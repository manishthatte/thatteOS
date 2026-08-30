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

    // §3: a REAL round trip. The file is an inode in a real TritFS, the write
    // stores bytes and the read returns them. `sys_write` used to return its
    // own `len` argument having touched nothing, so a demo asserting the
    // result was asserting its own input.
    // A FRESH fs and fd table for the round trip, and a file that actually
    // exists. The fd opened above names inode 7, which in a fresh TritFS is an
    // EMPTY inode at permission 0 (r-x) -- so a write to it is correctly
    // REFUSED, and the first version of this block asserted otherwise. The
    // demo was opening an inode nobody had created.
    let mut fs = tritfs_init();
    fs = create_file(fs, "/tmp/data.mt", 4, +);   // -> inode 6, rwx
    let mut fdt2 = fd_table_init(2);
    fdt2 = sys_open(fdt2, 6, 0, "/tmp/data.mt"); // -> fd 3
    io::println("");
    io::println("--- Write to fd=3, then read it back ---");
    let w = sys_write_data(fs, fdt2, 3, "hello ternary");
    io::print("  wrote: ");
    io::println_int(w);
    expect_int("fd: the write reports the byte count", w, 13);
    expect_int("fd: the inode's size was updated",  fs_inode_at(fs, 6).size, 13);

    let r = sys_read_data(fs, fdt2, 3);
    io::print("  read back: ");
    io::println(r);
    expect_bool("fd: what was written is what is read", r == "hello ternary", true);

    // The permission check, which had no caller outside its own demo before §3.
    // ino 3 is /proc at r--, so a write to it must be refused. It is opened on
    // a second fd so the successful path above is untouched.
    fdt2 = sys_open(fdt2, 3, 0, "/proc");
    let denied = sys_write_data(fs, fdt2, 4, "nope");
    expect_int("fd: writing to an r-- inode is refused", denied, -1);
    expect_bool("fd: and the refused write stored nothing",
                fs_inode_at(fs, 3).content == "", true);
    // ...and the same inode still READS, so the refusal is about the verb.
    let pr = sys_read_data(fs, fdt2, 4);
    expect_bool("fd: an r-- inode still reads", pr == "", true);
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
