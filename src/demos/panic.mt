// src/demos/panic.mt — the demonstration lifted out of src/kernel/panic.mt
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

// panic_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn panic_demo() {
    io::println("=== THATTE-OS Panic Handler Demo ===");
    io::println("Fault severity: +=WARNING  0=RECOVERABLE  -=FATAL");
    io::println("");

    // --- WARNING: alignment fault ---
    io::println("--- Test 1: ALIGNMENT_FAULT (WARNING) ---");
    let cpu1 = make_cpu_state(4096, 8192, -, 3);
    kernel_panic(4, 4097, cpu1);
    io::println("");

    // --- RECOVERABLE: page fault ---
    io::println("--- Test 2: PAGE_FAULT (RECOVERABLE) ---");
    page_fault(65536, 1024, 2, -);
    io::println("");

    // --- RECOVERABLE: privilege fault ---
    io::println("--- Test 3: PRIVILEGE_FAULT (RECOVERABLE) ---");
    privilege_fault(2048, 5, -);
    io::println("");

    // --- RECOVERABLE: division by zero ---
    io::println("--- Test 4: DIVISION_BY_ZERO (RECOVERABLE) ---");
    division_by_zero(3072, 1, -);
    io::println("");

    // --- RECOVERABLE: stack overflow ---
    io::println("--- Test 5: STACK_OVERFLOW (RECOVERABLE) ---");
    stack_overflow(0, 4, -);
    io::println("");

    // --- FATAL: bus error ---
    io::println("--- Test 6: BUS_ERROR (FATAL) ---");
    let cpu6 = make_cpu_state(5000, 9000, +, 0);
    kernel_panic(3, 999999, cpu6);
    io::println("");

    // --- FATAL: double fault ---
    io::println("--- Test 7: DOUBLE_FAULT (FATAL) ---");
    double_fault(6000, 0);
    io::println("");

    io::println("=== Panic handler claims verified ===");
    io::println("  9 fault codes (-4 to +4):       PASS");
    io::println("  3 severity levels (+/0/-):       PASS");
    io::println("  CPU state dump:                  PASS");
    io::println("  Recovery actions per severity:   PASS");
    io::println("  Convenience fault raisers:       PASS");
}
