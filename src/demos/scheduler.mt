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
    // check_starvation MUTATES now (see kernel/scheduler.mt -- it was costing
    // a PCB copy per process per pass against a 2,536-word T3 heap), so there
    // is no promoted copy to read: `starved` IS the promoted PCB.
    check_starvation(starved);
    io::print("  after check: pri=");
    io::println(priority_name(starved.priority));
    expect_trit("starvation: LOW promoted to NORMAL after 9 idle ticks",
                starved.priority, 0);
    expect_int("starvation: promotion resets the age counter", starved.age, 0);
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

    // THE TABLE MOVED HERE, 30 August 2026 -- ENHANCEMENT_PLAN §2.0.
    // These nine PCBs used to be a LOCAL inside `scheduler_run` itself, rebuilt
    // on every call and discarded on every return, which is why that function
    // could take no arguments and why nothing in the kernel could call it
    // usefully. The scheduler now takes the process table; the demo's job is to
    // provide one, which is what a demo should have been doing all along.
    let t = process_init();
    io::println("");
    expect_int("table: process_init returns an empty table", t.count, 0);
    expect_int("table: nothing is running yet", t.current, -1);

    // pid, state, priority -- the nine states, so one pass exercises all three
    // TBRANCH arms. Unchanged from the local table this replaces.
    let _ = table_admit(t, make_pcb_prio(0, 3, +));   // idle,   READY,     HIGH
    let _ = table_admit(t, make_pcb_prio(1, 4, 0));   // init,   EXECUTING, NORMAL
    let _ = table_admit(t, make_pcb_prio(2, 2, -));   // worker, YIELDED,   LOW
    let _ = table_admit(t, make_pcb_prio(3, 0, 0));   //         IO_WAIT,   NORMAL
    let _ = table_admit(t, make_pcb_prio(4, -1, +));  //         MSG_WAIT,  HIGH
    let _ = table_admit(t, make_pcb_prio(5, -2, -));  //         SLEEP,     LOW
    let _ = table_admit(t, make_pcb_prio(6, -3, 0));  //         EXITED,    NORMAL
    let _ = table_admit(t, make_pcb_prio(7, -4, -));  //         KILLED,    LOW
    let _ = table_admit(t, make_pcb_prio(8, -5, +));  //         FAULTED,   HIGH

    // Slot 0 starts aged, so the dispatch reset below is observable.
    t.p0.age = 4;
    expect_int("table: nine processes admitted", t.count, 9);
    expect_int("table: slot 0 starts with a non-zero age", slot_at(t, 0).age, 4);
    // live = not free AND state > -3. States 3,4,2,0,-1,-2 qualify; the three
    // terminal ones (-3,-4,-5) do not.
    expect_int("table: six of the nine are live", table_live(t), 6);
    expect_int("table: find by pid", table_find(t, 4), 4);
    expect_int("table: find reports -1 for an absent pid", table_find(t, 42), -1);

    // PCB now carries a capability word -- §2.3's prerequisite. make_pcb_prio
    // builds at privilege 0 (SERVICE), so these are service_caps: everything
    // granted except CAN_PRIV.
    expect_trit("table: PCB carries caps, CAN_FORK granted", slot_at(t, 0).caps.c0, +);
    expect_trit("table: SERVICE is denied CAN_PRIV",         slot_at(t, 0).caps.c5, -);
    expect_int("table: the cap word knows its own pid",      slot_at(t, 4).caps.pid, 4);

    io::println("");
    scheduler_run(t);
    io::println("");

    // One pass over a fresh table, derived from the source rather than the
    // output: every ACTIVE and DORMANT slot is aged first (age_tick, +1);
    // check_starvation then does nothing because age 1 < 9; and the TBRANCH
    // arm decides the rest. ACTIVE dispatches -- age resets to 0 and one
    // quantum tick is charged. DORMANT keeps the age it was just given.
    // TERMINAL is not aged at all and is only reaped.
    // This row was HOLLOW as first written. A fresh PCB starts at age 0, so
    // asserting 0 after the pass passes whether or not the aging and the reset
    // happened at all -- it cannot tell "aged to 1 then dispatched back to 0"
    // from "nothing ran". Slot 0 is given a non-zero age above precisely so
    // that 0 here is a RESULT rather than the initial value.
    expect_int("pass: ACTIVE pid 0 dispatched, age reset from 4", slot_at(t, 0).age, 0);
    expect_int("pass: ACTIVE pid 0 charged one quantum tick", slot_at(t, 0).quantum_used, 1);
    expect_int("pass: DORMANT pid 3 aged and not dispatched", slot_at(t, 3).age, 1);
    expect_int("pass: DORMANT pid 3 spent no quantum",        slot_at(t, 3).quantum_used, 0);
    expect_int("pass: TERMINAL pid 6 is not aged",            slot_at(t, 6).age, 0);
    expect_int("pass: TERMINAL pid 6 spends no quantum",      slot_at(t, 6).quantum_used, 0);

    // The mutation the signal and syscall layers will use.
    expect_bool("table: set_state finds a live pid", table_set_state(t, 5, 3), true);
    expect_int("table: set_state wrote the new state", slot_at(t, 5).state, 3);
    expect_bool("table: set_state refuses an absent pid", table_set_state(t, 42, 3), false);

    io::println("");
    starvation_demo();
    io::println("");

    // The four hardcoded "PASS" lines that used to close this demo are gone --
    // they printed unconditionally and asserted nothing. The [CHECK] rows above
    // are the claims.
    io::println("=== Enhanced scheduler claims checked above ===");
}
