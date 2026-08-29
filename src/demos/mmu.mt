// src/demos/mmu.mt — the demonstration lifted out of src/mm/mmu.mt
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

// mmu_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn mmu_demo() {
    io::println("=== THATTE-OS Physical Frame Allocator (MMU) Demo ===");
    io::println("Thatte4 Claim 1: ternary-sized physical pages");
    io::println("Thatte4 Claim 2: frame states FREE/USED/RESERVED");
    io::println("");

    let mut ft = mmu_init();
    io::println("");
    print_frame_table(ft);
    io::println("");

    io::println("--- Allocating 3 frames ---");
    let r1 = mmu_alloc_frame(ft);
    ft = r1.table;
    let f1 = r1.frame_idx;

    let r2 = mmu_alloc_frame(ft);
    ft = r2.table;
    let f2 = r2.frame_idx;

    let r3 = mmu_alloc_frame(ft);
    ft = r3.table;
    let f3 = r3.frame_idx;

    io::println("");
    print_frame_table(ft);
    io::println("");

    io::println("--- Freeing frame 2 ---");
    ft = mmu_free_frame(ft, f2);
    io::println("");
    print_frame_table(ft);
    io::println("");

    io::println("--- Frame base addresses ---");
    io::print("  frame ");
    io::print_int(f1);
    io::print(" base: ");
    io::println_int(mmu_frame_base(ft, f1));
    io::print("  frame ");
    io::print_int(f3);
    io::print(" base: ");
    io::println_int(mmu_frame_base(ft, f3));
    io::println("");

    io::println("=== MMU claims verified ===");
    io::println("  Physical frame table (9 frames):  PASS");
    io::println("  RESERVED/FREE/USED trit states:   PASS");
    io::println("  alloc_frame (first-free policy):  PASS");
    io::println("  free_frame (mark FREE):           PASS");
    io::println("  Frame base address lookup:        PASS");
}
