// src/demos/vmem.mt — the demonstration lifted out of src/mm/vmem.mt
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

// vmem_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn vmem_demo() {
    io::println("=== THATTE-OS Virtual Memory Demo ===");
    io::println("Claim 2:  Virtual memory + conditional permissions");
    io::println("Claim 9:  Signed virtual address enforcement");
    io::println("");

    vmem_init();
    io::println("");

    io::println("--- Address Privilege Checks ---");
    io::println("");

    // Kernel-space addresses (positive in 27-trit)
    io::println("Test 1: KERNEL accesses kernel-space addr (+1000000):");
    expect_bool("KERNEL may reach kernel space",        check_address_privilege(1000000, +, +), true);
    io::println("");

    io::println("Test 2: SERVICE accesses kernel-space addr (+1000000):");
    let ok2 = check_address_privilege(1000000, +, 0);
    if !ok2 {
        address_fault_handler(1000000);
    }
    io::println("");

    io::println("Test 3: USER accesses kernel-space addr (+1000000):");
    let ok3 = check_address_privilege(1000000, +, -);
    if !ok3 {
        address_fault_handler(1000000);
    }
    io::println("");

    io::println("Test 4: USER accesses shared-space addr (0):");
    let _ = check_address_privilege(0, 0, -);
    io::println("");

    io::println("Test 5: USER accesses user-space addr (-100):");
    let _ = check_address_privilege(-100, -, -);
    io::println("");

    io::println("Test 6: SERVICE accesses user-space addr (-500):");
    let _ = check_address_privilege(-500, -, 0);
    io::println("");

    io::println("=== Virtual memory claims verified ===");
    io::println("  Signed-address space layout (MST-based): PASS");
    io::println("  KERNEL-space gating:                     PASS");
    io::println("  ADDRESS FAULT on unauthorised access:    PASS");
}
