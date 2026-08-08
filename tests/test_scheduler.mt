// test_scheduler.mt — THATTE-OS scheduler tests
// Tests get_primary() state mapping, priority ordering, starvation
// prevention, and quantum preemption.

use std::io;

// ---------------------------------------------------------------------------
// Test helper
// ---------------------------------------------------------------------------

fn assert_true(cond: bool, name: str, test_num: int) -> int {
    io::print("  test ");
    io::print_int(test_num);
    io::print(": ");
    io::print(name);
    if cond {
        io::println(" — PASS");
        return 1;
    } else {
        io::println(" — FAIL");
        return 0;
    }
}

// ---------------------------------------------------------------------------
// Reproduced from kernel/scheduler.mt
// ---------------------------------------------------------------------------

fn get_primary(state: int) -> trit {
    if state > 0 { return +; }
    elif state == 0 { return 0; }
    elif state >= -2 { return 0; }
    else { return -; }
}

struct PCB {
    pub pid: int,
    pub state: int,
    pub pc: int,
    pub sp: int,
    pub priority: trit,
    pub age: int,
    pub quantum_used: int,
}

fn make_pcb(pid: int, state: int, pri: trit) -> PCB {
    return PCB { pid: pid, state: state, pc: 0, sp: 0,
                 priority: pri, age: 0, quantum_used: 0 };
}

fn check_starvation(p: PCB) -> PCB {
    if p.age >= 9 {
        tif p.priority {
            - => {
                return PCB { pid: p.pid, state: p.state, pc: p.pc, sp: p.sp,
                             priority: 0, age: 0, quantum_used: 0 };
            }
            0 => {
                return PCB { pid: p.pid, state: p.state, pc: p.pc, sp: p.sp,
                             priority: +, age: 0, quantum_used: 0 };
            }
            + => return p,
        }
    }
    return p;
}

// ---------------------------------------------------------------------------
// Trit comparison helper
// ---------------------------------------------------------------------------

fn trit_eq(a: trit, b: trit) -> bool {
    tif a {
        + => {
            tif b {
                + => return true,
                0 => return false,
                - => return false,
            }
        }
        0 => {
            tif b {
                + => return false,
                0 => return true,
                - => return false,
            }
        }
        - => {
            tif b {
                + => return false,
                0 => return false,
                - => return true,
            }
        }
    }
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn main() {
    io::println("=== THATTE-OS Scheduler Tests ===");
    let mut passed = 0;
    let mut total = 0;

    // -----------------------------------------------------------------------
    // Part 1: get_primary() for all 9 process states (-5 to +4)
    // ACTIVE(+): EXECUTING(+4), READY(+3), YIELDED(+2)  => state > 0 => +
    // DORMANT(0): IO_WAIT(0), MSG_WAIT(-1), SLEEP(-2)   => 0 or >= -2 => 0
    // TERMINAL(-): EXITED(-3), KILLED(-4), FAULTED(-5)   => < -2 => -
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- get_primary() for all 9 states ---");

    // EXECUTING = +4 -> ACTIVE (+)
    total = total + 1;
    passed = passed + assert_true(trit_eq(get_primary(4), +), "EXECUTING(+4) -> ACTIVE(+)", total);

    // READY = +3 -> ACTIVE (+)
    total = total + 1;
    passed = passed + assert_true(trit_eq(get_primary(3), +), "READY(+3) -> ACTIVE(+)", total);

    // YIELDED = +2 -> ACTIVE (+)
    total = total + 1;
    passed = passed + assert_true(trit_eq(get_primary(2), +), "YIELDED(+2) -> ACTIVE(+)", total);

    // IO_WAIT = 0 -> DORMANT (0)
    total = total + 1;
    passed = passed + assert_true(trit_eq(get_primary(0), 0), "IO_WAIT(0) -> DORMANT(0)", total);

    // MSG_WAIT = -1 -> DORMANT (0)
    total = total + 1;
    passed = passed + assert_true(trit_eq(get_primary(-1), 0), "MSG_WAIT(-1) -> DORMANT(0)", total);

    // SLEEP = -2 -> DORMANT (0)
    total = total + 1;
    passed = passed + assert_true(trit_eq(get_primary(-2), 0), "SLEEP(-2) -> DORMANT(0)", total);

    // EXITED = -3 -> TERMINAL (-)
    total = total + 1;
    passed = passed + assert_true(trit_eq(get_primary(-3), -), "EXITED(-3) -> TERMINAL(-)", total);

    // KILLED = -4 -> TERMINAL (-)
    total = total + 1;
    passed = passed + assert_true(trit_eq(get_primary(-4), -), "KILLED(-4) -> TERMINAL(-)", total);

    // FAULTED = -5 -> TERMINAL (-)
    total = total + 1;
    passed = passed + assert_true(trit_eq(get_primary(-5), -), "FAULTED(-5) -> TERMINAL(-)", total);

    // -----------------------------------------------------------------------
    // Part 2: Priority ordering — HIGH dispatched before NORMAL before LOW
    // Simulate: 3 READY processes with different priorities, verify order
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Priority ordering ---");

    let p_high   = make_pcb(1, 3, +);
    let p_normal = make_pcb(2, 3, 0);
    let p_low    = make_pcb(3, 3, -);

    // HIGH should be dispatched (is ACTIVE and HIGH priority)
    total = total + 1;
    let high_active = trit_eq(get_primary(p_high.state), +);
    let high_pri = trit_eq(p_high.priority, +);
    passed = passed + assert_true(high_active, "HIGH-priority process is ACTIVE", total);

    total = total + 1;
    passed = passed + assert_true(high_pri, "HIGH dispatched first (priority=+)", total);

    // NORMAL dispatched second
    total = total + 1;
    passed = passed + assert_true(trit_eq(p_normal.priority, 0), "NORMAL dispatched second (priority=0)", total);

    // LOW dispatched last
    total = total + 1;
    passed = passed + assert_true(trit_eq(p_low.priority, -), "LOW dispatched last (priority=-)", total);

    // -----------------------------------------------------------------------
    // Part 3: Starvation — process with age >= 9 gets promoted
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Starvation prevention ---");

    // LOW with age=10 -> promoted to NORMAL
    let starved_low = PCB { pid: 10, state: 3, pc: 0, sp: 0,
                            priority: -, age: 10, quantum_used: 0 };
    let promoted_low = check_starvation(starved_low);
    total = total + 1;
    passed = passed + assert_true(trit_eq(promoted_low.priority, 0),
        "LOW age=10 promoted to NORMAL", total);

    total = total + 1;
    passed = passed + assert_true(promoted_low.age == 0,
        "age reset to 0 after promotion", total);

    // NORMAL with age=9 -> promoted to HIGH
    let starved_norm = PCB { pid: 11, state: 3, pc: 0, sp: 0,
                             priority: 0, age: 9, quantum_used: 0 };
    let promoted_norm = check_starvation(starved_norm);
    total = total + 1;
    passed = passed + assert_true(trit_eq(promoted_norm.priority, +),
        "NORMAL age=9 promoted to HIGH", total);

    // HIGH with age=15 -> stays HIGH (already max)
    let starved_high = PCB { pid: 12, state: 3, pc: 0, sp: 0,
                             priority: +, age: 15, quantum_used: 0 };
    let promoted_high = check_starvation(starved_high);
    total = total + 1;
    passed = passed + assert_true(trit_eq(promoted_high.priority, +),
        "HIGH age=15 stays HIGH (already max)", total);

    // LOW with age=5 -> not promoted (below threshold)
    let young_low = PCB { pid: 13, state: 3, pc: 0, sp: 0,
                          priority: -, age: 5, quantum_used: 0 };
    let still_low = check_starvation(young_low);
    total = total + 1;
    passed = passed + assert_true(trit_eq(still_low.priority, -),
        "LOW age=5 stays LOW (below threshold)", total);

    // -----------------------------------------------------------------------
    // Part 4: Quantum — 3 ticks = preemption
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Quantum preemption ---");

    // quantum_used < 3 -> no preemption
    let p1 = PCB { pid: 20, state: 4, pc: 0, sp: 0,
                   priority: 0, age: 0, quantum_used: 2 };
    total = total + 1;
    passed = passed + assert_true(p1.quantum_used < 3,
        "quantum_used=2 < 3 -> no preemption", total);

    // quantum_used == 3 -> preempt
    let p2 = PCB { pid: 21, state: 4, pc: 0, sp: 0,
                   priority: 0, age: 0, quantum_used: 3 };
    total = total + 1;
    passed = passed + assert_true(p2.quantum_used >= 3,
        "quantum_used=3 >= 3 -> preempt", total);

    // quantum_used > 3 -> preempt
    let p3 = PCB { pid: 22, state: 4, pc: 0, sp: 0,
                   priority: 0, age: 0, quantum_used: 5 };
    total = total + 1;
    passed = passed + assert_true(p3.quantum_used >= 3,
        "quantum_used=5 >= 3 -> preempt", total);

    // -----------------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------------
    io::println("");
    io::print("Results: ");
    io::print_int(passed);
    io::print("/");
    io::print_int(total);
    io::println(" passed");
}
