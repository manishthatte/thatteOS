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



// admit_boot_processes: put the boot process set into THE process table.
//
// REPLACES `scheduler_run_demo`, 30 August 2026 -- ENHANCEMENT_PLAN §2.0.
// That function was a FOURTH re-implementation of the scheduler, living in
// this file, walking its own hardcoded `pids`/`states` arrays and printing
// what a scheduler would do. Phase 1 dropped eight such stubs from boot.mt;
// this one survived them because it did not print `[BOOT]`.
//
// THAT IS WORTH KEEPING: the suite's "no module re-implemented in boot.mt" row
// greps for `[BOOT] interrupt_init`, `[BOOT] vmem_init`, `[BOOT] syscall_init`
// and `[BOOT] process_init` -- it catches a stub that announces itself as boot.
// This stub announced itself as `[SCHED] scheduler_run:`, the real module's own
// prefix, so the guard could not see it, and the row above it -- "kernel:
// scheduler pass completes", which greps for "[SCHED] scheduler_run: pass
// complete" -- was being satisfied BY THE STUB. A guard keyed on the impostor
// naming itself cannot catch an impostor that uses the real name.
//
// The nine states are kept from the retired stub deliberately: one pass over
// them exercises all three TBRANCH arms (ACTIVE +, DORMANT 0, TERMINAL -),
// which is the coverage the boot sequence is here to demonstrate. What has
// changed is that they are now PCBs in the table the rest of the kernel holds,
// scheduled by kernel/scheduler.mt, instead of integers in a local array
// narrated by this file.
// event_loop: the kernel's steady state, three ticks of it.
//
// Every subsystem below was reachable from boot before §2 and none of them
// reached EACH OTHER: the timer printed "-> scheduler_run() invoked", the
// scheduler built its own table and discarded it, and the syscall layer never
// consulted a capability. This is those four modules connected.
fn event_loop(t: ProcTable, sr: StatusRegister) {
    io::println("[BOOT] event loop: interrupt -> timer -> scheduler, 3 ticks");

    let mut timer = timer_init();
    let mut queue = sleep_queue_init();
    let mut irq = irq_state_init();

    // The init process asks to sleep, so the loop has a sleeper to wake and
    // the timer's queue is exercised rather than merely initialised.
    queue = sys_sleep(timer, queue, 1, 2);

    let mut tick = 0;
    while tick < 3 {
        io::print("  --- tick ");
        io::print_int(tick + 1);
        io::println(" ---");

        // The timer interrupt is vector 0.
        irq = interrupt_dispatch(0, irq);

        // timer_tick wakes due sleepers INTO the table and, when the quantum
        // expires, runs the scheduler over it.
        let r = timer_tick(timer, queue, t);
        timer = r.timer;
        queue = r.queue;

        irq = interrupt_return(irq);

        // A REAL SYSCALL, through the capability gate (§2.3).
        //
        // The gate was enforced at `syscall_dispatch` and every caller was in
        // `src/demos/syscall.mt`, so nothing in the RUNNING kernel ever passed
        // through it. The running process issues SYS_YIELD each tick, which is
        // one of the two syscalls that require no capability -- a process may
        // always give the CPU up -- and on the last tick it also attempts
        // SYS_MOD_LOAD, which its ring does not permit. Both answers are
        // printed, so boot shows the gate allowing and refusing.
        if t.current >= 0 {
            let running = slot_at(t, t.current);
            let _y = syscall_dispatch(-1, 0, 0, running);
            if tick == 2 {
                // Issued BY INIT, which runs at USER(-1) and therefore holds
                // user_caps: CAN_MOD is withheld. Aimed at init specifically
                // rather than at whoever happens to be current, because the
                // point of the row is the RING, and idle runs at KERNEL where
                // the same call is legitimately allowed.
                let ii = table_find(t, 1);
                if ii >= 0 {
                    io::println("  [BOOT] init (USER) attempts SYS_MOD_LOAD:");
                    let denied = syscall_dispatch(10, 16384, 0, slot_at(t, ii));
                    if denied == EPERM() {
                        io::println("  [BOOT] refused — capability enforcement is live");
                    }
                }
            }
        }

        tick = tick + 1;
    }

    io::print("  [BOOT] after 3 ticks: ");
    io::print_int(table_live(t));
    io::print(" live of ");
    io::print_int(t.count);
    io::println(" admitted");
    uptime(timer);
}

fn admit_boot_processes(t: ProcTable) {
    io::println("[BOOT] admitting the boot process set to the process table");

    // TWO PROCESSES -- the ones this boot sequence actually creates. `idle` is
    // PID 0 and `launch_init` above spawns PID 1 at USER, which the line
    // "init process spawned: PID=1 state=READY(+3)" reports.
    //
    // The retired `scheduler_run_demo` walked NINE hardcoded states here, and
    // the first version of this function inherited that set. It did not fit,
    // and the way it failed is worth keeping. PCB carries a CapWord since
    // §2.3, so one costs ~21 words of the 2,536-word T3 heap (report.txt P63);
    // nine placeholders plus nine admissions plus the rest of boot crossed it.
    // Sometimes that traps --
    //     TRAP: heap exhausted allocating 10 word(s) at 65533 (limit 65536)
    // -- and sometimes it does NOT, which is the part to remember: with the
    // pressure slightly lower the kernel ran on and the table came back
    // CORRUPTED instead, five of nine slots holding values like 6589397959
    // and 63000, the latter being HEAP_BASE itself. Hosted was correct
    // throughout, so the only instrument that could see it was the suite's
    // byte-identical row.
    //
    // The nine-state coverage was not lost, it was moved to where it belongs:
    // `src/demos/scheduler.mt` builds the nine-PCB table and asserts against
    // it, and `build/kernel_demos` is hosted-only, so it is not spending a
    // budget the target has. Boot demonstrating seven processes it never
    // created was the stub's habit, not a requirement.
    // THE RINGS ARE REAL, and they were not. `make_pcb_prio` hardcodes
    // privilege 0 (SERVICE) because the scheduler that used it only cared
    // about priority -- so the PCB for init said SERVICE while `launch_init`
    // ten lines above printed "init: running at USER privilege (-1)". The
    // process table disagreed with the boot sequence about its own processes,
    // and once §2.3 made capabilities derive from the ring that stopped being
    // cosmetic: init held service_caps and could have loaded a kernel module.
    //
    // Built with `make_pcb`, which takes the privilege, and the priority set
    // after -- rather than `make_pcb_prio`, which takes the priority and
    // assumes the privilege.
    let idle_pcb = make_pcb(0, 3, +, 0);      // idle:  KERNEL(+1), READY
    idle_pcb.priority = +;                     //        HIGH
    let init_pcb = make_pcb(1, 4, -, 0);      // init:  USER(-1), EXECUTING
    init_pcb.priority = 0;                     //        NORMAL
    let idle = table_admit(t, idle_pcb);
    let init = table_admit(t, init_pcb);
    if idle < 0 || init < 0 {
        io::println("  process table full — cannot admit");
    }
    io::print("  admitted: ");
    io::print_int(t.count);
    io::print(" processes, ");
    io::print_int(table_live(t));
    io::println(" of them live");
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

    // Step 2: Process table init — and it now RETURNS the table it announces.
    let ptable = process_init();
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

    // Step 7: the first scheduling pass, over THE process table
    admit_boot_processes(ptable);
    io::println("");
    scheduler_run(ptable);
    io::println("");

    // Step 8: the event loop — ENHANCEMENT_PLAN §2.5
    //
    // Interrupt -> timer -> scheduler, over ONE process table, for three
    // ticks. §2.5 was written as a fifth item; it is really §2.0 finished,
    // because once the table is threaded the loop is just what threads it.
    //
    // Three ticks and not thirty, for a measured reason: the quantum is three,
    // so this is exactly one quantum and the loop shows the preemption that
    // ends it. The T3 image and heap both have to hold, and a kernel that
    // demonstrates a scheduler by running it forever cannot also fit under
    // 60,000 words with room to grow (report.txt P38, P63).
    event_loop(ptable, sr);
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
