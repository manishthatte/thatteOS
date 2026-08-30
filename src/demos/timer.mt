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
//
// ASSERTIONS ADDED 30 August 2026, and the reason is a stale finding.
// ENHANCEMENT_PLAN.md §2.2 has recorded, unmeasured, that the sleep queue
// "detects expiry, prints, and returns a `bool` nobody uses, so entries are
// never marked invalid and are 'woken' on every subsequent tick", with the
// remedy "return the updated `SleepQueue`". Re-probed against the source
// before implementing it, as §7 of that plan instructs:
//
//   * There is no `check_and_wake`. The function is `wake_entry_if_due`, and
//     it already returns `SleepEntry { .., valid: false }`.
//   * `timer_tick` already returns the cleaned queue inside a `TickResult`,
//     and already decrements `count` by the number it invalidated.
//
// The prescribed remedy is what the code already does. §2.2 is struck.
//
// But NOTHING PINNED IT: this demo had zero assertions and closed by printing
// five hardcoded "PASS" lines — the same "beside hardcoded PASS string
// literals" shape the merge removed from the other demos, and worse than
// printing nothing, because it reads as evidence. A property that is correct
// and unpinned is one refactor from being incorrect and unnoticed. The five
// literals are gone; every line below states a claim the program actually
// checks.
//
// Every expected value is derived FROM THE SOURCE — `timer_init` returns
// tick 0 / quantum 3, `sys_sleep` computes `wake_tick = timer.tick + ticks`
// against a timer that is never advanced between the three calls, and
// `timer_tick` increments BEFORE comparing — never from what the program
// printed. A check that copies the observed answer tests nothing.

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

    // A PROCESS TABLE, new in §2.1. The timer takes one now because waking a
    // sleeper means setting its state, and until §2.0 there was nothing to set
    // it in. The three sleepers below are admitted as real PCBs in SLEEP(-2),
    // so the wake can be asserted where it actually matters -- in the table --
    // rather than in the sentence the timer prints.
    let ptable = proc_table_init();
    let _ = table_admit(ptable, make_pcb_prio(2, -2, 0));
    let _ = table_admit(ptable, make_pcb_prio(5, -2, 0));
    let _ = table_admit(ptable, make_pcb_prio(7, -2, 0));
    expect_int("timer: three sleepers are in the process table", ptable.count, 3);
    expect_int("timer: PID 7 starts in SLEEP(-2)", slot_at(ptable, 2).state, -2);

    expect_int("timer: starts at tick 0", timer.tick, 0);
    expect_int("timer: quantum is 3 ticks", timer.quantum, 3);
    expect_int("sleep queue: starts empty", queue.count, 0);
    io::println("");

    // --- Put processes to sleep ---
    // The timer is NOT advanced between these three calls, so every wake_tick
    // is measured from tick 0: sys_sleep computes timer.tick + ticks.
    io::println("--- Scheduling sleeps ---");
    queue = sys_sleep(timer, queue, 2, 3);  // wake at 0+3 = 3
    queue = sys_sleep(timer, queue, 5, 6);  // wake at 0+6 = 6
    queue = sys_sleep(timer, queue, 7, 1);  // wake at 0+1 = 1
    expect_int("sys_sleep: three sleepers queued", queue.count, 3);
    expect_int("sys_sleep: first free slot took PID 2", queue.s0.pid, 2);
    expect_int("sys_sleep: PID 2 wakes at tick 3", queue.s0.wake_tick, 3);
    expect_int("sys_sleep: PID 5 wakes at tick 6", queue.s1.wake_tick, 6);
    expect_int("sys_sleep: PID 7 wakes at tick 1", queue.s2.wake_tick, 1);
    io::println("");

    // --- Tick 1: PID 7 falls due (wake_tick 1, and timer_tick increments
    //     BEFORE it compares, so new_tick is 1 on the first call) ---
    io::println("--- Tick 1: PID 7 falls due ---");
    let r1 = timer_tick(timer, queue, ptable);
    timer = r1.timer;
    queue = r1.queue;
    expect_int("tick 1: counter advanced to 1", timer.tick, 1);
    expect_bool("tick 1: PID 7's slot invalidated", queue.s2.valid, false);
    expect_int("tick 1: count drops to 2", queue.count, 2);
    // §2.1: the wake is now a state change in the table, not a printed claim.
    expect_int("tick 1: PID 7 is READY(+3) in the table", slot_at(ptable, 2).state, 3);
    expect_int("tick 1: PID 2 is still SLEEP(-2)", slot_at(ptable, 0).state, -2);
    expect_bool("tick 1: PID 2 still asleep", queue.s0.valid, true);
    io::println("");

    // --- Tick 2: nothing is due, AND THIS IS THE CHECK §2.2 IS ABOUT ---
    // "Woken once" and "woken on every subsequent tick" have the SAME end
    // state after nine ticks — both finish with the queue drained. Only a tick
    // taken AFTER a wake, with nothing else due, can tell them apart, which is
    // why this pair exists rather than an end-state assertion alone.
    io::println("--- Tick 2: nothing due; the woken entry must stay woken ---");
    let r2 = timer_tick(timer, queue, ptable);
    timer = r2.timer;
    queue = r2.queue;
    expect_int("tick 2: woken entry does NOT fire again", queue.count, 2);
    expect_bool("tick 2: PID 7's slot stays invalid", queue.s2.valid, false);
    expect_int("tick 2: invalidation clears `valid` only, pid survives", queue.s2.pid, 7);
    io::println("");

    // --- Ticks 3 to 9: PID 2 falls due at 3, PID 5 at 6 ---
    io::println("--- Ticks 3-9 ---");
    let mut t = 2;
    while t < 9 {
        let result = timer_tick(timer, queue, ptable);
        timer = result.timer;
        queue = result.queue;
        io::println("");
        t = t + 1;
    }

    expect_int("nine ticks: counter is 9", timer.tick, 9);
    expect_int("nine ticks: queue fully drained", queue.count, 0);
    expect_bool("nine ticks: PID 2 woken at tick 3", queue.s0.valid, false);
    expect_bool("nine ticks: PID 5 woken at tick 6", queue.s1.valid, false);
    expect_int("nine ticks: PID 2 ended READY in the table", slot_at(ptable, 0).state, 3);
    expect_int("nine ticks: PID 5 ended READY in the table", slot_at(ptable, 1).state, 3);
    // quantum is 3 and nine ticks is exactly three quanta, so the counter
    // must have reset on the ninth rather than be left mid-quantum.
    expect_int("nine ticks: 9 = 3x3, quantum counter reset", timer.ticks_this_quantum, 0);
    io::println("");

    // --- Uptime ---
    uptime(timer);
    io::println("");

    // The five "PASS" string literals that used to close this demo are gone.
    // They asserted nothing and printed unconditionally; the [CHECK] lines
    // above are the claims, and they can fail.
    io::println("=== Timer claims checked above ===");
}
