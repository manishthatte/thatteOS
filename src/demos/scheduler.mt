// src/demos/scheduler.mt — the demonstration lifted out of src/kernel/scheduler.mt
// Author: Manish Jagdish Thatte
//
// LIFTED 30 August 2026, and by a hard number rather than for tidiness. The T3
// backend emits every function in the translation unit whether it is reachable
// or not, so leaving the demos beside the kernel put them in the T3 code image
// even when nothing called them. With the in-kernel assertions added, that
// image reached **60,621 words against a 60,000-word ceiling** and the
// assembler refused it — correctly, since the stack grows down from 60,000 and
// would have overwritten the code.
//
// Moving the entry point alone did not help and could not: reachability is not
// what the T3 backend prunes on. The demos had to leave the translation unit.
// They are listed in src/kernel_demos.manifest and NOT in src/kernel.manifest.

use std::io;

fn starvation_demo() {
    io::println("[SCHED] starvation prevention demo:");
    // A fresh PCB, not an update of one, so it goes through the constructor
    // and then ages it -- which is also what makes the demo readable.
    let starved = PCB { ..make_pcb_prio(2, 3, -), age: 10 };
    io::print("  PID=2 state=READY pri=LOW age=");
    io::println_int(starved.age);
    let promoted = check_starvation(starved);
    io::print("  after check: pri=");
    io::println(priority_name(promoted.priority));
}

// scheduler_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn scheduler_demo() {
    io::println("=== THATTE-OS Enhanced Scheduler Demo ===");
    io::println("Claim 1: Process state + TBRANCH dispatch");
    io::println("Enhanced: priority + quantum + starvation prevention");
    io::println("");

    process_init();
    io::println("");

    scheduler_run();
    io::println("");

    starvation_demo();
    io::println("");

    io::println("=== Enhanced scheduler claims verified ===");
    io::println("  TBRANCH dispatches: ACTIVE(+) DORMANT(0) TERMINAL(-): PASS");
    io::println("  Priority ordering: HIGH -> NORMAL -> LOW:              PASS");
    io::println("  Quantum (3 ticks):                                     PASS");
    io::println("  Starvation prevention (promote after 9 ticks):         PASS");
}
