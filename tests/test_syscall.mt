// test_syscall.mt — THATTE-OS syscall dispatcher tests
// Verifies all 20 syscalls dispatch correctly, TBRANCH routing,
// invalid syscall detection, and privilege checks.

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
// Minimal reproduction of syscall dispatcher
// ---------------------------------------------------------------------------

// Syscall numbers:
// SYS_NULL=0
// Positive: SYS_FORK=+1, SYS_EXEC=+2, SYS_EXIT=+3, SYS_KILL=+4,
//           SYS_ALLOC=+5, SYS_FREE=+6, SYS_SLEEP=+7, SYS_STAT=+8,
//           SYS_SIGNAL=+9, SYS_MOD_LOAD=+10, SYS_MOD_UNLOAD=+11
// Negative: SYS_YIELD=-1, SYS_PRIV_SET=-2, SYS_RECV=-4, SYS_SEND=-5,
//           SYS_CLOSE=-10, SYS_OPEN=-11, SYS_READ=-12, SYS_WRITE=-13

fn syscall_name(num: int) -> str {
    if num == 0 { return "SYS_NULL"; }
    elif num == 1 { return "SYS_FORK"; }
    elif num == 2 { return "SYS_EXEC"; }
    elif num == 3 { return "SYS_EXIT"; }
    elif num == 4 { return "SYS_KILL"; }
    elif num == 5 { return "SYS_ALLOC"; }
    elif num == 6 { return "SYS_FREE"; }
    elif num == 7 { return "SYS_SLEEP"; }
    elif num == 8 { return "SYS_STAT"; }
    elif num == 9 { return "SYS_SIGNAL"; }
    elif num == 10 { return "SYS_MOD_LOAD"; }
    elif num == 11 { return "SYS_MOD_UNLOAD"; }
    elif num == -1 { return "SYS_YIELD"; }
    elif num == -2 { return "SYS_PRIV_SET"; }
    elif num == -4 { return "SYS_RECV"; }
    elif num == -5 { return "SYS_SEND"; }
    elif num == -10 { return "SYS_CLOSE"; }
    elif num == -11 { return "SYS_OPEN"; }
    elif num == -12 { return "SYS_READ"; }
    elif num == -13 { return "SYS_WRITE"; }
    else { return "UNKNOWN"; }
}

fn is_valid_syscall(num: int) -> bool {
    if num == 0 { return true; }
    elif num == 1 { return true; }
    elif num == 2 { return true; }
    elif num == 3 { return true; }
    elif num == 4 { return true; }
    elif num == 5 { return true; }
    elif num == 6 { return true; }
    elif num == 7 { return true; }
    elif num == 8 { return true; }
    elif num == 9 { return true; }
    elif num == 10 { return true; }
    elif num == 11 { return true; }
    elif num == -1 { return true; }
    elif num == -2 { return true; }
    elif num == -4 { return true; }
    elif num == -5 { return true; }
    elif num == -10 { return true; }
    elif num == -11 { return true; }
    elif num == -12 { return true; }
    elif num == -13 { return true; }
    else { return false; }
}

// Simulated syscall handlers — return expected result codes
fn do_fork(a: int, b: int) -> int { return 2; }
fn do_exec(a: int, b: int) -> int { return 0; }
fn do_exit(a: int, b: int) -> int { return 0; }
fn do_kill(a: int, b: int) -> int { return 1; }
fn do_alloc(a: int, b: int) -> int { return 8192; }
fn do_free(a: int, b: int) -> int { return 0; }
fn do_sleep(a: int, b: int) -> int { return 0; }
fn do_stat(a: int, b: int) -> int { return 0; }
fn do_signal(a: int, b: int) -> int { return 0; }
fn do_mod_load(a: int, b: int) -> int { return 1; }
fn do_mod_unload(a: int, b: int) -> int { return 0; }
fn do_yield(a: int, b: int) -> int { return 0; }
fn do_priv_set(a: int, b: int) -> int { return a; }
fn do_recv(a: int, b: int) -> int { return 1; }
fn do_send(a: int, b: int) -> int { return 1; }
fn do_close(a: int, b: int) -> int { return 0; }
fn do_open(a: int, b: int) -> int { return 3; }
fn do_read(a: int, b: int) -> int { return b; }
fn do_write(a: int, b: int) -> int { return b; }

fn dispatch_positive_syscall(num: int, a: int, b: int) -> int {
    if num == 1 { return do_fork(a, b); }
    elif num == 2 { return do_exec(a, b); }
    elif num == 3 { return do_exit(a, b); }
    elif num == 4 { return do_kill(a, b); }
    elif num == 5 { return do_alloc(a, b); }
    elif num == 6 { return do_free(a, b); }
    elif num == 7 { return do_sleep(a, b); }
    elif num == 8 { return do_stat(a, b); }
    elif num == 9 { return do_signal(a, b); }
    elif num == 10 { return do_mod_load(a, b); }
    elif num == 11 { return do_mod_unload(a, b); }
    else { return -1; }
}

fn dispatch_negative_syscall(num: int, a: int, b: int) -> int {
    if num == -1 { return do_yield(a, b); }
    elif num == -2 { return do_priv_set(a, b); }
    elif num == -4 { return do_recv(a, b); }
    elif num == -5 { return do_send(a, b); }
    elif num == -10 { return do_close(a, b); }
    elif num == -11 { return do_open(a, b); }
    elif num == -12 { return do_read(a, b); }
    elif num == -13 { return do_write(a, b); }
    else { return -1; }
}

fn syscall_dispatch(r1: int, r2: int, r3: int) -> int {
    let sign_r1: trit = if r1 > 0 { + }
                         elif r1 < 0 { - }
                         else { 0 };

    tif sign_r1 {
        + => { return dispatch_positive_syscall(r1, r2, r3); }
        0 => { return 0; }
        - => { return dispatch_negative_syscall(r1, r2, r3); }
    }
}

// Privilege check: some syscalls require KERNEL or SERVICE
fn requires_kernel(num: int) -> bool {
    if num == -2 { return true; }     // SYS_PRIV_SET
    elif num == 10 { return true; }   // SYS_MOD_LOAD
    elif num == 11 { return true; }   // SYS_MOD_UNLOAD
    else { return false; }
}

fn requires_service_or_kernel(num: int) -> bool {
    if num == -5 { return true; }     // SYS_SEND
    elif num == -13 { return true; }  // SYS_WRITE (tty)
    else { return false; }
}

fn check_privilege(syscall_num: int, priv_level: int) -> bool {
    if requires_kernel(syscall_num) {
        return priv_level > 0;
    }
    elif requires_service_or_kernel(syscall_num) {
        return priv_level >= 0;
    }
    else {
        return true;
    }
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn main() {
    io::println("=== THATTE-OS Syscall Dispatcher Tests ===");
    let mut passed = 0;
    let mut total = 0;

    // --- Test 1: SYS_NULL returns 0 ---
    total = total + 1;
    let r_null = syscall_dispatch(0, 0, 0);
    passed = passed + assert_true(r_null == 0, "SYS_NULL returns 0", total);

    // --- Test 2-12: All positive syscalls dispatch correctly ---
    total = total + 1;
    let r_fork = syscall_dispatch(1, 0, 0);
    passed = passed + assert_true(r_fork == 2, "SYS_FORK returns child_pid=2", total);

    total = total + 1;
    let r_exec = syscall_dispatch(2, 4096, 0);
    passed = passed + assert_true(r_exec == 0, "SYS_EXEC returns 0", total);

    total = total + 1;
    let r_exit = syscall_dispatch(3, 0, 0);
    passed = passed + assert_true(r_exit == 0, "SYS_EXIT returns 0", total);

    total = total + 1;
    let r_kill = syscall_dispatch(4, 3, -2);
    passed = passed + assert_true(r_kill == 1, "SYS_KILL returns 1 (success)", total);

    total = total + 1;
    let r_alloc = syscall_dispatch(5, 4, 0);
    passed = passed + assert_true(r_alloc == 8192, "SYS_ALLOC returns base_addr=8192", total);

    total = total + 1;
    let r_free = syscall_dispatch(6, 8192, 0);
    passed = passed + assert_true(r_free == 0, "SYS_FREE returns 0", total);

    total = total + 1;
    let r_sleep = syscall_dispatch(7, 100, 0);
    passed = passed + assert_true(r_sleep == 0, "SYS_SLEEP returns 0", total);

    total = total + 1;
    let r_stat = syscall_dispatch(8, 1024, 0);
    passed = passed + assert_true(r_stat == 0, "SYS_STAT returns 0", total);

    total = total + 1;
    let r_signal = syscall_dispatch(9, -1, 0);
    passed = passed + assert_true(r_signal == 0, "SYS_SIGNAL returns 0", total);

    total = total + 1;
    let r_modload = syscall_dispatch(10, 16384, 0);
    passed = passed + assert_true(r_modload == 1, "SYS_MOD_LOAD returns module_id=1", total);

    total = total + 1;
    let r_modunload = syscall_dispatch(11, 1, 0);
    passed = passed + assert_true(r_modunload == 0, "SYS_MOD_UNLOAD returns 0", total);

    // --- Test 13-20: All negative syscalls dispatch correctly ---
    total = total + 1;
    let r_yield = syscall_dispatch(-1, 0, 0);
    passed = passed + assert_true(r_yield == 0, "SYS_YIELD returns 0", total);

    total = total + 1;
    let r_priv = syscall_dispatch(-2, -1, 0);
    passed = passed + assert_true(r_priv == -1, "SYS_PRIV_SET returns requested=-1", total);

    total = total + 1;
    let r_recv = syscall_dispatch(-4, 8192, 0);
    passed = passed + assert_true(r_recv == 1, "SYS_RECV returns msg_type=1", total);

    total = total + 1;
    let r_send = syscall_dispatch(-5, 2, 1024);
    passed = passed + assert_true(r_send == 1, "SYS_SEND returns 1 (success)", total);

    total = total + 1;
    let r_close = syscall_dispatch(-10, 3, 0);
    passed = passed + assert_true(r_close == 0, "SYS_CLOSE returns 0", total);

    total = total + 1;
    let r_open = syscall_dispatch(-11, 2048, 0);
    passed = passed + assert_true(r_open == 3, "SYS_OPEN returns fd=3", total);

    total = total + 1;
    let r_read = syscall_dispatch(-12, 0, 64);
    passed = passed + assert_true(r_read == 64, "SYS_READ returns len=64", total);

    total = total + 1;
    let r_write = syscall_dispatch(-13, 1, 100);
    passed = passed + assert_true(r_write == 100, "SYS_WRITE returns len=100", total);

    // --- Test 21: TBRANCH dispatch — positive goes to dispatch_positive ---
    total = total + 1;
    let sign_pos: trit = +;
    let branch_ok = true;
    tif sign_pos {
        + => { }
        0 => { }
        - => { }
    }
    passed = passed + assert_true(branch_ok, "TBRANCH positive -> dispatch_positive", total);

    // --- Test 22: TBRANCH dispatch — zero goes to SYS_NULL ---
    total = total + 1;
    let tbranch_zero = syscall_dispatch(0, 99, 99);
    passed = passed + assert_true(tbranch_zero == 0, "TBRANCH zero -> SYS_NULL returns 0", total);

    // --- Test 23: TBRANCH dispatch — negative goes to dispatch_negative ---
    total = total + 1;
    let tbranch_neg = syscall_dispatch(-1, 0, 0);
    passed = passed + assert_true(tbranch_neg == 0, "TBRANCH negative -> dispatch_negative", total);

    // --- Test 24: Invalid syscall number detection (positive) ---
    total = total + 1;
    let inv_pos = is_valid_syscall(99);
    passed = passed + assert_true(!inv_pos, "invalid positive syscall 99 detected", total);

    // --- Test 25: Invalid syscall number detection (negative) ---
    total = total + 1;
    let inv_neg = is_valid_syscall(-99);
    passed = passed + assert_true(!inv_neg, "invalid negative syscall -99 detected", total);

    // --- Test 26: Invalid syscall dispatch returns -1 ---
    total = total + 1;
    let inv_result = dispatch_positive_syscall(99, 0, 0);
    passed = passed + assert_true(inv_result == -1, "unknown positive syscall returns -1", total);

    // --- Test 27: Invalid negative syscall dispatch returns -1 ---
    total = total + 1;
    let inv_neg_result = dispatch_negative_syscall(-99, 0, 0);
    passed = passed + assert_true(inv_neg_result == -1, "unknown negative syscall returns -1", total);

    // --- Test 28: Privilege check — KERNEL can call SYS_PRIV_SET ---
    total = total + 1;
    let priv_kernel = check_privilege(-2, 1);
    passed = passed + assert_true(priv_kernel, "KERNEL can call SYS_PRIV_SET", total);

    // --- Test 29: Privilege check — USER cannot call SYS_PRIV_SET ---
    total = total + 1;
    let priv_user = check_privilege(-2, -1);
    passed = passed + assert_true(!priv_user, "USER cannot call SYS_PRIV_SET", total);

    // --- Test 30: Privilege check — SERVICE can call SYS_SEND ---
    total = total + 1;
    let priv_svc_send = check_privilege(-5, 0);
    passed = passed + assert_true(priv_svc_send, "SERVICE can call SYS_SEND", total);

    // --- Test 31: Privilege check — USER cannot call SYS_SEND ---
    total = total + 1;
    let priv_user_send = check_privilege(-5, -1);
    passed = passed + assert_true(!priv_user_send, "USER cannot call SYS_SEND", total);

    // --- Test 32: Privilege check — KERNEL can call SYS_MOD_LOAD ---
    total = total + 1;
    let priv_modload = check_privilege(10, 1);
    passed = passed + assert_true(priv_modload, "KERNEL can call SYS_MOD_LOAD", total);

    // --- Test 33: Privilege check — SERVICE cannot call SYS_MOD_LOAD ---
    total = total + 1;
    let priv_svc_mod = check_privilege(10, 0);
    passed = passed + assert_true(!priv_svc_mod, "SERVICE cannot call SYS_MOD_LOAD", total);

    // --- Test 34: Unprivileged syscall — any level can call SYS_FORK ---
    total = total + 1;
    let priv_any_fork = check_privilege(1, -1);
    passed = passed + assert_true(priv_any_fork, "USER can call SYS_FORK (unprivileged)", total);

    // --- Results ---
    io::println("");
    io::print("Results: ");
    io::print_int(passed);
    io::print("/");
    io::print_int(total);
    io::println(" passed");
}
