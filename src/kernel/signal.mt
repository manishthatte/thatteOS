// kernel/signal.mt — THATTE-OS signal handling
// Module 16: 9 signals, signal delivery, default handlers
//
// Demonstrates P5 Claims:
//   Claim 4  — SYS_KILL, SYS_SIGNAL syscalls
//   Claim 6  — Signal delivery via IPC message infrastructure
//
// 9 signals indexed -4 to +4 (ternary-native):
//   -4 = SIG_KILL   (unconditional terminate, cannot be caught)
//   -3 = SIG_STOP   (pause process)
//   -2 = SIG_TERM   (request termination)
//   -1 = SIG_INT    (keyboard interrupt)
//    0 = SIG_NULL   (test if process exists)
//   +1 = SIG_CONT   (resume stopped process)
//   +2 = SIG_USR1   (user-defined 1)
//   +3 = SIG_USR2   (user-defined 2)
//   +4 = SIG_CHLD   (child process status change)

use std::io;

// ---------------------------------------------------------------------------
// Signal constants and names
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

// ---------------------------------------------------------------------------
// Signal disposition (per-process)
// ---------------------------------------------------------------------------
// Each process has 9 signal dispositions:
//   +1 = catch (user handler installed)
//    0 = default (use kernel default action)
//   -1 = ignore

struct SignalTable {
    pub pid: int,
    // Dispositions for signals -4 to +4 (indexed as 0..8)
    pub d0: trit,   // SIG_KILL (always 0 — cannot override)
    pub d1: trit,   // SIG_STOP
    pub d2: trit,   // SIG_TERM
    pub d3: trit,   // SIG_INT
    pub d4: trit,   // SIG_NULL
    pub d5: trit,   // SIG_CONT
    pub d6: trit,   // SIG_USR1
    pub d7: trit,   // SIG_USR2
    pub d8: trit,   // SIG_CHLD
}

fn default_signal_table(pid: int) -> SignalTable {
    return SignalTable {
        pid: pid,
        d0: 0,   // SIG_KILL: always default (cannot change)
        d1: 0,   // SIG_STOP: default
        d2: 0,   // SIG_TERM: default
        d3: 0,   // SIG_INT:  default
        d4: 0,   // SIG_NULL: default
        d5: 0,   // SIG_CONT: default
        d6: -,   // SIG_USR1: ignore by default
        d7: -,   // SIG_USR2: ignore by default
        d8: -,   // SIG_CHLD: ignore by default
    };
}

fn get_disposition(table: SignalTable, sig: int) -> trit {
    let idx = sig + 4;  // map -4..+4 to 0..8
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

fn disposition_name(d: trit) -> str {
    tif d {
        + => return "CATCH",
        0 => return "DEFAULT",
        - => return "IGNORE",
    }
}

// ---------------------------------------------------------------------------
// Default signal actions
// ---------------------------------------------------------------------------

fn default_action(sig: int) -> str {
    if sig == -4 { return "KILL (unconditional, state=KILLED(-4))"; }
    elif sig == -3 { return "STOP (state=SLEEP(-2))"; }
    elif sig == -2 { return "TERMINATE (state=EXITED(-3))"; }
    elif sig == -1 { return "TERMINATE (state=EXITED(-3))"; }
    elif sig == 0 { return "NOOP (test existence)"; }
    elif sig == 1 { return "CONTINUE (state=READY(+3))"; }
    elif sig == 2 { return "IGNORE (user-defined)"; }
    elif sig == 3 { return "IGNORE (user-defined)"; }
    elif sig == 4 { return "IGNORE (child status)"; }
    else { return "UNKNOWN"; }
}

// ---------------------------------------------------------------------------
// sys_kill: send signal to process
// ---------------------------------------------------------------------------

fn sys_kill(sender_pid: int, target_pid: int, sig: int, sender_priv: trit) -> trit {
    io::print("[SYS_KILL] sender=");
    io::print_int(sender_pid);
    io::print(" target=");
    io::print_int(target_pid);
    io::print(" signal=");
    io::print(signal_name(sig));
    io::print("(");
    io::print_int(sig);
    io::println(")");

    // Validate signal range
    if sig < -4 || sig > 4 {
        io::println("  invalid signal number — REJECTED");
        return -;
    }

    // Validate PID
    if target_pid < 0 || target_pid > 8 {
        io::println("  invalid target PID — REJECTED");
        return -;
    }

    // Privilege check: USER can only signal own processes
    // KERNEL/SERVICE can signal any
    tif sender_priv {
        + => {
            io::println("  privilege: KERNEL — allowed to signal any process");
        }
        0 => {
            io::println("  privilege: SERVICE — allowed to signal any process");
        }
        - => {
            if sender_pid != target_pid {
                io::println("  privilege: USER — can only signal own process");
                io::println("  SYS_KILL returns -1 (denied)");
                return -;
            }
            io::println("  privilege: USER — signaling self (allowed)");
        }
    }

    // SIG_NULL just checks existence
    if sig == 0 {
        io::print("  SIG_NULL: process ");
        io::print_int(target_pid);
        io::println(" exists");
        return +;
    }

    io::print("  delivering ");
    io::print(signal_name(sig));
    io::print(" to PID=");
    io::println_int(target_pid);

    return +;
}

// ---------------------------------------------------------------------------
// deliver_signal: execute signal on target process
// ---------------------------------------------------------------------------

fn deliver_signal(target_pid: int, sig: int, table: SignalTable) {
    let disposition = get_disposition(table, sig);

    io::print("[SIGNAL] deliver to PID=");
    io::print_int(target_pid);
    io::print(" signal=");
    io::print(signal_name(sig));
    io::print(" disposition=");
    io::println(disposition_name(disposition));

    // SIG_KILL cannot be caught or ignored
    if sig == -4 {
        io::println("  SIG_KILL: UNCONDITIONAL — process.state = KILLED(-4)");
        io::println("  (cannot be caught or ignored)");
        return;
    }

    tif disposition {
        + => {
            // User handler installed
            io::print("  CATCH: invoking user signal handler for ");
            io::println(signal_name(sig));
            io::println("  save context, jump to handler address");
        }
        0 => {
            // Default action
            io::print("  DEFAULT: ");
            io::println(default_action(sig));
        }
        - => {
            // Ignore
            io::print("  IGNORE: ");
            io::print(signal_name(sig));
            io::println(" ignored by process");
        }
    }
}

// ---------------------------------------------------------------------------
// sys_signal: install/change signal handler
// ---------------------------------------------------------------------------

fn sys_signal(table: SignalTable, sig: int, new_disp: trit) -> SignalTable {
    io::print("[SYS_SIGNAL] pid=");
    io::print_int(table.pid);
    io::print(" signal=");
    io::print(signal_name(sig));
    io::print(" new_disposition=");
    io::println(disposition_name(new_disp));

    // SIG_KILL and SIG_STOP cannot be caught or ignored
    if sig == -4 {
        io::println("  SIG_KILL: cannot change disposition — REJECTED");
        return table;
    }
    if sig == -3 {
        io::println("  SIG_STOP: cannot change disposition — REJECTED");
        return table;
    }

    io::print("  disposition changed to ");
    io::println(disposition_name(new_disp));

    // Return updated table (simplified — set the right slot)
    let idx = sig + 4;
    if idx == 2 { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: new_disp, d3: table.d3, d4: table.d4, d5: table.d5, d6: table.d6, d7: table.d7, d8: table.d8 }; }
    elif idx == 3 { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: new_disp, d4: table.d4, d5: table.d5, d6: table.d6, d7: table.d7, d8: table.d8 }; }
    elif idx == 4 { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: table.d3, d4: new_disp, d5: table.d5, d6: table.d6, d7: table.d7, d8: table.d8 }; }
    elif idx == 5 { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: table.d3, d4: table.d4, d5: new_disp, d6: table.d6, d7: table.d7, d8: table.d8 }; }
    elif idx == 6 { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: table.d3, d4: table.d4, d5: table.d5, d6: new_disp, d7: table.d7, d8: table.d8 }; }
    elif idx == 7 { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: table.d3, d4: table.d4, d5: table.d5, d6: table.d6, d7: new_disp, d8: table.d8 }; }
    else { return SignalTable { pid: table.pid, d0: table.d0, d1: table.d1, d2: table.d2, d3: table.d3, d4: table.d4, d5: table.d5, d6: table.d6, d7: table.d7, d8: new_disp }; }
}

// ---------------------------------------------------------------------------
// main: demonstrate signal handling
// ---------------------------------------------------------------------------
