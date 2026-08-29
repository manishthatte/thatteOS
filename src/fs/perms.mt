// fs/perms.mt — THATTE-OS filesystem permission enforcement
// Extracted from tritfs.mt (GOD file split).
//
// Responsibilities:
//   - Trit-encoded permission model: rwx(+1), r-x(0), r--(-)
//   - check_permission: verify access trit against inode perm
//   - perm_check_all: batch audit of an inode against all access types
//
// Access trit: +1=read, 0=write, -1=execute
//
// TODO: when module imports are added, `use fs::perms;`.

use std::io;

// MERGE NOTE, 30 August 2026: `Inode` and `perm_name` were byte-identical to
// inode.mt's and are now taken from there. This module keeps the permission
// LAYER -- `check_permission`, `access_name`, `perm_check_all` -- which is
// what it is for. Its `check_permission` is also the canonical one over
// tritfs.mt's: it names the inode in the denial, where the other says only
// "permission denied".



fn access_name(a: trit) -> str {
    tif a {
        + => return "read",
        0 => return "write",
        - => return "execute",
    }
}

// ---------------------------------------------------------------------------
// check_permission: can 'access' be performed on 'inode'?
//   Returns true if allowed, false if denied (also logs denial reason).
// ---------------------------------------------------------------------------

fn check_permission(inode: Inode, access: trit) -> bool {
    tif inode.perm {
        + => {
            // rwx — all access granted
            return true;
        }
        0 => {
            // r-x — read and execute only; write denied
            tif access {
                + => return true,
                0 => {
                    io::print("  DENIED: ");
                    io::print(inode.name);
                    io::println(" (r-x) does not allow write");
                    return false;
                }
                - => return true,
            }
        }
        - => {
            // r-- — read only; write and execute denied
            tif access {
                + => return true,
                0 => {
                    io::print("  DENIED: ");
                    io::print(inode.name);
                    io::println(" (r--) does not allow write");
                    return false;
                }
                - => {
                    io::print("  DENIED: ");
                    io::print(inode.name);
                    io::println(" (r--) does not allow execute");
                    return false;
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// perm_check_all: audit all three access types for an inode
// ---------------------------------------------------------------------------

fn perm_check_all(inode: Inode) {
    io::print("  Inode ");
    io::print(inode.name);
    io::print(" perm=");
    io::println(perm_name(inode.perm));

    let can_read  = check_permission(inode, +);
    let can_write = check_permission(inode, 0);
    let can_exec  = check_permission(inode, -);

    io::print("    read:    "); if can_read  { io::println("ALLOWED"); } else { io::println("DENIED"); }
    io::print("    write:   "); if can_write { io::println("ALLOWED"); } else { io::println("DENIED"); }
    io::print("    execute: "); if can_exec  { io::println("ALLOWED"); } else { io::println("DENIED"); }
}

// ---------------------------------------------------------------------------
// main: permission model standalone demo
// ---------------------------------------------------------------------------
