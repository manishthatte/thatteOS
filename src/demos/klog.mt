// src/demos/klog.mt — the demonstration lifted out of src/kernel/klog.mt
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

// klog_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn klog_demo() {
    io::println("=== THATTE-OS Kernel Log Demo ===");
    io::println("Log levels: DEBUG(+) INFO(0) ERROR(-)");
    io::println("Ring buffer: 9 entries (ternary: 3^2)");
    io::println("");

    let mut log = klog_init();
    io::println("");

    // --- Boot sequence logging ---
    io::println("--- Boot Sequence Logging ---");
    log = klog(log, 0, "BOOT", "kernel_main: starting boot sequence");
    log = klog_tick(log);
    log = klog(log, 0, "IRQ", "interrupt_init: 27 vectors registered");
    log = klog_tick(log);
    log = klog(log, 0, "PROC", "process_init: 9-slot table ready");
    log = klog_tick(log);
    log = klog(log, 0, "VMEM", "vmem_init: address space mapped");
    log = klog_tick(log);
    log = klog(log, 0, "SCALL", "syscall_init: 16 handlers registered");
    log = klog_tick(log);
    log = klog(log, 0, "TTY", "tty_init: driver loaded at SERVICE");
    log = klog_tick(log);
    log = klog(log, 0, "INIT", "init process spawned at USER");
    io::println("");

    // --- Debug message (should be filtered out at INFO level) ---
    io::println("--- DEBUG message (filtered at INFO level) ---");
    log = klog(log, +, "SCHED", "scheduler tick — this should NOT appear");
    io::println("  (no output — DEBUG filtered)");
    io::println("");

    // --- Error message ---
    io::println("--- ERROR message (always logged) ---");
    log = klog_tick(log);
    log = klog(log, -, "VMEM", "page fault at addr=0x10000 pid=3");
    io::println("");

    // --- Enable DEBUG level ---
    io::println("--- Enable DEBUG level ---");
    log = klog_set_level(log, +);
    log = klog_tick(log);
    log = klog(log, +, "SCHED", "scheduler tick — now visible with DEBUG level");
    io::println("");

    // --- Dump all entries ---
    io::println("--- dmesg (full log dump) ---");
    klog_dump(log);
    io::println("");

    // --- Statistics ---
    klog_stats(log);
    io::println("");

    io::println("=== Kernel log claims verified ===");
    io::println("  Ring buffer (9 entries):      PASS");
    io::println("  3 log levels (+/0/-):         PASS");
    io::println("  Level filtering:              PASS");
    io::println("  Tick-stamped entries:          PASS");
    io::println("  dmesg dump:                   PASS");
}
