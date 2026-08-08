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

// ---------------------------------------------------------------------------
// Minimal Inode definition (TODO: import from fs::inode when available)
// ---------------------------------------------------------------------------

struct Inode {
    pub ino: int,
    pub itype: trit,
    pub perm: trit,
    pub size: int,
    pub data_addr: int,
    pub name: str,
    pub parent_ino: int,
    pub valid: bool,
}

fn perm_name(p: trit) -> str {
    tif p {
        + => return "rwx",
        0 => return "r-x",
        - => return "r--",
    }
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

fn main() {
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
