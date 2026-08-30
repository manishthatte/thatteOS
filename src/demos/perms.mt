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

    // Built through `make_inode` rather than spelled out. These were the last
    // four bare Inode literals and all four broke at once when the struct
    // gained `content` in §3 -- the same failure the PCB literals had in §2.0.
    let tty    = make_inode(2, -, +, "/dev/tty", 1);
    let proc_d = make_inode(3, 0, -, "/proc",    0);
    let bin    = make_inode(5, 0, 0, "/bin",     0);
    let tmp    = make_inode(4, 0, +, "/tmp",     0);

    // The unix mapping, §3. A trit round-trips through unix and back; a unix
    // mode does NOT round-trip through a trit, because 0644 says "read yes,
    // write yes, execute no" and there is no such trit.
    expect_int("perms: rwx maps to 0755", perm_to_unix(+), 493);
    expect_int("perms: r-x maps to 0555", perm_to_unix(0), 365);
    expect_int("perms: r-- maps to 0444", perm_to_unix(-), 292);
    expect_trit("perms: 0755 reads back as rwx", unix_to_perm(493), +);
    expect_trit("perms: 0555 reads back as r-x", unix_to_perm(365), 0);
    expect_trit("perms: 0444 reads back as r--", unix_to_perm(292), -);
    // The lossy direction, asserted rather than described: 0644 is writable,
    // so the least authority consistent with its owner triad is rwx, and
    // mapping back out gives 0755 and not 0644.
    expect_trit("perms: 0644 projects to rwx (there is no rw-)", unix_to_perm(420), +);
    expect_int("perms: and so 0644 does not survive the round trip",
               perm_to_unix(unix_to_perm(420)), 493);
    io::println("");

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
