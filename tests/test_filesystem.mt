// test_filesystem.mt — THATTE-OS TritFS filesystem tests
// Verifies inode types, permissions, FD table, sys_open/read/write,
// permission checks (all 9 access/perm combos), and sys_mkdir.

use std::io;

// ---------------------------------------------------------------------------
// Test helper
// ---------------------------------------------------------------------------

fn assert_true(cond: bool, name: str, test_num: int) -> int {
    io::print("  test ");
    io::print_int(test_num);
    io::print(": ");
    io::print(name);
    if cond {
        io::println(" — PASS");
        return 1;
    } else {
        io::println(" — FAIL");
        return 0;
    }
}

// ---------------------------------------------------------------------------
// Minimal reproduction of TritFS types and functions
// ---------------------------------------------------------------------------

struct Inode {
    pub ino: int,
    pub itype: trit,        // +1=file, 0=directory, -1=device
    pub perm: trit,         // +1=rwx, 0=r-x, -1=r--
    pub size: int,
    pub data_addr: int,
    pub name: str,
    pub parent_ino: int,
    pub valid: bool,
}

fn make_inode(ino: int, itype: trit, perm: trit, name: str, parent: int) -> Inode {
    return Inode {
        ino: ino, itype: itype, perm: perm,
        size: 0, data_addr: 0,
        name: name, parent_ino: parent, valid: true,
    };
}

fn empty_inode() -> Inode {
    return Inode { ino: 0, itype: 0, perm: 0, size: 0, data_addr: 0,
                   name: "", parent_ino: 0, valid: false };
}

struct FileDesc {
    pub fd: int,
    pub ino: int,
    pub offset: int,
    pub mode: trit,         // +1=read, 0=read/write, -1=write-only
    pub open: bool,
}

fn make_fd(fd: int, ino: int, mode: trit) -> FileDesc {
    return FileDesc { fd: fd, ino: ino, offset: 0, mode: mode, open: true };
}

fn empty_fd() -> FileDesc {
    return FileDesc { fd: 0, ino: 0, offset: 0, mode: 0, open: false };
}

struct FdTable {
    pub pid: int,
    pub count: int,
    pub fd0: FileDesc,
    pub fd1: FileDesc,
    pub fd2: FileDesc,
    pub fd3: FileDesc,
    pub fd4: FileDesc,
    pub fd5: FileDesc,
    pub fd6: FileDesc,
    pub fd7: FileDesc,
    pub fd8: FileDesc,
}

fn fd_table_init(pid: int) -> FdTable {
    let stdin  = make_fd(0, 100, +);
    let stdout = make_fd(1, 100, -);
    let stderr = make_fd(2, 100, -);
    return FdTable {
        pid: pid, count: 3,
        fd0: stdin, fd1: stdout, fd2: stderr,
        fd3: empty_fd(), fd4: empty_fd(), fd5: empty_fd(),
        fd6: empty_fd(), fd7: empty_fd(), fd8: empty_fd(),
    };
}

fn sys_open_fd(fd_table: FdTable, ino: int, mode: trit) -> FdTable {
    if fd_table.count >= 9 { return fd_table; }
    let new_fd = make_fd(fd_table.count, ino, mode);
    let new_count = fd_table.count + 1;
    if fd_table.count == 3 {
        return FdTable { pid: fd_table.pid, count: new_count,
            fd0: fd_table.fd0, fd1: fd_table.fd1, fd2: fd_table.fd2,
            fd3: new_fd, fd4: fd_table.fd4, fd5: fd_table.fd5,
            fd6: fd_table.fd6, fd7: fd_table.fd7, fd8: fd_table.fd8 };
    } elif fd_table.count == 4 {
        return FdTable { pid: fd_table.pid, count: new_count,
            fd0: fd_table.fd0, fd1: fd_table.fd1, fd2: fd_table.fd2,
            fd3: fd_table.fd3, fd4: new_fd, fd5: fd_table.fd5,
            fd6: fd_table.fd6, fd7: fd_table.fd7, fd8: fd_table.fd8 };
    } else {
        return fd_table;
    }
}

fn sys_read(fd_num: int, len: int) -> int {
    if fd_num < 0 || fd_num > 8 { return -1; }
    if len <= 0 { return -1; }
    return len;
}

fn sys_write(fd_num: int, len: int) -> int {
    if fd_num < 0 || fd_num > 8 { return -1; }
    if len <= 0 { return -1; }
    return len;
}

// check_permission: access trit (+1=read, 0=write, -1=execute)
fn check_permission(perm: trit, access: trit) -> bool {
    tif perm {
        + => {
            // rwx — all allowed
            return true;
        }
        0 => {
            // r-x — read and exec only
            tif access {
                + => return true,
                0 => return false,
                - => return true,
            }
        }
        - => {
            // r-- — read only
            tif access {
                + => return true,
                0 => return false,
                - => return false,
            }
        }
    }
}

struct TritFS {
    pub next_ino: int,
    pub i0: Inode,
    pub i1: Inode,
    pub i2: Inode,
    pub i3: Inode,
    pub i4: Inode,
    pub i5: Inode,
    pub i6: Inode,
    pub i7: Inode,
    pub i8: Inode,
}

fn tritfs_init() -> TritFS {
    let root    = make_inode(0, 0, 0, "/",        -1);
    let dev     = make_inode(1, 0, 0, "/dev",      0);
    let tty_dev = make_inode(2, -, +, "/dev/tty",  1);
    let proc_d  = make_inode(3, 0, -, "/proc",     0);
    let tmp     = make_inode(4, 0, +, "/tmp",       0);
    let bin     = make_inode(5, 0, 0, "/bin",       0);
    return TritFS {
        next_ino: 6,
        i0: root, i1: dev, i2: tty_dev,
        i3: proc_d, i4: tmp, i5: bin,
        i6: empty_inode(), i7: empty_inode(), i8: empty_inode(),
    };
}

fn sys_mkdir(fs: TritFS, name: str, parent_ino: int) -> TritFS {
    if fs.next_ino >= 9 { return fs; }
    let new_inode = make_inode(fs.next_ino, 0, +, name, parent_ino);
    let next = fs.next_ino + 1;
    if fs.next_ino == 6 {
        return TritFS { next_ino: next, i0: fs.i0, i1: fs.i1, i2: fs.i2,
            i3: fs.i3, i4: fs.i4, i5: fs.i5, i6: new_inode, i7: fs.i7, i8: fs.i8 };
    } elif fs.next_ino == 7 {
        return TritFS { next_ino: next, i0: fs.i0, i1: fs.i1, i2: fs.i2,
            i3: fs.i3, i4: fs.i4, i5: fs.i5, i6: fs.i6, i7: new_inode, i8: fs.i8 };
    } else {
        return TritFS { next_ino: next, i0: fs.i0, i1: fs.i1, i2: fs.i2,
            i3: fs.i3, i4: fs.i4, i5: fs.i5, i6: fs.i6, i7: fs.i7, i8: new_inode };
    }
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn main() {
    io::println("=== THATTE-OS Filesystem Tests ===");
    let mut passed = 0;
    let mut total = 0;

    // --- Inode type trit tests ---
    let file_inode = make_inode(10, +, +, "test.mt", 0);
    let dir_inode  = make_inode(11, 0, 0, "mydir", 0);
    let dev_inode  = make_inode(12, -, +, "tty0", 1);

    total = total + 1;
    let file_type: bool = tif file_inode.itype { + => true, 0 => false, - => false };
    passed = passed + assert_true(file_type, "inode type FILE = +1", total);

    total = total + 1;
    let dir_type: bool = tif dir_inode.itype { + => false, 0 => true, - => false };
    passed = passed + assert_true(dir_type, "inode type DIR = 0", total);

    total = total + 1;
    let dev_type: bool = tif dev_inode.itype { + => false, 0 => false, - => true };
    passed = passed + assert_true(dev_type, "inode type DEV = -1", total);

    // --- Permission trit tests ---
    let rwx_inode = make_inode(20, +, +, "rwx_file", 0);
    let rx_inode  = make_inode(21, +, 0, "rx_file", 0);
    let ro_inode  = make_inode(22, +, -, "ro_file", 0);

    total = total + 1;
    let rwx_perm: bool = tif rwx_inode.perm { + => true, 0 => false, - => false };
    passed = passed + assert_true(rwx_perm, "permission rwx = +1", total);

    total = total + 1;
    let rx_perm: bool = tif rx_inode.perm { + => false, 0 => true, - => false };
    passed = passed + assert_true(rx_perm, "permission r-x = 0", total);

    total = total + 1;
    let ro_perm: bool = tif ro_inode.perm { + => false, 0 => false, - => true };
    passed = passed + assert_true(ro_perm, "permission r-- = -1", total);

    // --- FD table init: stdin/stdout/stderr pre-opened ---
    let fdt = fd_table_init(1);

    total = total + 1;
    passed = passed + assert_true(fdt.count == 3, "FD table init count = 3", total);

    total = total + 1;
    passed = passed + assert_true(fdt.fd0.open, "stdin (fd0) is open", total);

    total = total + 1;
    passed = passed + assert_true(fdt.fd1.open, "stdout (fd1) is open", total);

    total = total + 1;
    passed = passed + assert_true(fdt.fd2.open, "stderr (fd2) is open", total);

    total = total + 1;
    passed = passed + assert_true(!fdt.fd3.open, "fd3 not open initially", total);

    total = total + 1;
    let stdin_read: bool = tif fdt.fd0.mode { + => true, 0 => false, - => false };
    passed = passed + assert_true(stdin_read, "stdin mode is READ (+1)", total);

    total = total + 1;
    let stdout_write: bool = tif fdt.fd1.mode { + => false, 0 => false, - => true };
    passed = passed + assert_true(stdout_write, "stdout mode is WRITE (-1)", total);

    // --- sys_open allocates next FD ---
    total = total + 1;
    let fdt2 = sys_open_fd(fdt, 7, 0);
    passed = passed + assert_true(fdt2.count == 4, "sys_open increments count to 4", total);

    total = total + 1;
    passed = passed + assert_true(fdt2.fd3.open, "sys_open opens fd3", total);

    total = total + 1;
    passed = passed + assert_true(fdt2.fd3.ino == 7, "sys_open fd3 points to inode 7", total);

    // --- sys_read with valid FD ---
    total = total + 1;
    let r1 = sys_read(0, 64);
    passed = passed + assert_true(r1 == 64, "sys_read valid FD returns len=64", total);

    // --- sys_read with invalid FD ---
    total = total + 1;
    let r2 = sys_read(-1, 64);
    passed = passed + assert_true(r2 == -1, "sys_read invalid FD=-1 returns -1", total);

    total = total + 1;
    let r3 = sys_read(9, 64);
    passed = passed + assert_true(r3 == -1, "sys_read invalid FD=9 returns -1", total);

    // --- sys_write with valid FD ---
    total = total + 1;
    let w1 = sys_write(1, 100);
    passed = passed + assert_true(w1 == 100, "sys_write valid FD returns len=100", total);

    // --- sys_write with invalid FD ---
    total = total + 1;
    let w2 = sys_write(-1, 100);
    passed = passed + assert_true(w2 == -1, "sys_write invalid FD=-1 returns -1", total);

    // --- sys_read with invalid length ---
    total = total + 1;
    let r4 = sys_read(0, 0);
    passed = passed + assert_true(r4 == -1, "sys_read len=0 returns -1", total);

    // --- Permission checks: all 9 combos (3 perms x 3 access types) ---
    // access: +1=read, 0=write, -1=execute

    // rwx (+1): all 3 allowed
    total = total + 1;
    passed = passed + assert_true(check_permission(+, +), "rwx + read -> allowed", total);

    total = total + 1;
    passed = passed + assert_true(check_permission(+, 0), "rwx + write -> allowed", total);

    total = total + 1;
    passed = passed + assert_true(check_permission(+, -), "rwx + exec -> allowed", total);

    // r-x (0): read and exec allowed, write denied
    total = total + 1;
    passed = passed + assert_true(check_permission(0, +), "r-x + read -> allowed", total);

    total = total + 1;
    passed = passed + assert_true(!check_permission(0, 0), "r-x + write -> denied", total);

    total = total + 1;
    passed = passed + assert_true(check_permission(0, -), "r-x + exec -> allowed", total);

    // r-- (-1): read only
    total = total + 1;
    passed = passed + assert_true(check_permission(-, +), "r-- + read -> allowed", total);

    total = total + 1;
    passed = passed + assert_true(!check_permission(-, 0), "r-- + write -> denied", total);

    total = total + 1;
    passed = passed + assert_true(!check_permission(-, -), "r-- + exec -> denied", total);

    // --- sys_mkdir creates directory ---
    let fs = tritfs_init();

    total = total + 1;
    passed = passed + assert_true(fs.next_ino == 6, "tritfs_init next_ino = 6", total);

    total = total + 1;
    let fs2 = sys_mkdir(fs, "/home", 0);
    passed = passed + assert_true(fs2.next_ino == 7, "sys_mkdir increments next_ino to 7", total);

    total = total + 1;
    passed = passed + assert_true(fs2.i6.valid, "sys_mkdir creates valid inode", total);

    total = total + 1;
    let mkdir_dir: bool = tif fs2.i6.itype { + => false, 0 => true, - => false };
    passed = passed + assert_true(mkdir_dir, "sys_mkdir creates DIR type inode", total);

    total = total + 1;
    let mkdir_rwx: bool = tif fs2.i6.perm { + => true, 0 => false, - => false };
    passed = passed + assert_true(mkdir_rwx, "sys_mkdir creates rwx permission", total);

    total = total + 1;
    passed = passed + assert_true(fs2.i6.parent_ino == 0, "sys_mkdir parent_ino correct", total);

    // --- Results ---
    io::println("");
    io::print("Results: ");
    io::print_int(passed);
    io::print("/");
    io::print_int(total);
    io::println(" passed");
}
