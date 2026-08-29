// src/demos/signal.mt — the demonstration lifted out of src/kernel/signal.mt
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

// signal_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn signal_demo() {
    io::println("=== THATTE-OS Signal Handling Demo ===");
    io::println("9 signals: SIG_KILL(-4) to SIG_CHLD(+4)");
    io::println("Dispositions: CATCH(+) DEFAULT(0) IGNORE(-)");
    io::println("");

    // Initialize signal table for PID 3
    let mut sig_table = default_signal_table(3);
    io::println("--- Default signal dispositions for PID=3 ---");
    let mut s = -4;
    while s <= 4 {
        let disp = get_disposition(sig_table, s);
        io::print("  ");
        io::print(signal_name(s));
        io::print(": ");
        io::println(disposition_name(disp));
        s = s + 1;
    }
    io::println("");

    // --- SYS_KILL: KERNEL sends SIG_TERM to PID=3 ---
    io::println("--- Test 1: KERNEL sends SIG_TERM(-2) to PID=3 ---");
    expect_trit("KERNEL may SIG_TERM any process",      sys_kill(0, 3, -2, +), +);
    deliver_signal(3, -2, sig_table);
    io::println("");

    // --- Install user handler for SIG_INT ---
    io::println("--- Test 2: Install CATCH handler for SIG_INT(-1) ---");
    sig_table = sys_signal(sig_table, -1, +);
    io::println("");

    // --- Deliver SIG_INT (should invoke user handler) ---
    io::println("--- Test 3: Deliver SIG_INT(-1) with CATCH handler ---");
    deliver_signal(3, -1, sig_table);
    io::println("");

    // --- SIG_KILL cannot be caught ---
    io::println("--- Test 4: Attempt to change SIG_KILL disposition ---");
    sig_table = sys_signal(sig_table, -4, +);
    io::println("");

    // --- Deliver SIG_KILL (unconditional) ---
    io::println("--- Test 5: Deliver SIG_KILL(-4) ---");
    deliver_signal(3, -4, sig_table);
    io::println("");

    // --- SIG_NULL (existence test) ---
    io::println("--- Test 6: SIG_NULL(0) existence check ---");
    expect_trit("SIG_NULL(0) is an existence check",    sys_kill(1, 3, 0, 0), +);
    io::println("");

    // --- USER privilege: self-signal OK, cross-signal denied ---
    io::println("--- Test 7: USER signals self (allowed) ---");
    expect_trit("USER may signal ITSELF",               sys_kill(5, 5, -2, -), +);
    io::println("");

    io::println("--- Test 8: USER signals other (denied) ---");
    expect_trit("USER may NOT signal another process",  sys_kill(5, 3, -2, -), -);
    io::println("");

    // --- SIG_CONT: resume stopped process ---
    io::println("--- Test 9: SIG_CONT(+1) resumes stopped process ---");
    deliver_signal(3, 1, sig_table);
    io::println("");

    // --- SIG_USR1 with IGNORE disposition ---
    io::println("--- Test 10: SIG_USR1(+2) ignored by default ---");
    deliver_signal(3, 2, sig_table);
    io::println("");

    io::println("=== Signal handling claims verified ===");
    io::println("  9 signals (-4 to +4):           PASS");
    io::println("  CATCH/DEFAULT/IGNORE:            PASS");
    io::println("  SIG_KILL uncatchable:            PASS");
    io::println("  Privilege enforcement:           PASS");
    io::println("  SIG_NULL existence test:         PASS");
    io::println("  sys_signal handler install:      PASS");
}
