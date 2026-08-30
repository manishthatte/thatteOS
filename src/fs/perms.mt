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



// ---------------------------------------------------------------------------
// THE THREE-VALUED PERMISSION MODEL, AND ITS MAPPING TO UNIX BITS
// ENHANCEMENT_PLAN §3 — written down before it is coded, as that section asks
// ---------------------------------------------------------------------------
//
// A TritFS inode carries ONE trit of permission, not nine bits:
//
//     +1  rwx   read, write, execute
//      0  r-x   read and execute; write denied
//     -1  r--   read only
//
// THE CLAIM THIS MAKES. Unix spends nine bits on three subjects (owner, group,
// other) x three verbs. TritFS spends one trit on one subject, and the ORDER is
// the point: the three values are a TOTAL ORDER of authority, so "may I?" is a
// COMPARISON rather than a mask test. `check_permission` below is a `tif` on
// the permission and then a `tif` on the access -- nine cases, no bitwise
// arithmetic anywhere in the filesystem.
//
// THE MAPPING, and it is deliberately LOSSY IN ONE DIRECTION ONLY.
//
//     trit -> unix    +1 -> 0755    0 -> 0555    -1 -> 0444
//
// Those three are chosen because they are the Unix modes whose owner triads
// are exactly rwx, r-x and r-- and whose other triads agree with them; a trit
// says nothing about a group, so a mapping that gave group and other different
// bits would be inventing information the inode does not carry.
//
// Going back is a PROJECTION and cannot be exact: 0644, 0600 and 0664 all
// answer "read yes, write yes, execute no", which is a combination the trit
// cannot express -- there is no "rw-". `unix_to_perm` therefore reads the
// OWNER triad and answers the least authority consistent with it, so a round
// trip trit -> unix -> trit is the identity while unix -> trit -> unix is not.
// That asymmetry is a property of the model and not a defect of the code, and
// it is the reason the two functions are named for their direction.
//
// WHY EXECUTE IS GRANTED BY `0` AND WRITE IS NOT. r-x sits between rwx and r--
// because in this model WRITE is the dangerous verb: a directory that can be
// traversed and a binary that can be run are both safe to share, while a write
// mutates state other processes can see. So the middle value withholds write
// and keeps execute, and `check_permission` denies exactly one access at 0.

fn perm_to_unix(perm: trit) -> int {
    tif perm {
        + => return 493,   // 0755
        0 => return 365,   // 0555
        - => return 292,   // 0444
    }
}

fn unix_to_perm(mode: int) -> trit {
    // Read the OWNER triad only -- bits 6,7,8 of the mode.
    let owner = (mode / 64) % 8;
    let w = (owner / 2) % 2;
    let x = owner % 2;
    if w == 1 { return +; }        // writable -> rwx, the only value that allows write
    elif x == 1 { return 0; }      // executable, not writable -> r-x
    else { return -; }             // neither -> r--
}

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
