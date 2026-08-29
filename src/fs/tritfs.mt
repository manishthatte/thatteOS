// fs/tritfs.mt — THATTE-OS TritFS integration
// GOD FILE SPLIT: this file is now the integration driver.
//   Sub-modules (standalone, compiled independently):
//     fs/inode.mt   — Inode, TritFS image, sys_mkdir, create_file, sys_stat
//     fs/fdtable.mt — FileDesc, FdTable, sys_open, sys_close, sys_read, sys_write
//     fs/perms.mt   — check_permission, perm_check_all
//
// TODO: when module imports are added, replace inline defs with:
//   use fs::inode;    use fs::fdtable;    use fs::perms;
//
// Demonstrates Thatte6 Claims:
//   Claim 4  — SYS_OPEN, SYS_CLOSE, SYS_READ, SYS_WRITE, SYS_STAT
//   Claim 7  — Full OS in ManiT

use std::io;

// MERGE NOTE, 30 August 2026 — twenty-seven declarations left this file, and
// what is left is the demonstration.
// 
// A census of the four fs modules found that tritfs.mt had ZERO unique
// declarations: all twenty-eight of its top-level names also existed in
// inode.mt, fdtable.mt or perms.mt. It was not a layer ABOVE those three,
// it was a COPY of all three, taken before they were split out and never
// reconciled afterwards.
// 
// The copies had drifted, and not harmlessly. This file's `create_file` and
// `sys_mkdir` wrote the new inode into slot 6, 7, or -- for EVERY OTHER
// VALUE OF next_ino, including 0 through 5 -- slot 8. inode.mt's delegate to
// `inode_set`, which handles all nine. Nothing caught it because nothing in
// this repository compiled src/ at all: not build.sh, not userspace/build.sh,
// not CI, not tests/test_all.sh.
// 
// So the three layer modules are canonical and this file keeps `tritfs_demo`,
// which is the thing it uniquely had.




























// ---------------------------------------------------------------------------
// main: demonstrate TritFS
// ---------------------------------------------------------------------------
