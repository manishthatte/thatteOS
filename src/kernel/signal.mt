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
    // Handler ADDRESSES, one per signal (§2.4). A disposition of `+` means
    // "the process installed a handler"; without an address there was nothing
    // to jump to, which is why `deliver_signal` could only print "save
    // context, jump to handler address" and do neither. 0 = none installed.
    pub h0: int, pub h1: int, pub h2: int,
    pub h3: int, pub h4: int, pub h5: int,
    pub h6: int, pub h7: int, pub h8: int,
}

fn get_handler(table: SignalTable, sig: int) -> int {
    let idx = sig + 4;
    if idx == 0 { return table.h0; }
    elif idx == 1 { return table.h1; }
    elif idx == 2 { return table.h2; }
    elif idx == 3 { return table.h3; }
    elif idx == 4 { return table.h4; }
    elif idx == 5 { return table.h5; }
    elif idx == 6 { return table.h6; }
    elif idx == 7 { return table.h7; }
    else { return table.h8; }
}

// install_handler: set BOTH halves at once -- a disposition of `+` and the
// address it refers to. Deliberately one function: a `+` with no address is
// the state that produced the original defect, and two setters make it
// reachable again.
fn install_handler(table: SignalTable, sig: int, addr: int) {
    if sig == -4 {
        io::println("  SIG_KILL: cannot install a handler — REJECTED");
        return;
    }
    if sig == -3 {
        io::println("  SIG_STOP: cannot install a handler — REJECTED");
        return;
    }
    let idx = sig + 4;
    if idx == 0 { table.d0 = +; table.h0 = addr; }
    elif idx == 1 { table.d1 = +; table.h1 = addr; }
    elif idx == 2 { table.d2 = +; table.h2 = addr; }
    elif idx == 3 { table.d3 = +; table.h3 = addr; }
    elif idx == 4 { table.d4 = +; table.h4 = addr; }
    elif idx == 5 { table.d5 = +; table.h5 = addr; }
    elif idx == 6 { table.d6 = +; table.h6 = addr; }
    elif idx == 7 { table.d7 = +; table.h7 = addr; }
    else { table.d8 = +; table.h8 = addr; }
    io::print("[SIGNAL] handler installed for ");
    io::print(signal_name(sig));
    io::print(" at 0x");
    io::println_int(addr);
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
        h0: 0, h1: 0, h2: 0, h3: 0, h4: 0, h5: 0, h6: 0, h7: 0, h8: 0,
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

fn sys_kill(sender_pid: int, target_pid: int, sig: int, sender_priv: trit,
            table: SignalTable, t: ProcTable, bank: ContextBank) -> trit {
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

    // AND IT NOW DELIVERS. §2.4.
    // `sys_kill` did the range checks and the privilege check, printed
    // "delivering", and returned. `deliver_signal` -- the function that
    // actually applies a signal -- was called from five sites, all five of
    // them in `src/demos/signal.mt`. The kill path and the delivery path were
    // two halves that never met, which is this phase's defect exactly.
    deliver_signal(target_pid, sig, table, t, bank);

    return +;
}

// ---------------------------------------------------------------------------
// deliver_signal: execute signal on target process
// ---------------------------------------------------------------------------

// deliver_signal: deliver `sig` to `target_pid`, and ACT on it.
//
// ENHANCEMENT_PLAN §2.4. This printed what it would do and returned `void`:
// "SIG_KILL: UNCONDITIONAL — process.state = KILLED(-4)" set nothing, and
// "save context, jump to handler address" did neither. It could not have done
// otherwise -- until §2.0 there was no process table in which a state could be
// set, which is why all five of its callers were in its own demo.
//
// It now takes the table and writes the state transitions it names. The
// handler jump is still narrated: a context switch needs kernel/context.mt's
// save/restore and an installed handler ADDRESS, and SignalTable stores a
// disposition trit rather than an address. That is the honest boundary of this
// step and is left visible rather than papered over.
fn deliver_signal(target_pid: int, sig: int, table: SignalTable, t: ProcTable, bank: ContextBank) {
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
        if !table_set_state(t, target_pid, -4) {
            io::println("  (no such pid in the process table)");
        }
        return;
    }

    tif disposition {
        + => {
            // User handler installed -- AND IT NOW ENTERS IT (§2.4).
            //
            // This arm used to print "save context, jump to handler address"
            // and do neither, because there was no process table to change a
            // PC in and no address to change it to. Both exist now: the
            // handler address lives beside the disposition in SignalTable, and
            // kernel/context.mt has had a nine-slot ContextBank with
            // `context_save` since it was written.
            io::print("  CATCH: invoking user signal handler for ");
            io::println(signal_name(sig));
            let idx = table_find(t, target_pid);
            let handler = get_handler(table, sig);
            if idx < 0 {
                io::println("    no such pid in the process table");
            } elif handler == 0 {
                // A `+` disposition with no address is exactly the state the
                // old code could not distinguish from a real handler.
                io::println("    disposition is CATCH but no handler address is installed");
            } else {
                let ctx = context_save(target_pid, slot_at(t, idx).pc,
                                       slot_at(t, idx).sp, slot_at(t, idx).pc,
                                       empty_regfile());
                let _ok = context_bank_put(bank, ctx);
                let _jm = table_set_pc(t, target_pid, handler);
                io::print("    context saved; process.pc = 0x");
                io::println_int(handler);
            }
            // NOT IMPLEMENTED and deliberately visible: there is no sigreturn.
            // The saved context is in the bank and nothing restores it when the
            // handler finishes, because a handler is an address this kernel
            // never executes -- it has no instruction stream of its own.
        }
        0 => {
            // Default action
            io::print("  DEFAULT: ");
            io::println(default_action(sig));
            // The default action for SIG_TERM(-2) and SIG_ABORT(-1) is to
            // terminate; SIG_STOP(-3) suspends. Both are state transitions the
            // table can now carry. Anything else defaults to ignore and leaves
            // the process alone.
            // The transitions are taken from `default_action` twenty lines
            // above -- it is this module's own statement of what each default
            // does, and writing a second mapping here would be a second source
            // of truth that could drift from the string the demo prints.
            //   -3 STOP      -> SLEEP(-2)
            //   -2, -1 TERM  -> EXITED(-3)
            //    1 CONTINUE  -> READY(+3)
            //    0, 2, 3, 4  -> nothing to do
            if sig == -2 || sig == -1 {
                if table_set_state(t, target_pid, -3) {
                    io::println("    process.state = EXITED(-3)");
                }
            } elif sig == -3 {
                if table_set_state(t, target_pid, -2) {
                    io::println("    process.state = SLEEP(-2) — suspended");
                }
            } elif sig == 1 {
                if table_set_state(t, target_pid, 3) {
                    io::println("    process.state = READY(+3) — resumed");
                }
            }
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

// MUTATES the table rather than rebuilding it, 30 August 2026.
//
// This was nine `return SignalTable { ..spelled out.. }` arms, and adding the
// handler addresses broke all nine at once -- the same failure `sys_exec` in
// kernel/process.mt already has a comment about ("an update expression cannot
// forget a field"). A struct parameter is a mutable reference in this
// language, so the copy was never needed: one assignment per arm, and a field
// added later cannot be forgotten by any of them.
//
// It still returns the table so existing call sites read unchanged; the return
// is the same object, not a copy.
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

    let idx = sig + 4;
    if idx == 0 { table.d0 = new_disp; }
    elif idx == 1 { table.d1 = new_disp; }
    elif idx == 2 { table.d2 = new_disp; }
    elif idx == 3 { table.d3 = new_disp; }
    elif idx == 4 { table.d4 = new_disp; }
    elif idx == 5 { table.d5 = new_disp; }
    elif idx == 6 { table.d6 = new_disp; }
    elif idx == 7 { table.d7 = new_disp; }
    else { table.d8 = new_disp; }
    return table;
}

// ---------------------------------------------------------------------------
// main: demonstrate signal handling
// ---------------------------------------------------------------------------
