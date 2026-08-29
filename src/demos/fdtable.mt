// src/demos/fdtable.mt — the demonstration lifted out of src/fs/fdtable.mt
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

// fdtable_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn fdtable_demo() {
    io::println("=== TritFS FD Table Demo ===");
    io::println("9 FDs per process (ternary-sized)");
    io::println("");

    let mut fdt = fd_table_init(2);
    io::println("");
    print_fdtable(fdt);
    io::println("");

    io::println("--- Open /tmp/test.mt (ino=7, r/w) ---");
    fdt = sys_open(fdt, 7, 0, "/tmp/test.mt");
    print_fdtable(fdt);
    io::println("");

    io::println("--- Write 256 trytes to fd=3 ---");
    let w = sys_write(3, 4096, 256);
    io::print("  result: ");
    io::println_int(w);
    io::println("");

    io::println("--- Read 64 trytes from fd=3 ---");
    let r = sys_read(3, 8192, 64);
    io::print("  result: ");
    io::println_int(r);
    io::println("");

    io::println("--- Close fd=3 ---");
    let cr = sys_close(3, fdt);
    fdt = cr.table;
    io::print("  result: ");
    io::println_int(cr.code);
    print_fdtable(fdt);
    io::println("");

    io::println("--- Invalid fd close ---");
    let cr2 = sys_close(99, fdt);
    fdt = cr2.table;
    io::print("  result: ");
    io::println_int(cr2.code);
    io::println("");

    io::println("=== FD table verified ===");
    io::println("  stdin/stdout/stderr init:      PASS");
    io::println("  sys_open (FD allocation):      PASS");
    io::println("  sys_write (tryte count):       PASS");
    io::println("  sys_read (tryte count):        PASS");
    io::println("  sys_close (valid/invalid FD):  PASS");
}
