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
    return PCB { pid: pid, state: state, pc: 0, sp: 0,
                 privilege: 0, page_table: 0, parent_pid: 0,
                 priority: pri, age: 0, quantum_used: 0 };
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

fn check_starvation(p: PCB) -> PCB {
    if p.age >= 9 {
        // Starvation detected — promote priority
        tif p.priority {
            - => {
                io::print("    [STARVATION] PID=");
                io::print_int(p.pid);
                io::println(" LOW->NORMAL after 9 idle ticks");
                return PCB { ..p, priority: 0, age: 0, quantum_used: 0 };
            }
            0 => {
                io::print("    [STARVATION] PID=");
                io::print_int(p.pid);
                io::println(" NORMAL->HIGH after 9 idle ticks");
                return PCB { ..p, priority: +, age: 0, quantum_used: 0 };
            }
            + => return p,
        }
    }
    return p;
}

// ---------------------------------------------------------------------------
// age_tick: one scheduler tick has elapsed without dispatch — age the PCB
// ---------------------------------------------------------------------------

fn age_tick(p: PCB) -> PCB {
    return PCB { ..p, age: p.age + 1 };
}

// ---------------------------------------------------------------------------
// schedule_pcb: starvation check + TBRANCH state dispatch for one PCB.
// Returns the updated PCB (promotion, age reset, quantum accounting) so the
// caller can write it back into the process table.
// ---------------------------------------------------------------------------

fn schedule_pcb(idx: int, p: PCB) -> PCB {
    let primary = get_primary(p.state);
    let p2 = check_starvation(p);
    io::print("  PCB[");
    io::print_int(idx);
    io::print("] PID=");
    io::print_int(p.pid);
    io::print(" state=");
    io::print(state_name(p.state));
    io::print(" pri=");
    io::print(priority_name(p.priority));
    io::print(" age=");
    io::print_int(p2.age);
    io::print(" primary=");
    io::println_trit(primary);

    tif primary {
        + => {
            io::println("    [ACTIVE]");
            if p2.quantum_used >= 3 {
                io::print("    [QUANTUM] PID=");
                io::print_int(p2.pid);
                io::println(" used 3 ticks — preempted, quantum reset");
                io::println("");
                return PCB { ..p2, quantum_used: 0 };
            }
            dispatch_active(p2);
            io::println("");
            // Dispatched: age resets, one quantum tick consumed
            return PCB { ..p2, age: 0, quantum_used: p2.quantum_used + 1 };
        }
        0 => {
            io::println("    [DORMANT]");
            let _ = check_wakeup(p2);
            io::println("");
            return p2;
        }
        - => {
            io::println("    [TERMINAL]");
            reap_process(p2);
            io::println("");
            return p2;
        }
    }
}

// ---------------------------------------------------------------------------
// scheduler_run: main loop — priority-first, then TBRANCH state dispatch
// ---------------------------------------------------------------------------

fn scheduler_run() {
    io::println("[SCHED] scheduler_run: priority-aware scheduling pass");
    io::println("[SCHED] priority order: HIGH(+) -> NORMAL(0) -> LOW(-)");
    io::println("[SCHED] quantum: 3 ticks per process");
    io::println("");

    // Process table: 9 PCBs with varied states and priorities
    let mut pcbs: [PCB] = [
        make_pcb_prio(0, 3, +),   // idle, READY, HIGH
        make_pcb_prio(1, 4, 0),   // init, EXECUTING, NORMAL
        make_pcb_prio(2, 2, -),   // worker, YIELDED, LOW
        make_pcb_prio(3, 0, 0),   // IO_WAIT, NORMAL
        make_pcb_prio(4, -1, +),  // MSG_WAIT, HIGH
        make_pcb_prio(5, -2, -),  // SLEEP, LOW
        make_pcb_prio(6, -3, 0),  // EXITED, NORMAL
        make_pcb_prio(7, -4, -),  // KILLED, LOW
        make_pcb_prio(8, -5, +),  // FAULTED, HIGH
    ];

    // --- Aging: a scheduler tick elapsed for every live process ---
    // (dispatch below resets age to 0; terminal processes do not age)
    let mut i = 0;
    while i < 9 {
        let p = pcbs[i];
        let pr = get_primary(p.state);
        tif pr {
            + => { pcbs[i] = age_tick(p); }
            0 => { pcbs[i] = age_tick(p); }
            - => {}
        }
        i = i + 1;
    }

    // --- Pass 1: HIGH priority processes ---
    io::println("  === HIGH priority pass ===");
    i = 0;
    while i < 9 {
        let p = pcbs[i];
        tif p.priority {
            + => { pcbs[i] = schedule_pcb(i, p); }
            0 => {}
            - => {}
        }
        i = i + 1;
    }

    // --- Pass 2: NORMAL priority processes ---
    io::println("  === NORMAL priority pass ===");
    i = 0;
    while i < 9 {
        let p = pcbs[i];
        tif p.priority {
            + => {}
            0 => { pcbs[i] = schedule_pcb(i, p); }
            - => {}
        }
        i = i + 1;
    }

    // --- Pass 3: LOW priority processes ---
    io::println("  === LOW priority pass ===");
    i = 0;
    while i < 9 {
        let p = pcbs[i];
        tif p.priority {
            + => {}
            0 => {}
            - => { pcbs[i] = schedule_pcb(i, p); }
        }
        i = i + 1;
    }

    io::println("[SCHED] scheduler_run: pass complete");
}

// ---------------------------------------------------------------------------
// process_init: initialise process table
// ---------------------------------------------------------------------------

fn process_init() {
    io::println("[PROC] process_init: 9-slot process table initialised");
    io::println("  States:");
    io::println("    +4=EXECUTING  +3=READY  +2=YIELDED  (ACTIVE, sign=+1)");
    io::println("     0=IO_WAIT   -1=MSG_WAIT  -2=SLEEP  (DORMANT, sign=0)");
    io::println("    -3=EXITED  -4=KILLED  -5=FAULTED    (TERMINAL, sign=-1)");
    io::println("  Priorities: HIGH(+) NORMAL(0) LOW(-)");
    io::println("  Quantum: 3 ticks | Starvation: promote after 9 idle ticks");
}

// ---------------------------------------------------------------------------
// starvation demo
// ---------------------------------------------------------------------------
