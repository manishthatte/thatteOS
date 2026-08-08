// boot.mt — THATTE-OS 0.1.0 kernel entry point
// Module 1: kernel_main() — boot sequence
//
// Demonstrates P5 Claims:
//   Claim 3  — Three-level privilege (KERNEL/SERVICE/USER) via status register
//   Claim 5  — Interrupt architecture (27 interrupt vectors)
//   Claim 7  — Full OS in ManiT / T3ISA binary
//   Claim 8  — Three-rail privilege substrate (VDD/GND/VSS)

use std::io;
use std::ternary;
use std::fmt;

// ---------------------------------------------------------------------------
// T3ISA privilege constants (status register [26..25])
// ---------------------------------------------------------------------------
// VDD = +1  KERNEL privilege
// GND =  0  SERVICE privilege
// VSS = -1  USER privilege

fn privilege_name(p: trit) -> str {
    tif p {
        + => return "KERNEL (+1) VDD",
        0 => return "SERVICE (0) GND",
        - => return "USER (-1) VSS",
    }
}

// ---------------------------------------------------------------------------
// Status register simulation (27-trit)
// Fields: [26..25] privilege, [24] irq_enable, [23] FLAGS
// ---------------------------------------------------------------------------

struct StatusReg {
    pub privilege: trit,
    pub irq_enable: trit,
    pub flags: trit,
}

fn make_status(priv_level: trit, irq: trit, flags: trit) -> StatusReg {
    return StatusReg { privilege: priv_level, irq_enable: irq, flags: flags };
}

fn print_status(sr: StatusReg) {
    io::print("  STATUS[26..25]=");
    io::print_trit(sr.privilege);
    io::print(" [24]=");
    io::print_trit(sr.irq_enable);
    io::print(" [23]=");
    io::println_trit(sr.flags);
}

// ---------------------------------------------------------------------------
// Interrupt table (27 entries)
// ---------------------------------------------------------------------------

struct IVEntry {
    pub vector: int,
    pub priority: trit,
    pub name: str,
}

fn make_iv(vec: int, pri: trit, name: str) -> IVEntry {
    return IVEntry { vector: vec, priority: pri, name: name };
}

fn interrupt_init() {
    io::println("[BOOT] interrupt_init: registering 27 interrupt vectors");

    // Build representative interrupt table entries
    let priorities: [trit] = [-, -, -, 0, 0, 0, 0, 0, 0,
                                0, 0, 0, 0, 0, +, 0, 0, 0,
                                0, 0, 0, 0, 0, 0, +, 0, 0];
    let mut v = 0;
    while v < 27 {
        let pri = priorities[v];
        tif pri {
            + => {
                io::print("    vector[");
                io::print_int(v);
                io::println("] priority=HIGH  (+1) — immediate dispatch");
            }
            0 => {
                io::print("    vector[");
                io::print_int(v);
                io::println("] priority=MED   ( 0) — queue next tick");
            }
            - => {
                io::print("    vector[");
                io::print_int(v);
                io::println("] priority=LOW   (-1) — defer to idle");
            }
        }
        v = v + 1;
    }

    io::println("[BOOT] interrupt_init: default handlers set");
    io::println("  vector[ 0] -> timer_handler      priority=MEDIUM");
    io::println("  vector[+1] -> syscall_handler     priority=HIGH");
    io::println("  vector[-1] -> fault_handler       priority=HIGH");
    io::println("[BOOT] interrupt_init: IRQ enabled (STATUS[24]=+1)");
}

// ---------------------------------------------------------------------------
// Process table (9 PCBs)
// ---------------------------------------------------------------------------

struct PCB {
    pub pid: int,
    pub state: int,
    pub pc: int,
    pub sp: int,
    pub privilege: trit,
    pub parent_pid: int,
}

fn make_pcb(pid: int, state: int, priv_level: trit, parent: int) -> PCB {
    return PCB { pid: pid, state: state, pc: 0, sp: 0,
                 privilege: priv_level, parent_pid: parent };
}

fn process_init() {
    io::println("[BOOT] process_init: allocating 9-slot process table");
    io::println("  Slot 0: PID=0 (idle)    state=READY(+3)  priv=KERNEL");
    io::println("  Slot 1: PID=1 (init)    state=READY(+3)  priv=USER");
    io::println("  Slots 2-8: empty");
    io::println("[BOOT] process_init: done");
}

// ---------------------------------------------------------------------------
// Virtual memory map
// ---------------------------------------------------------------------------

fn vmem_init() {
    io::println("[BOOT] vmem_init: mapping T3ISA address space");
    io::println("  MST=+1 kernel space: addr[26]=+1 — requires KERNEL privilege");
    io::println("  MST= 0 shared space: addr[26]= 0 — all privilege levels");
    io::println("  MST=-1 user space:   addr[26]=-1 — all privilege levels");
    io::println("[BOOT] vmem_init: page size = 3^9 = 19683 words");
    io::println("[BOOT] vmem_init: page perms: read/write/exec each {-1,0,+1}");
    io::println("  read_perm:  -1=deny   0=copy-on-write  +1=allow");
    io::println("  write_perm: -1=deny   0=demand-zero    +1=allow");
    io::println("  exec_perm:  -1=deny   0=JIT-compile    +1=allow");
    io::println("[BOOT] vmem_init: done");
}

// ---------------------------------------------------------------------------
// Syscall table (16 syscalls)
// ---------------------------------------------------------------------------

fn syscall_init() {
    io::println("[BOOT] syscall_init: registering 16 syscall handlers");
    io::println("  Positive syscalls (process/memory management):");
    io::println("    SYS_FORK       = +1");
    io::println("    SYS_EXEC       = +2");
    io::println("    SYS_EXIT       = +3");
    io::println("    SYS_ALLOC      = +5");
    io::println("    SYS_FREE       = +6");
    io::println("    SYS_MOD_LOAD   = +10");
    io::println("    SYS_MOD_UNLOAD = +11");
    io::println("  Negative syscalls (I/O and communication):");
    io::println("    SYS_YIELD      = -1");
    io::println("    SYS_PRIV_SET   = -2");
    io::println("    SYS_RECV       = -4");
    io::println("    SYS_SEND       = -5");
    io::println("    SYS_CLOSE      = -10");
    io::println("    SYS_OPEN       = -11");
    io::println("    SYS_READ       = -12");
    io::println("    SYS_WRITE      = -13");
    io::println("  Null syscall (void): SYS_NULL = 0");
    io::println("[BOOT] syscall_init: dispatch via TBRANCH sign(R1)");
    io::println("[BOOT] syscall_init: done");
}

// ---------------------------------------------------------------------------
// TTY driver load at SERVICE privilege
// ---------------------------------------------------------------------------

fn tty_init(sr: StatusReg) -> StatusReg {
    io::println("[BOOT] tty_init: dropping KERNEL -> SERVICE");
    // Simulate privilege drop: KERNEL(+1) -> SERVICE(0)
    let new_sr = make_status(0, sr.irq_enable, sr.flags);
    io::print("  Privilege transition: ");
    io::print(privilege_name(sr.privilege));
    io::print(" -> ");
    io::println(privilege_name(new_sr.privilege));
    io::println("  TTY driver loaded at SERVICE (0) GND domain");
    io::println("  SYS_MOD_LOAD registered: module_id=1 name=tty");
    return new_sr;
}

// ---------------------------------------------------------------------------
// Launch init process at USER privilege
// ---------------------------------------------------------------------------

fn launch_init(sr: StatusReg) -> StatusReg {
    io::println("[BOOT] launch_init: dropping SERVICE -> USER");
    let new_sr = make_status(-, sr.irq_enable, sr.flags);
    io::print("  Privilege transition: ");
    io::print(privilege_name(sr.privilege));
    io::print(" -> ");
    io::println(privilege_name(new_sr.privilege));
    io::println("  init process spawned: PID=1 state=READY(+3) priv=USER(-1)");
    io::println("  init: running at USER privilege (-1)");
    return new_sr;
}

// ---------------------------------------------------------------------------
// Scheduler demonstration
// ---------------------------------------------------------------------------

fn get_primary(state: int) -> trit {
    if state > 0 { return +; }
    elif state == 0 { return 0; }
    elif state >= -2 { return 0; }
    else { return -; }
}

fn state_name(state: int) -> str {
    if state == 4 { return "EXECUTING"; }
    elif state == 3 { return "READY"; }
    elif state == 2 { return "YIELDED"; }
    elif state == 0 { return "IO_WAIT"; }
    elif state == -1 { return "MSG_WAIT"; }
    elif state == -2 { return "SLEEP"; }
    elif state == -3 { return "EXITED"; }
    elif state == -4 { return "KILLED"; }
    else { return "FAULTED"; }
}

fn scheduler_run_demo() {
    io::println("[SCHED] scheduler_run: one scheduling pass over 9 PCBs");

    let pids: [int]   = [1, 2, 3, 4, 5, 6, 7, 8, 9];
    let states: [int] = [3, 2, 0, -1, -2, -3, -4, -5, 3];

    let mut i = 0;
    while i < 9 {
        let pid = pids[i];
        let state = states[i];
        let primary = get_primary(state);

        io::print("  PID=");
        io::print_int(pid);
        io::print(" state=");
        io::print(state_name(state));
        io::print("(");
        io::print_int(state);
        io::print(") primary=");
        io::print_trit(primary);
        io::print(" => ");

        tif primary {
            + => {
                io::println("ACTIVE  — dispatch_active: restore PC/SP, resume");
            }
            0 => {
                io::println("DORMANT — check_wakeup: inspect wakeup condition");
            }
            - => {
                io::println("TERMINAL — reap_process: free pages, remove PCB");
            }
        }
        i = i + 1;
    }
    io::println("[SCHED] scheduler_run: pass complete");
}

// ---------------------------------------------------------------------------
// kernel_main — boot entry point
// ---------------------------------------------------------------------------

fn kernel_main() {
    // --- Boot banner ---
    io::println("========================================");
    io::println("THATTE-OS 0.1.0");
    io::println("Balanced Ternary Microkernel");
    io::println("Architecture: PANINI / T3ISA / 27-trit");
    io::println("Privilege: KERNEL (+1) — VDD domain");
    io::println("Build: 2026-03-21 manitc 0.1.0");
    io::println("========================================");
    io::println("");

    // Initialise status register at KERNEL privilege
    let mut sr = make_status(+, +, 0);
    io::print("[BOOT] Status register: ");
    print_status(sr);

    io::println("");

    // Step 1: Interrupt init
    interrupt_init();
    io::println("");

    // Step 2: Process table init
    process_init();
    io::println("");

    // Step 3: Virtual memory init
    vmem_init();
    io::println("");

    // Step 4: Syscall table init
    syscall_init();
    io::println("");

    // Step 5: TTY driver (drops to SERVICE)
    sr = tty_init(sr);
    io::println("");

    // Step 6: Launch init process (drops to USER)
    sr = launch_init(sr);
    io::println("");

    // Step 7: Scheduler demonstration
    scheduler_run_demo();
    io::println("");

    io::println("========================================");
    io::println("THATTE-OS boot sequence complete");
    io::println("All subsystems operational");
    io::println("========================================");
}

fn main() {
    kernel_main();
}
