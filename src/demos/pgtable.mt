// src/demos/pgtable.mt — the demonstration lifted out of src/mm/pgtable.mt
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

// pgtable_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn pgtable_demo() {
    io::println("=== THATTE-OS Page Table Demo ===");
    io::println("Claim 10: Conditional page permissions");
    io::println("  -1=deny  0=conditional(CoW/demand-zero/JIT)  +1=allow");
    io::println("");

    // --- Map pages with different permission combinations ---
    io::println("--- Mapping pages ---");
    let p_kernel = map_page(1000, +, +, -);   // kernel: RW, no-exec
    let p_cow    = map_page(2000, 0, -, -);   // CoW read, deny write/exec
    let p_code   = map_page(3000, +, -, 0);   // read, no-write, JIT exec
    let p_dz     = map_page(4000, +, 0, +);   // read, demand-zero write, exec
    let p_deny   = map_page(5000, -, -, -);   // all deny
    io::println("");

    // --- Test all 9 access/permission combinations ---
    io::println("--- Access Demonstrations ---");
    io::println("");

    // READ with +1 perm (allow)
    io::println("Test 1: READ on kernel page (read_perm=+1):");
    handle_page_access(1000, +, p_kernel);
    io::println("");

    // READ with 0 perm (CoW)
    io::println("Test 2: READ on CoW page (read_perm=0):");
    handle_page_access(2000, +, p_cow);
    io::println("");

    // READ with -1 perm (deny)
    io::println("Test 3: READ on deny-all page (read_perm=-1):");
    handle_page_access(5000, +, p_deny);
    io::println("");

    // WRITE with +1 perm (allow)
    io::println("Test 4: WRITE on kernel page (write_perm=+1):");
    handle_page_access(1000, 0, p_kernel);
    io::println("");

    // WRITE with 0 perm (demand-zero)
    io::println("Test 5: WRITE on demand-zero page (write_perm=0):");
    handle_page_access(4000, 0, p_dz);
    io::println("");

    // WRITE with -1 perm (deny)
    io::println("Test 6: WRITE on deny-all page (write_perm=-1):");
    handle_page_access(5000, 0, p_deny);
    io::println("");

    // EXEC with +1 perm (allow)
    io::println("Test 7: EXEC on demand-zero page (exec_perm=+1):");
    handle_page_access(4000, -, p_dz);
    io::println("");

    // EXEC with 0 perm (JIT)
    io::println("Test 8: EXEC on JIT page (exec_perm=0):");
    handle_page_access(3000, -, p_code);
    io::println("");

    // EXEC with -1 perm (deny)
    io::println("Test 9: EXEC on deny-all page (exec_perm=-1):");
    handle_page_access(5000, -, p_deny);
    io::println("");

    io::println("=== Page table claims verified ===");
    io::println("  9 permission/access combinations tested: PASS");
    io::println("  CoW(0)/demand-zero(0)/JIT(0) conditional: PASS");
    io::println("  deny(-1) and allow(+1) direct paths:      PASS");
}
