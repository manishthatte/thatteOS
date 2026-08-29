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
use std::env;
use std::str;

// MERGE NOTE, 30 August 2026 — eight declarations left this file.
// 
// boot.mt used to carry its own `PCB`, `make_pcb`, `state_name`,
// `get_primary`, `interrupt_init`, `process_init`, `syscall_init` and
// `vmem_init`, because a .mt file could not use another one's bodies and
// `kernel_main` had to call SOMETHING. They were stubs of the real ones and
// free to drift from them, and they had: boot's `PCB` was process.mt's minus
// `page_table`, and boot's `PCB` and `make_pcb` were never referenced at all
// -- declared, and dead, for as long as this file has existed.
// 
// The kernel is one translation unit now (src/kernel.manifest), so
// `kernel_main` calls the real ones: kernel/interrupt.mt, kernel/scheduler.mt,
// syscall/syscall.mt and mm/vmem.mt. Four of the five inits had an IDENTICAL
// signature, so those call sites did not move. The fifth did not -- see
// `drop_to_service` below.

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







// ---------------------------------------------------------------------------
// TTY driver load at SERVICE privilege
// ---------------------------------------------------------------------------

// Renamed from `tty_init` in the 30 Aug merge, and this is the one init stub
// that could NOT simply be deleted in favour of the real module's. The two
// signatures do not meet: this took a StatusReg and returned one, while
// drivers/tty.mt's `tty_init` takes a trit and returns a TtyState. They were
// never the same operation wearing two shapes -- one moves the STATUS REGISTER
// from KERNEL to SERVICE, the other loads the TTY DRIVER. `kernel_main` now
// does both, in that order, and each is named for what it does.
fn drop_to_service(sr: StatusReg) -> StatusReg {
    io::println("[BOOT] drop_to_service: dropping KERNEL -> SERVICE");
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

    // Step 5: TTY driver, then the privilege drop that goes with it.
    // Two calls where there used to be one, because there were always two
    // operations here and boot.mt could only reach the register half.
    let tty = tty_init(sr.privilege);
    tty_stats(tty_print_info(tty, "kernel_main: TTY is the boot console"));
    sr = drop_to_service(sr);
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

// ---------------------------------------------------------------------------
// No `fn main` here — see src/entry_kernel.mt and src/entry_demos.mt
// ---------------------------------------------------------------------------
//
// `kernel_main` is the boot sequence and nothing else. The entry point lives in
// a one-function module chosen by the manifest, because there are two programs
// built from these same 26 modules and they differ ONLY in their entry:
//
//     src/kernel.manifest        -> boot only          — BOTH backends
//     src/kernel_demos.manifest  -> boot + 25 demos    — hosted only
//
// The split is forced by a hard number rather than by taste. The T3 code image
// must fit below the stack at 60,000 words. Boot-only is 56,421. Adding
// `run_all_demos()` makes all 25 demos REACHABLE, so nothing can eliminate
// them, and the image becomes **60,760 words — 760 over, and the assembler
// refuses it**. The demos are a hosted development aid; the kernel is the
// thing that has to fit on the target, and it does.
