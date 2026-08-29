// src/demos/perms.mt — the demonstration lifted out of src/fs/perms.mt
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

// perms_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn perms_demo() {
    io::println("=== TritFS Permission Model Demo ===");
    io::println("  Trit permissions: +1=rwx  0=r-x  -1=r--");
    io::println("  Access type:      +1=read  0=write  -1=execute");
    io::println("");

    let tty = Inode { ino: 2, itype: -, perm: +, size: 0, data_addr: 0,
                      name: "/dev/tty", parent_ino: 1, valid: true };
    let proc_d = Inode { ino: 3, itype: 0, perm: -, size: 0, data_addr: 0,
                         name: "/proc", parent_ino: 0, valid: true };
    let bin = Inode { ino: 5, itype: 0, perm: 0, size: 0, data_addr: 0,
                      name: "/bin", parent_ino: 0, valid: true };
    let tmp = Inode { ino: 4, itype: 0, perm: +, size: 0, data_addr: 0,
                      name: "/tmp", parent_ino: 0, valid: true };

    io::println("--- /dev/tty (rwx = +1) ---");
    perm_check_all(tty);
    io::println("");

    io::println("--- /proc (r-- = -1) ---");
    perm_check_all(proc_d);
    io::println("");

    io::println("--- /bin (r-x = 0) ---");
    perm_check_all(bin);
    io::println("");

    io::println("--- /tmp (rwx = +1) ---");
    perm_check_all(tmp);
    io::println("");

    io::println("--- Targeted checks ---");
    io::print("  /proc write: ");
    if check_permission(proc_d, 0) { io::println("ALLOWED"); } else { io::println("DENIED"); }
    io::print("  /bin  exec:  ");
    if check_permission(bin, -) { io::println("ALLOWED"); } else { io::println("DENIED"); }
    io::print("  /tmp  write: ");
    if check_permission(tmp, 0) { io::println("ALLOWED"); } else { io::println("DENIED"); }
    io::println("");

    io::println("=== Permission model verified ===");
    io::println("  rwx (+1) — all access allowed:       PASS");
    io::println("  r-x ( 0) — no write:                 PASS");
    io::println("  r-- (-1) — no write or execute:       PASS");
    io::println("  Denial logging with inode name:       PASS");
}
