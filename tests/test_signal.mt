// test_signal.mt — THATTE-OS signal handling tests
// Tests all 9 signal types, delivery, masking/blocking,
// uncatchable SIG_KILL, custom signal handlers, and dispositions.
//
// Author: Manish Jagdish Thatte

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
// Reproduced from kernel/signal.mt (minimal, assertion-friendly)
// ---------------------------------------------------------------------------

fn signal_name(sig: int) -> str {
    if sig == -4 { return "SIG_KILL"; }
    elif sig == -3 { return "SIG_STOP"; }
    elif sig == -2 { return "SIG_TERM"; }
    elif sig == -1 { return "SIG_INT"; }
    elif sig == 0 { return "SIG_NULL"; }
    elif sig == 1 { return "SIG_CONT"; }
    elif sig == 2 { return "SIG_USR1"; }
    elif sig == 3 { return "SIG_USR2"; }
    elif sig == 4 { return "SIG_CHLD"; }
    else { return "UNKNOWN"; }
}

fn default_action(sig: int) -> str {
    if sig == -4 { return "KILL"; }
    elif sig == -3 { return "STOP"; }
    elif sig == -2 { return "TERMINATE"; }
    elif sig == -1 { return "TERMINATE"; }
    elif sig == 0 { return "NOOP"; }
    elif sig == 1 { return "CONTINUE"; }
    elif sig == 2 { return "IGNORE"; }
    elif sig == 3 { return "IGNORE"; }
    elif sig == 4 { return "IGNORE"; }
    else { return "UNKNOWN"; }
}

struct SignalTable {
    pub pid: int,
    pub d0: trit,   // SIG_KILL (-4): always DEFAULT, cannot override
    pub d1: trit,   // SIG_STOP (-3)
    pub d2: trit,   // SIG_TERM (-2)
    pub d3: trit,   // SIG_INT  (-1)
    pub d4: trit,   // SIG_NULL  (0)
    pub d5: trit,   // SIG_CONT (+1)
    pub d6: trit,   // SIG_USR1 (+2)
    pub d7: trit,   // SIG_USR2 (+3)
    pub d8: trit,   // SIG_CHLD (+4)
    // Signal mask: +1 = unblocked, 0 = deferred, -1 = blocked
    pub m0: trit, pub m1: trit, pub m2: trit,
    pub m3: trit, pub m4: trit, pub m5: trit,
    pub m6: trit, pub m7: trit, pub m8: trit,
}

fn default_signal_table(pid: int) -> SignalTable {
    return SignalTable {
        pid: pid,
        d0: 0, d1: 0, d2: 0, d3: 0, d4: 0, d5: 0,
        d6: -, d7: -, d8: -,
        // All signals unblocked by default
        m0: +, m1: +, m2: +, m3: +, m4: +, m5: +, m6: +, m7: +, m8: +,
    };
}

fn get_disposition(table: SignalTable, sig: int) -> trit {
    let idx = sig + 4;
    if idx == 0 { return table.d0; }
    elif idx == 1 { return table.d1; }
    elif idx == 2 { return table.d2; }
    elif idx == 3 { return table.d3; }
    elif idx == 4 { return table.d4; }
    elif idx == 5 { return table.d5; }
    elif idx == 6 { return table.d6; }
    elif idx == 7 { return table.d7; }
    else { return table.d8; }
}

fn get_mask(table: SignalTable, sig: int) -> trit {
    let idx = sig + 4;
    if idx == 0 { return table.m0; }
    elif idx == 1 { return table.m1; }
    elif idx == 2 { return table.m2; }
    elif idx == 3 { return table.m3; }
    elif idx == 4 { return table.m4; }
    elif idx == 5 { return table.m5; }
    elif idx == 6 { return table.m6; }
    elif idx == 7 { return table.m7; }
    else { return table.m8; }
}

fn disposition_name(d: trit) -> str {
    tif d {
        + => return "CATCH",
        0 => return "DEFAULT",
        - => return "IGNORE",
    }
}

fn trit_eq(a: trit, b: trit) -> bool {
    tif a {
        + => { tif b { + => return true, 0 => return false, - => return false } }
        0 => { tif b { + => return false, 0 => return true, - => return false } }
        - => { tif b { + => return false, 0 => return false, - => return true } }
    }
}

// sys_signal: install new disposition. SIG_KILL and SIG_STOP cannot be changed.
fn sys_signal(table: SignalTable, sig: int, new_disp: trit) -> SignalTable {
    if sig == -4 { return table; }   // SIG_KILL: cannot override
    if sig == -3 { return table; }   // SIG_STOP: cannot override

    let idx = sig + 4;
    if idx == 2 { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: new_disp, d3: table.d3, d4: table.d4, d5: table.d5, d6: table.d6, d7: table.d7, d8: table.d8, m0: table.m0, m1: table.m1, m2: table.m2, m3: table.m3, m4: table.m4, m5: table.m5, m6: table.m6, m7: table.m7, m8: table.m8 }; }
    elif idx == 3 { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: new_disp, d4: table.d4, d5: table.d5, d6: table.d6, d7: table.d7, d8: table.d8, m0: table.m0, m1: table.m1, m2: table.m2, m3: table.m3, m4: table.m4, m5: table.m5, m6: table.m6, m7: table.m7, m8: table.m8 }; }
    elif idx == 4 { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: table.d3, d4: new_disp, d5: table.d5, d6: table.d6, d7: table.d7, d8: table.d8, m0: table.m0, m1: table.m1, m2: table.m2, m3: table.m3, m4: table.m4, m5: table.m5, m6: table.m6, m7: table.m7, m8: table.m8 }; }
    elif idx == 5 { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: table.d3, d4: table.d4, d5: new_disp, d6: table.d6, d7: table.d7, d8: table.d8, m0: table.m0, m1: table.m1, m2: table.m2, m3: table.m3, m4: table.m4, m5: table.m5, m6: table.m6, m7: table.m7, m8: table.m8 }; }
    elif idx == 6 { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: table.d3, d4: table.d4, d5: table.d5, d6: new_disp, d7: table.d7, d8: table.d8, m0: table.m0, m1: table.m1, m2: table.m2, m3: table.m3, m4: table.m4, m5: table.m5, m6: table.m6, m7: table.m7, m8: table.m8 }; }
    elif idx == 7 { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: table.d3, d4: table.d4, d5: table.d5, d6: table.d6, d7: new_disp, d8: table.d8, m0: table.m0, m1: table.m1, m2: table.m2, m3: table.m3, m4: table.m4, m5: table.m5, m6: table.m6, m7: table.m7, m8: table.m8 }; }
    else { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: table.d3, d4: table.d4, d5: table.d5, d6: table.d6, d7: table.d7, d8: new_disp, m0: table.m0, m1: table.m1, m2: table.m2, m3: table.m3, m4: table.m4, m5: table.m5, m6: table.m6, m7: table.m7, m8: table.m8 }; }
}

// sys_sigmask: set signal mask for a given signal.
// +1 = unblocked, 0 = deferred, -1 = blocked
// SIG_KILL (-4) cannot be blocked.
fn sys_sigmask(table: SignalTable, sig: int, mask: trit) -> SignalTable {
    if sig == -4 { return table; }   // SIG_KILL: cannot block

    let idx = sig + 4;
    if idx == 1 { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: table.d3, d4: table.d4, d5: table.d5, d6: table.d6, d7: table.d7, d8: table.d8, m0: table.m0, m1: mask, m2: table.m2, m3: table.m3, m4: table.m4, m5: table.m5, m6: table.m6, m7: table.m7, m8: table.m8 }; }
    elif idx == 2 { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: table.d3, d4: table.d4, d5: table.d5, d6: table.d6, d7: table.d7, d8: table.d8, m0: table.m0, m1: table.m1, m2: mask, m3: table.m3, m4: table.m4, m5: table.m5, m6: table.m6, m7: table.m7, m8: table.m8 }; }
    elif idx == 3 { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: table.d3, d4: table.d4, d5: table.d5, d6: table.d6, d7: table.d7, d8: table.d8, m0: table.m0, m1: table.m1, m2: table.m2, m3: mask, m4: table.m4, m5: table.m5, m6: table.m6, m7: table.m7, m8: table.m8 }; }
    elif idx == 4 { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: table.d3, d4: table.d4, d5: table.d5, d6: table.d6, d7: table.d7, d8: table.d8, m0: table.m0, m1: table.m1, m2: table.m2, m3: table.m3, m4: mask, m5: table.m5, m6: table.m6, m7: table.m7, m8: table.m8 }; }
    elif idx == 5 { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: table.d3, d4: table.d4, d5: table.d5, d6: table.d6, d7: table.d7, d8: table.d8, m0: table.m0, m1: table.m1, m2: table.m2, m3: table.m3, m4: table.m4, m5: mask, m6: table.m6, m7: table.m7, m8: table.m8 }; }
    elif idx == 6 { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: table.d3, d4: table.d4, d5: table.d5, d6: table.d6, d7: table.d7, d8: table.d8, m0: table.m0, m1: table.m1, m2: table.m2, m3: table.m3, m4: table.m4, m5: table.m5, m6: mask, m7: table.m7, m8: table.m8 }; }
    elif idx == 7 { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: table.d3, d4: table.d4, d5: table.d5, d6: table.d6, d7: table.d7, d8: table.d8, m0: table.m0, m1: table.m1, m2: table.m2, m3: table.m3, m4: table.m4, m5: table.m5, m6: table.m6, m7: mask, m8: table.m8 }; }
    else { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: table.d3, d4: table.d4, d5: table.d5, d6: table.d6, d7: table.d7, d8: table.d8, m0: table.m0, m1: table.m1, m2: table.m2, m3: table.m3, m4: table.m4, m5: table.m5, m6: table.m6, m7: table.m7, m8: mask }; }
}

// deliver_signal: returns action string for testing
// Returns: "KILLED" | "CATCH" | "DEFAULT" | "IGNORE" | "BLOCKED"
fn deliver_signal(table: SignalTable, sig: int) -> str {
    // SIG_KILL is unconditional and unblockable
    if sig == -4 {
        return "KILLED";
    }

    // Check mask first
    let mask = get_mask(table, sig);
    tif mask {
        + => {
            // Unblocked — check disposition
        }
        0 => {
            return "DEFERRED";
        }
        - => {
            return "BLOCKED";
        }
    }

    let disp = get_disposition(table, sig);
    tif disp {
        + => return "CATCH",
        0 => return "DEFAULT",
        - => return "IGNORE",
    }
}

// sys_kill: returns +1 (success) or -1 (denied)
fn sys_kill(sender_pid: int, target_pid: int, sig: int, sender_priv: trit) -> trit {
    if sig < -4 || sig > 4 { return -; }
    if target_pid < 0 || target_pid > 8 { return -; }

    tif sender_priv {
        + => { }
        0 => { }
        - => {
            if sender_pid != target_pid { return -; }
        }
    }
    return +;
}

fn is_success(v: trit) -> bool {
    tif v { + => return true, 0 => return false, - => return false }
}

fn is_denied_t(v: trit) -> bool {
    tif v { + => return false, 0 => return false, - => return true }
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn main() {
    io::println("=== THATTE-OS Signal Handling Tests ===");
    let mut passed = 0;
    let mut total = 0;

    // -----------------------------------------------------------------------
    // Part 1: All 9 signal types — names and default dispositions
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Signal names and defaults ---");

    let table = default_signal_table(3);

    total = total + 1;
    passed = passed + assert_true(signal_name(-4) == "SIG_KILL",
        "signal -4 is SIG_KILL", total);

    total = total + 1;
    passed = passed + assert_true(signal_name(-3) == "SIG_STOP",
        "signal -3 is SIG_STOP", total);

    total = total + 1;
    passed = passed + assert_true(signal_name(0) == "SIG_NULL",
        "signal  0 is SIG_NULL", total);

    total = total + 1;
    passed = passed + assert_true(signal_name(4) == "SIG_CHLD",
        "signal +4 is SIG_CHLD", total);

    // Default dispositions: SIG_KILL..SIG_CONT = DEFAULT(0), USR1/USR2/CHLD = IGNORE(-)
    total = total + 1;
    passed = passed + assert_true(trit_eq(get_disposition(table, -4), 0),
        "SIG_KILL default disposition is DEFAULT", total);

    total = total + 1;
    passed = passed + assert_true(trit_eq(get_disposition(table, 2), -),
        "SIG_USR1 default disposition is IGNORE", total);

    // -----------------------------------------------------------------------
    // Part 2: Signal delivery to a process
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Signal delivery ---");

    total = total + 1;
    passed = passed + assert_true(deliver_signal(table, -2) == "DEFAULT",
        "SIG_TERM delivered with DEFAULT action", total);

    total = total + 1;
    passed = passed + assert_true(deliver_signal(table, 2) == "IGNORE",
        "SIG_USR1 delivered with IGNORE action", total);

    // -----------------------------------------------------------------------
    // Part 3: Signal masking/blocking
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Signal masking ---");

    // Block SIG_INT (-1)
    let t_blocked = sys_sigmask(table, -1, -);

    total = total + 1;
    passed = passed + assert_true(deliver_signal(t_blocked, -1) == "BLOCKED",
        "SIG_INT blocked after sys_sigmask", total);

    // Defer SIG_TERM (-2)
    let t_deferred = sys_sigmask(table, -2, 0);

    total = total + 1;
    passed = passed + assert_true(deliver_signal(t_deferred, -2) == "DEFERRED",
        "SIG_TERM deferred after sys_sigmask", total);

    // -----------------------------------------------------------------------
    // Part 4: SIG_KILL (-4) cannot be caught, ignored, or blocked
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- SIG_KILL uncatchable ---");

    // Attempt to change SIG_KILL disposition to CATCH
    let t_kill_catch = sys_signal(table, -4, +);
    total = total + 1;
    passed = passed + assert_true(trit_eq(get_disposition(t_kill_catch, -4), 0),
        "SIG_KILL disposition unchanged after CATCH attempt", total);

    // SIG_KILL always kills, even if we try to block it
    let t_kill_block = sys_sigmask(table, -4, -);
    total = total + 1;
    passed = passed + assert_true(deliver_signal(t_kill_block, -4) == "KILLED",
        "SIG_KILL delivers KILLED even after block attempt", total);

    // SIG_KILL unconditional
    total = total + 1;
    passed = passed + assert_true(deliver_signal(table, -4) == "KILLED",
        "SIG_KILL always returns KILLED", total);

    // -----------------------------------------------------------------------
    // Part 5: Custom signal handlers
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Custom handlers ---");

    // Install CATCH handler for SIG_INT
    let t_catch = sys_signal(table, -1, +);

    total = total + 1;
    passed = passed + assert_true(trit_eq(get_disposition(t_catch, -1), +),
        "SIG_INT disposition changed to CATCH", total);

    total = total + 1;
    passed = passed + assert_true(deliver_signal(t_catch, -1) == "CATCH",
        "SIG_INT delivered with CATCH action", total);

    // Install IGNORE for SIG_TERM
    let t_ign = sys_signal(table, -2, -);

    total = total + 1;
    passed = passed + assert_true(deliver_signal(t_ign, -2) == "IGNORE",
        "SIG_TERM delivered with IGNORE after install", total);

    // SIG_STOP cannot be caught
    let t_stop_catch = sys_signal(table, -3, +);
    total = total + 1;
    passed = passed + assert_true(trit_eq(get_disposition(t_stop_catch, -3), 0),
        "SIG_STOP disposition unchanged after CATCH attempt", total);

    // -----------------------------------------------------------------------
    // Part 6: sys_kill privilege enforcement
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- sys_kill privilege ---");

    total = total + 1;
    passed = passed + assert_true(is_success(sys_kill(0, 3, -2, +)),
        "KERNEL can signal any process", total);

    total = total + 1;
    passed = passed + assert_true(is_denied_t(sys_kill(5, 3, -2, -)),
        "USER cannot signal other process", total);

    total = total + 1;
    passed = passed + assert_true(is_success(sys_kill(5, 5, -2, -)),
        "USER can signal self", total);

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
