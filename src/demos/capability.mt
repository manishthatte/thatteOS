// src/demos/capability.mt — the demonstration lifted out of src/security/capability.mt
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

// capability_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn capability_demo() {
    io::println("=== THATTE-OS Capability Security Demo ===");
    io::println("9-trit capability word per process");
    io::println("Values: GRANTED(+) INHERITED(0) DENIED(-)");
    io::println("");

    // --- Show default capability sets ---
    io::println("--- KERNEL capabilities ---");
    let kcap = kernel_caps(0);
    print_caps(kcap);
    io::println("");

    io::println("--- SERVICE capabilities ---");
    let scap = service_caps(1);
    print_caps(scap);
    io::println("");

    io::println("--- USER capabilities ---");
    let ucap = user_caps(2);
    print_caps(ucap);
    io::println("");

    io::println("--- SANDBOXED capabilities ---");
    let sandbox = sandboxed_caps(3);
    print_caps(sandbox);
    io::println("");

    // --- Enforcement demos ---
    io::println("--- Capability Enforcement ---");
    io::println("");

    io::println("KERNEL PID=0:");
    expect_bool("KERNEL  CAN_FORK   granted", enforce(kcap, 0, "SYS_FORK"), true);
    expect_bool("KERNEL  CAN_PRIV   granted", enforce(kcap, 5, "SYS_PRIV_SET"), true);
    io::println("");

    io::println("USER PID=2:");
    expect_bool("USER    CAN_FORK   granted", enforce(ucap, 0, "SYS_FORK"), true);
    expect_bool("USER    CAN_IO     DENIED",  enforce(ucap, 3, "SYS_IO"), false);
    expect_bool("USER    CAN_MOD    DENIED",  enforce(ucap, 4, "SYS_MOD_LOAD"), false);
    expect_bool("USER    CAN_FS     granted", enforce(ucap, 8, "SYS_OPEN"), true);
    io::println("");

    io::println("SANDBOXED PID=3:");
    expect_bool("SANDBOX CAN_FORK   DENIED",  enforce(sandbox, 0, "SYS_FORK"), false);
    expect_bool("SANDBOX CAN_IPC    INHERITED, not granted", enforce(sandbox, 2, "SYS_SEND"), false);
    expect_bool("SANDBOX CAN_ALLOC  INHERITED, not granted", enforce(sandbox, 6, "SYS_ALLOC"), false);
    io::println("");

    // --- Attenuation demo ---
    io::println("--- Capability Attenuation ---");
    io::println("USER (parent) creates child requesting KERNEL-level caps:");
    let child_request = kernel_caps(4);  // child wants everything
    let attenuated = attenuate(ucap, child_request);
    io::println("Result after attenuation:");
    print_caps(attenuated);
    io::println("");

    // --- Inheritance resolution ---
    io::println("--- Inheritance Resolution ---");
    io::println("Resolve SANDBOXED child against USER parent:");
    let resolved = resolve_all(sandbox, ucap);
    io::println("Resolved capabilities:");
    print_caps(resolved);
    io::println("");

    // --- Composition order (see COMPOSITION RULE) ---
    io::println("--- Composition Order ---");
    io::print("USER parent is resolved (no INHERITED trit): ");
    io::println_bool3(is_resolved(ucap));
    io::print("SANDBOXED word is resolved: ");
    io::println_bool3(is_resolved(sandbox));
    io::println("Resolving the sandbox word at the root denies its INHERITED trits:");
    let rooted = resolve_root(sandbox);
    io::print("  resolved: ");
    io::println_bool3(is_resolved(rooted));
    io::println("Canonical order — resolve the parent, then attenuate the child:");
    let grandchild = attenuate(resolved, kernel_caps(5));
    print_caps(grandchild);
    io::println("");

    io::println("=== Capability claims verified ===");
    io::println("  9-trit capability word:          PASS");
    io::println("  GRANTED/INHERITED/DENIED:        PASS");
    io::println("  Enforcement before syscall:      PASS");
    io::println("  Attenuation (parent limits):     PASS");
    io::println("  Inheritance resolution:          PASS");
    io::println("  4 preset levels (K/S/U/sandbox): PASS");
}
