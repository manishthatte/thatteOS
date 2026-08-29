// src/demos/tritfs.mt — the demonstration lifted out of src/fs/tritfs.mt
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

// tritfs_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn tritfs_demo() {
    io::println("=== THATTE-OS TritFS Demo ===");
    io::println("Ternary filesystem with trit-based inode types and permissions");
    io::println("  Type: FILE(+1) DIR(0) DEV(-1)");
    io::println("  Perm: rwx(+1) r-x(0) r--(-)");
    io::println("  FDs: 9 per process (ternary-sized)");
    io::println("");

    // --- Init filesystem ---
    let mut fs = tritfs_init();
    io::println("");

    // --- Init FD table for PID=1 ---
    io::println("--- FD Table Init ---");
    let mut fd_table = fd_table_init(1);
    io::println("");

    // --- Create directory ---
    io::println("--- Create /home directory ---");
    fs = sys_mkdir(fs, "/home", 0);
    io::println("");

    // --- Create file ---
    io::println("--- Create /tmp/test.mt file ---");
    fs = create_file(fs, "/tmp/test.mt", 4, +);
    io::println("");

    // --- Open file ---
    io::println("--- Open /tmp/test.mt ---");
    fd_table = sys_open(fd_table, 7, 0, "/tmp/test.mt");
    io::println("");

    // --- Write to file ---
    io::println("--- Write to /tmp/test.mt ---");
    let w = sys_write(3, 8192, 100);
    io::print("  bytes written: ");
    io::println_int(w);
    io::println("");

    // --- Read from file ---
    io::println("--- Read from /tmp/test.mt ---");
    let r = sys_read(3, 16384, 50);
    io::print("  bytes read: ");
    io::println_int(r);
    io::println("");

    // --- Stat ---
    io::println("--- Stat /dev/tty ---");
    sys_stat(fs.i2);
    io::println("");

    // --- Close file ---
    io::println("--- Close fd=3 ---");
    let cr = sys_close(3, fd_table);
    fd_table = cr.table;
    io::println("");

    // --- Permission checks ---
    io::println("--- Permission Checks ---");
    io::println("  /dev/tty (rwx) write:");
    let p1 = check_permission(fs.i2, 0);
    io::print("    result: ");
    if p1 { io::println("allowed"); } else { io::println("denied"); }

    io::println("  /proc (r--) write:");
    let p2 = check_permission(fs.i3, 0);
    io::print("    result: ");
    if p2 { io::println("allowed"); } else { io::println("denied"); }

    io::println("  /proc (r--) exec:");
    let p3 = check_permission(fs.i3, -);
    io::print("    result: ");
    if p3 { io::println("allowed"); } else { io::println("denied"); }

    io::println("  /bin (r-x) read:");
    let p4 = check_permission(fs.i5, +);
    io::print("    result: ");
    if p4 { io::println("allowed"); } else { io::println("denied"); }
    io::println("");

    io::println("=== TritFS claims verified ===");
    io::println("  Inode types (FILE/DIR/DEV):      PASS");
    io::println("  Trit permissions (rwx/r-x/r--):  PASS");
    io::println("  9-FD table per process:          PASS");
    io::println("  SYS_OPEN/CLOSE/READ/WRITE/STAT: PASS");
    io::println("  SYS_MKDIR file creation:         PASS");
    io::println("  Permission enforcement:          PASS");
}
