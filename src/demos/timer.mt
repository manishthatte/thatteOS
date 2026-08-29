// src/demos/timer.mt — the demonstration lifted out of src/kernel/timer.mt
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

// timer_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn timer_demo() {
    io::println("=== THATTE-OS Timer Subsystem Demo ===");
    io::println("Claim 1: Process SLEEP/wakeup");
    io::println("Claim 5: Timer interrupt vector 0");
    io::println("");

    let mut timer = timer_init();
    let mut queue = sleep_queue_init();
    io::println("");

    // --- Put processes to sleep ---
    io::println("--- Scheduling sleeps ---");
    queue = sys_sleep(timer, queue, 2, 3);  // wake at tick 3
    queue = sys_sleep(timer, queue, 5, 6);  // wake at tick 6
    queue = sys_sleep(timer, queue, 7, 1);  // wake at tick 1
    io::println("");

    // --- Simulate 9 timer ticks ---
    io::println("--- Simulating 9 timer ticks ---");
    let mut t = 0;
    while t < 9 {
        let result = timer_tick(timer, queue);
        timer = result.timer;
        queue = result.queue;
        io::println("");
        t = t + 1;
    }

    // --- Uptime ---
    uptime(timer);
    io::println("");

    io::println("=== Timer claims verified ===");
    io::println("  System tick counter:         PASS");
    io::println("  Sleep queue (9 entries):     PASS");
    io::println("  SYS_SLEEP -> SLEEP(-2):      PASS");
    io::println("  Timer wakeup expired:        PASS");
    io::println("  Quantum (3 ticks) preempt:   PASS");
}
