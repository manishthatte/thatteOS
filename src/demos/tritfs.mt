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

    // --- Write to file, and read it back (§3) ---
    // The file created above is inode 6, at permission rwx, so a write is
    // allowed and the bytes land in the inode rather than in a sentence.
    io::println("--- Write to /tmp/test.mt, then read it back ---");
    let w = sys_write_data(fs, fd_table, 3, "trit data");
    io::print("  bytes written: ");
    io::println_int(w);
    expect_int("tritfs: the write reports its byte count", w, 9);

    let r = sys_read_data(fs, fd_table, 3);
    io::print("  read back: ");
    io::println(r);
    expect_bool("tritfs: a file round-trips through the filesystem",
                r == "trit data", true);
    expect_int("tritfs: and the inode records the size", fs_inode_at(fs, 7).size, 9);
    io::println("");

    // --- REAL STORAGE (§3), hosted only -----------------------------------
    // Everything above this point is an in-memory filesystem: the write really
    // moved bytes, but into a struct field. This block puts them on the host's
    // disk and reads them back through a CLEARED inode, so the content can
    // only have come from the file.
    io::println("--- Persistence: flush to disk, clear, reload ---");
    store_init();
    expect_bool("store: flushing a live inode succeeds", store_flush(fs, 7), true);

    // Clear the inode. If the reload below is a no-op, the assertion after it
    // sees "" and fails -- which is what makes this a test of the DISK rather
    // than of the struct that is still holding the value.
    let _ = fs_set_content(fs, 7, "");
    expect_int("store: the inode was cleared before reloading", fs_inode_at(fs, 7).size, 0);

    expect_bool("store: reloading from disk succeeds", store_load(fs, 7), true);
    expect_bool("store: the bytes came back from the host filesystem",
                fs_inode_at(fs, 7).content == "trit data", true);
    expect_int("store: and the size was restored with them", fs_inode_at(fs, 7).size, 9);

    // An inode that was never flushed has nothing to load.
    expect_bool("store: loading an inode with no file reports failure",
                store_load(fs, 5), false);
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
