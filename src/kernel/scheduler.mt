// kernel/scheduler.mt — THATTE-OS scheduler (enhanced)
// Module 2: Priority scheduler with TBRANCH + quantum + starvation prevention
//
// Demonstrates P5 Claim 1:
//   Process state model + TBRANCH scheduler dispatch
//   Three-way tif on sign(state): ACTIVE / DORMANT / TERMINAL
//
// Enhancements:
//   - Priority: HIGH(+) / NORMAL(0) / LOW(-) — TBRANCH before round-robin
//   - Quantum: 3 ticks per scheduling round (ternary)
//   - Starvation prevention: promote LOW after 9 ticks without dispatch
//   - Process age tracking

use std::io;

// ---------------------------------------------------------------------------
// Process states (t9 conceptual values)
//   EXECUTING = +4   READY = +3   YIELDED = +2   -> sign > 0 -> ACTIVE
//   IO_WAIT   =  0   MSG_WAIT = -1   SLEEP = -2   -> dormant
//   EXITED    = -3   KILLED = -4   FAULTED = -5   -> sign < 0 -> TERMINAL
// ---------------------------------------------------------------------------

fn get_primary(state: int) -> trit {
    if state > 0 { return +; }
    elif state == 0 { return 0; }
    elif state >= -2 { return 0; }
    else { return -; }
}

fn state_name(s: int) -> str {
    if s == 4 { return "EXECUTING"; }
    elif s == 3 { return "READY"; }
    elif s == 2 { return "YIELDED"; }
    elif s == 0 { return "IO_WAIT"; }
    elif s == -1 { return "MSG_WAIT"; }
    elif s == -2 { return "SLEEP"; }
    elif s == -3 { return "EXITED"; }
    elif s == -4 { return "KILLED"; }
    else { return "FAULTED"; }
}

// ---------------------------------------------------------------------------
// PCB with priority and age
// ---------------------------------------------------------------------------

// `PCB` moved to kernel/process.mt, 30 August 2026, as the UNION of the two
// (see the note there). This module's three scheduling fields -- priority, age,
// quantum_used -- went with it, so everything below reads them unchanged.

// Renamed from `make_pcb` in the 30 Aug merge, and it is a different
// constructor rather than a copy of process.mt's: that one takes a privilege
// level and a parent, this one takes a PRIORITY, which is the field the
// scheduler cares about. Both fill the whole union now.
fn make_pcb_prio(pid: int, state: int, pri: trit) -> PCB {
    // Built by UPDATING process.mt's constructor rather than by spelling the
    // fields out. The spelled-out form is what broke when PCB gained `caps` on
    // 30 August 2026, and it was the last bare PCB literal in the kernel --
    // sys_exec's comment already said why ("an update expression cannot forget
    // a field") and this was the site still not taking the advice.
    // privilege 0 = SERVICE, which is what the spelled-out version set, so the
    // capability word comes out as service_caps and nothing moves.
    // Built then MUTATED, not `PCB { ..make_pcb(..), priority: pri }`, which
    // allocated a second PCB cell to change one field. Nine of those is 99
    // heap words of 2,536 on T3.
    let p = make_pcb(pid, state, 0, 0);
    p.priority = pri;
    return p;
}

fn priority_name(p: trit) -> str {
    tif p {
        + => return "HIGH",
        0 => return "NORMAL",
        - => return "LOW",
    }
}

// ---------------------------------------------------------------------------
// dispatch_active: restore context and resume process
// ---------------------------------------------------------------------------

fn dispatch_active(p: PCB) {
    io::print("    dispatch_active: PID=");
    io::print_int(p.pid);
    io::print(" pri=");
    io::print(priority_name(p.priority));
    io::print(" PC=0x");
    io::print_int(p.pc);
    io::print(" SP=0x");
    io::println_int(p.sp);
    io::println("    [JUMP to process.pc — context restored]");
}

// ---------------------------------------------------------------------------
// check_wakeup: dormant processes
// ---------------------------------------------------------------------------

fn check_wakeup(p: PCB) -> int {
    let s = p.state;
    if s == 0 {
        io::print("    check_wakeup: PID=");
        io::print_int(p.pid);
        io::println(" IO_WAIT — check_io_ready");
        io::println("    [io device not ready — remain IO_WAIT]");
    } elif s == -1 {
        io::print("    check_wakeup: PID=");
        io::print_int(p.pid);
        io::println(" MSG_WAIT — check_message_ready");
        io::println("    [no message in queue — remain MSG_WAIT]");
    } else {
        io::print("    check_wakeup: PID=");
        io::print_int(p.pid);
        io::println(" SLEEP — check_sleep_expired");
        io::println("    [sleep not yet expired — remain SLEEP]");
    }
    return 0;
}

// ---------------------------------------------------------------------------
// reap_process: free resources for TERMINAL processes
// ---------------------------------------------------------------------------

fn reap_process(p: PCB) {
    io::print("    reap_process: PID=");
    io::print_int(p.pid);
    io::print(" state=");
    io::print(state_name(p.state));
    io::println(" — freeing pages, removing PCB");
}

// ---------------------------------------------------------------------------
// check_starvation: promote LOW priority after 9 ticks
// ---------------------------------------------------------------------------

// MUTATES `p` rather than returning a promoted copy, 30 August 2026.
//
// This is a HEAP measurement, not a style change. A struct parameter in this
// language is a mutable reference (measured on both backends), while
// `PCB { ..p, .. }` genuinely copies -- and the T3 heap is 2,536 words with no
// free (maniTC report.txt P63). When PCB gained its CapWord for §2.3 it roughly
// doubled, to a ~11-word cell pointing at a ~10-word cap word, and this
// function plus `age_tick` and `schedule_pcb` each copy-constructed one per
// process per pass. Nine processes over three passes exhausted the heap during
// boot and the T3 kernel trapped:
//     TRAP: heap exhausted allocating 10 word(s) at 65533 (limit 65536)
// The hosted backend never noticed, so this was a CROSS-BACKEND divergence
// caught only by the suite's byte-identical row.
fn check_starvation(p: PCB) {
    if p.age >= 9 {
        // Starvation detected — promote priority
        tif p.priority {
            - => {
                io::print("    [STARVATION] PID=");
                io::print_int(p.pid);
                io::println(" LOW->NORMAL after 9 idle ticks");
                p.priority = 0;
                p.age = 0;
                p.quantum_used = 0;
            }
            0 => {
                io::print("    [STARVATION] PID=");
                io::print_int(p.pid);
                io::println(" NORMAL->HIGH after 9 idle ticks");
                p.priority = +;
                p.age = 0;
                p.quantum_used = 0;
            }
            + => {}
        }
    }
}

// ---------------------------------------------------------------------------
// age_tick: one scheduler tick has elapsed without dispatch — age the PCB
// ---------------------------------------------------------------------------

fn age_tick(p: PCB) {
    p.age = p.age + 1;
}

// ---------------------------------------------------------------------------
// schedule_pcb: starvation check + TBRANCH state dispatch for one PCB.
// Returns the updated PCB (promotion, age reset, quantum accounting) so the
// caller can write it back into the process table.
// ---------------------------------------------------------------------------

// Returns true when the PCB was actually DISPATCHED, so the table can record
// which slot is running. `ProcTable.current` was added in §2.0 and nothing set
// it -- it read -1 for the life of the program, which is a field that describes
// the running process and never knows one.
fn schedule_pcb(idx: int, p: PCB) -> bool {
    let primary = get_primary(p.state);
    // check_starvation mutates `p` now; there is no second binding, and that
    // removes a genuine hazard as well as an allocation -- the old code held
    // BOTH `p` and its promoted copy `p2` and then read `p.state`/`p.priority`
    // from the stale one while reporting `p2.age`.
    check_starvation(p);
    io::print("  PCB[");
    io::print_int(idx);
    io::print("] PID=");
    io::print_int(p.pid);
    io::print(" state=");
    io::print(state_name(p.state));
    io::print(" pri=");
    io::print(priority_name(p.priority));
    io::print(" age=");
    io::print_int(p.age);
    io::print(" primary=");
    io::println_trit(primary);

    tif primary {
        + => {
            io::println("    [ACTIVE]");
            if p.quantum_used >= 3 {
                io::print("    [QUANTUM] PID=");
                io::print_int(p.pid);
                io::println(" used 3 ticks — preempted, quantum reset");
                io::println("");
                p.quantum_used = 0;
            } else {
                dispatch_active(p);
                io::println("");
                // Dispatched: age resets, one quantum tick consumed
                p.age = 0;
                p.quantum_used = p.quantum_used + 1;
                return true;
            }
        }
        0 => {
            io::println("    [DORMANT]");
            let _ = check_wakeup(p);
            io::println("");
        }
        - => {
            io::println("    [TERMINAL]");
            reap_process(p);
            io::println("");
        }
    }
    return false;
}

// ---------------------------------------------------------------------------
// scheduler_run: main loop — priority-first, then TBRANCH state dispatch
// ---------------------------------------------------------------------------

// scheduler_run: one scheduling pass over THE process table.
//
// CHANGED 30 August 2026 -- ENHANCEMENT_PLAN §2.0. This function used to take
// no arguments and return nothing, and to build its own nine-PCB table as a
// LOCAL on every call: it aged that table, scheduled it, and discarded it when
// it returned. Four sites in this kernel printed "-> scheduler_run() invoked"
// and none of them called it, which was the honest choice while calling it
// would have scheduled a table nobody else could see.
//
// It now takes the table. It MUTATES it in place rather than returning a copy,
// for the three measured reasons set out above `struct ProcTable` in
// kernel/process.mt -- chiefly that a struct parameter in this language IS a
// mutable reference, so a returned "copy" would be a second name for the same
// object.
//
// Free slots are skipped. The old local table was always full, so it never had
// to ask; a real table has holes.
fn scheduler_run(t: ProcTable) {
    io::println("[SCHED] scheduler_run: priority-aware scheduling pass");
    io::println("[SCHED] priority order: HIGH(+) -> NORMAL(0) -> LOW(-)");
    io::println("[SCHED] quantum: 3 ticks per process");
    io::println("");

    // --- Aging: a scheduler tick elapsed for every live process ---
    // (dispatch below resets age to 0; terminal processes do not age)
    //
    // Every slot is read through `slot_at(t, i)` rather than bound to a local:
    // `let p = slot_at(t, i);` inside a `while` is a move on each iteration and
    // the borrow checker refuses it. Passing to a function does not move.
    let mut i = 0;
    while i < 9 {
        if !slot_is_free(slot_at(t, i)) {
            tif get_primary(slot_at(t, i).state) {
                + => { table_age(t, i); }
                0 => { table_age(t, i); }
                - => {}
            }
        }
        i = i + 1;
    }

    // --- Pass 1: HIGH priority processes ---
    io::println("  === HIGH priority pass ===");
    i = 0;
    while i < 9 {
        if !slot_is_free(slot_at(t, i)) {
            tif slot_at(t, i).priority {
                + => { table_schedule(t, i); }
                0 => {}
                - => {}
            }
        }
        i = i + 1;
    }

    // --- Pass 2: NORMAL priority processes ---
    io::println("  === NORMAL priority pass ===");
    i = 0;
    while i < 9 {
        if !slot_is_free(slot_at(t, i)) {
            tif slot_at(t, i).priority {
                + => {}
                0 => { table_schedule(t, i); }
                - => {}
            }
        }
        i = i + 1;
    }

    // --- Pass 3: LOW priority processes ---
    io::println("  === LOW priority pass ===");
    i = 0;
    while i < 9 {
        if !slot_is_free(slot_at(t, i)) {
            tif slot_at(t, i).priority {
                + => {}
                0 => {}
                - => { table_schedule(t, i); }
            }
        }
        i = i + 1;
    }

    io::println("[SCHED] scheduler_run: pass complete");
}

// ---------------------------------------------------------------------------
// process_init: initialise process table
// ---------------------------------------------------------------------------

// process_init: describe the process model AND build the table.
//
// It returned nothing until 30 August 2026, so its first line -- "9-slot
// process table initialised" -- was the only initialising it did. §2.0.
fn process_init() -> ProcTable {
    io::println("[PROC] process_init: 9-slot process table initialised");
    io::println("  States:");
    io::println("    +4=EXECUTING  +3=READY  +2=YIELDED  (ACTIVE, sign=+1)");
    io::println("     0=IO_WAIT   -1=MSG_WAIT  -2=SLEEP  (DORMANT, sign=0)");
    io::println("    -3=EXITED  -4=KILLED  -5=FAULTED    (TERMINAL, sign=-1)");
    io::println("  Priorities: HIGH(+) NORMAL(0) LOW(-)");
    io::println("  Quantum: 3 ticks | Starvation: promote after 9 idle ticks");
    return proc_table_init();
}

// ---------------------------------------------------------------------------
// starvation demo
// ---------------------------------------------------------------------------
