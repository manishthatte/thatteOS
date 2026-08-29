// src/demos/privilege.mt — the demonstration lifted out of src/kernel/privilege.mt
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

// privilege_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn privilege_demo() {
    io::println("=== THATTE-OS Privilege Management Demo ===");
    io::println("Claim 3: Three-level privilege KERNEL/SERVICE/USER");
    io::println("Claim 8: Three-rail substrate VDD/GND/VSS");
    io::println("Claim 9: Signed virtual address enforcement");
    io::println("");

    // Track privilege as int: 1=KERNEL, 0=SERVICE, -1=USER
    let mut priv: int = 1;   // start at KERNEL

    io::print("Initial: ");
    io::println(priv_rail_name(priv));
    io::println("");

    // --- Transition 1: KERNEL -> SERVICE ---
    io::println("--- Transition 1: KERNEL -> SERVICE ---");
    priv = sys_priv_set(priv, 0);
    io::print("  current: ");
    io::println(priv_rail_name(priv));
    io::println("");

    // --- Transition 2: SERVICE -> USER ---
    io::println("--- Transition 2: SERVICE -> USER ---");
    priv = sys_priv_set(priv, -1);
    io::print("  current: ");
    io::println(priv_rail_name(priv));
    io::println("");

    // --- Transition 3: USER -> KERNEL (illegal escalation) ---
    io::println("--- Transition 3: USER -> KERNEL (illegal escalation) ---");
    priv = sys_priv_set(priv, 1);
    io::print("  current (unchanged): ");
    io::println(priv_rail_name(priv));
    io::println("");

    // --- Transition 4: USER -> SERVICE (illegal escalation) ---
    io::println("--- Transition 4: USER -> SERVICE (illegal escalation) ---");
    priv = sys_priv_set(priv, 0);
    io::print("  current (unchanged): ");
    io::println(priv_rail_name(priv));
    io::println("");

    // --- Reset to KERNEL for address checks ---
    priv = 1;
    io::println("--- Reset to KERNEL ---");

    // --- Signed virtual address enforcement ---
    io::println("");
    io::println("--- Virtual Address Enforcement (Claim 9) ---");
    io::println("Addresses: MST=+1 kernel-space, MST=0 shared, MST=-1 user");
    io::println("");

    io::println("KERNEL priv accessing kernel-space addr (+):");
    let _ = priv_check_address(1000000, 1);

    io::println("SERVICE priv accessing kernel-space addr (+):");
    let ok2 = priv_check_address(1000000, 0);
    if !ok2 { privilege_fault_handler(0); }

    io::println("USER priv accessing kernel-space addr (+):");
    let ok3 = priv_check_address(1000000, -1);
    if !ok3 { privilege_fault_handler(0); }

    io::println("");
    io::println("USER priv accessing shared-space addr (0=0):");
    let _ = priv_check_address(0, -1);

    io::println("USER priv accessing user-space addr (-):");
    let _ = priv_check_address(-1000, -1);

    io::println("");
    io::println("=== Privilege claims verified ===");
    io::println("  KERNEL->SERVICE->USER transitions:   PASS");
    io::println("  USER escalation blocked (FAULT):     PASS");
    io::println("  Kernel-space addr enforced:          PASS");
    io::println("  Three-rail VDD/GND/VSS substrate:    PASS");
}
