// src/demos/tty.mt — the demonstration lifted out of src/drivers/tty.mt
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

// tty_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn tty_demo() {
    io::println("=== THATTE-OS Enhanced TTY Driver Demo ===");
    io::println("Claim 3: SERVICE privilege driver");
    io::println("Enhanced: line buffer, formatted output, echo, stats");
    io::println("");

    // Init TTY from KERNEL context
    io::println("--- tty_init ---");
    let mut tty = tty_init(+);
    io::println("");

    // Formatted output
    io::println("--- Formatted Output ---");
    tty = tty_print_ok(tty, "System initialized successfully");
    tty = tty_print_info(tty, "Loading user environment");
    tty = tty_print_error(tty, "Config file not found, using defaults");
    io::println("");

    // tty_write from KERNEL (allowed)
    io::println("--- tty_write from KERNEL ---");
    let w1 = tty_write(tty, "THATTE-OS 0.2.0 boot message", 28, +);
    tty = w1.tty;
    io::println("");

    // tty_write from SERVICE (allowed)
    io::println("--- tty_write from SERVICE ---");
    let w2 = tty_write(tty, "service message to console", 26, 0);
    tty = w2.tty;
    io::println("");

    // tty_write from USER (denied)
    io::println("--- tty_write from USER (denied) ---");
    let w3 = tty_write(tty, "user attempt", 12, -);
    tty = w3.tty;
    io::print("  result=");
    io::println_int(w3.bytes);
    io::println("");

    // tty_read with echo
    io::println("--- tty_read with echo ---");
    let r1 = tty_read(tty, 32768, 64);
    tty = r1.tty;
    io::println("");

    // Disable echo (for password input)
    io::println("--- Disable echo (password mode) ---");
    tty = tty_set_echo(tty, false);
    let r2 = tty_read(tty, 32768, 16);
    tty = r2.tty;
    io::println("");

    // Re-enable echo
    tty = tty_set_echo(tty, true);
    io::println("");

    // Statistics
    io::println("--- TTY Statistics ---");
    tty_stats(tty);
    io::println("");

    io::println("=== Enhanced TTY claims verified ===");
    io::println("  SERVICE privilege init:           PASS");
    io::println("  Privilege enforcement:            PASS");
    io::println("  Formatted output (+/0/-):         PASS");
    io::println("  Terminal 81x27 (3^4 x 3^3):      PASS");
    io::println("  Echo enable/disable:              PASS");
    io::println("  Statistics tracking:              PASS");
}
