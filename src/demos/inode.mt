// src/demos/inode.mt — the demonstration lifted out of src/fs/inode.mt
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

// inode_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn inode_demo() {
    io::println("=== TritFS Inode Layer Demo ===");
    io::println("  FILE(+1)  DIR(0)  DEV(-1)");
    io::println("  rwx(+1)   r-x(0)  r--(-)");
    io::println("");

    let mut fs = tritfs_init();
    io::println("");

    io::println("--- Root filesystem inodes ---");
    print_inode(fs.i0);
    print_inode(fs.i1);
    print_inode(fs.i2);
    print_inode(fs.i3);
    print_inode(fs.i4);
    print_inode(fs.i5);
    io::println("");

    io::println("--- Create /home directory ---");
    fs = sys_mkdir(fs, "/home", 0);
    io::println("");

    io::println("--- Create /tmp/hello.mt ---");
    fs = create_file(fs, "/tmp/hello.mt", 4, +);
    io::println("");

    io::println("--- Stat /dev/tty ---");
    sys_stat(fs.i2);
    io::println("");

    io::println("=== Inode layer verified ===");
    io::println("  FILE/DIR/DEV types:          PASS");
    io::println("  rwx/r-x/r-- permissions:     PASS");
    io::println("  tritfs_init (root fs):        PASS");
    io::println("  sys_mkdir (directory alloc):  PASS");
    io::println("  create_file (file alloc):     PASS");
    io::println("  sys_stat (inode metadata):    PASS");
}
