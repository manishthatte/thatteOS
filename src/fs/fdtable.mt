// fs/fdtable.mt — THATTE-OS per-process file descriptor table
// Extracted from tritfs.mt (GOD file split).
//
// Responsibilities:
//   - FileDesc struct (FD, inode reference, offset, mode)
//   - FdTable struct (9 FDs per process, ternary-sized)
//   - fd_table_init: pre-open stdin/stdout/stderr
//   - sys_open, sys_close, sys_read, sys_write
//
// TODO: when module imports are added, `use fs::fdtable;`.

use std::io;

// ---------------------------------------------------------------------------
// FD mode helpers: +1=read-only, 0=read/write, -1=write-only
// ---------------------------------------------------------------------------

fn mode_name(m: trit) -> str {
    tif m {
        + => return "READ",
        0 => return "READ/WRITE",
        - => return "WRITE",
    }
}

// ---------------------------------------------------------------------------
// FileDesc: open file handle
// ---------------------------------------------------------------------------

struct FileDesc {
    pub fd: int,
    pub ino: int,
    pub offset: int,
    pub mode: trit,   // +1=read, 0=r/w, -1=write
    pub open: bool,
}

fn make_fd(fd: int, ino: int, mode: trit) -> FileDesc {
    return FileDesc { fd: fd, ino: ino, offset: 0, mode: mode, open: true };
}

fn empty_fd() -> FileDesc {
    return FileDesc { fd: 0, ino: 0, offset: 0, mode: 0, open: false };
}

// ---------------------------------------------------------------------------
// FdTable: 9-descriptor per-process table
// ---------------------------------------------------------------------------

struct FdTable {
    pub pid: int,
    pub count: int,
    pub fd0: FileDesc,  // stdin
    pub fd1: FileDesc,  // stdout
    pub fd2: FileDesc,  // stderr
    pub fd3: FileDesc,
    pub fd4: FileDesc,
    pub fd5: FileDesc,
    pub fd6: FileDesc,
    pub fd7: FileDesc,
    pub fd8: FileDesc,
}

fn fd_table_init(pid: int) -> FdTable {
    let stdin  = make_fd(0, 2, +);   // ino 2 = /dev/tty, read
    let stdout = make_fd(1, 2, -);   // ino 2 = /dev/tty, write
    let stderr = make_fd(2, 2, -);   // ino 2 = /dev/tty, write
    io::print("[FDTABLE] fd_table_init: PID=");
    io::print_int(pid);
    io::println(" — stdin/stdout/stderr opened on /dev/tty");
    return FdTable {
        pid: pid, count: 3,
        fd0: stdin, fd1: stdout, fd2: stderr,
        fd3: empty_fd(), fd4: empty_fd(), fd5: empty_fd(),
        fd6: empty_fd(), fd7: empty_fd(), fd8: empty_fd(),
    };
}

// ---------------------------------------------------------------------------
// fd_table_get: fetch the descriptor stored in a slot
// ---------------------------------------------------------------------------

fn fd_table_get(fd_table: FdTable, slot: int) -> FileDesc {
    if slot == 0 { return fd_table.fd0; }
    elif slot == 1 { return fd_table.fd1; }
    elif slot == 2 { return fd_table.fd2; }
    elif slot == 3 { return fd_table.fd3; }
    elif slot == 4 { return fd_table.fd4; }
    elif slot == 5 { return fd_table.fd5; }
    elif slot == 6 { return fd_table.fd6; }
    elif slot == 7 { return fd_table.fd7; }
    else { return fd_table.fd8; }
}

// ---------------------------------------------------------------------------
// fd_find_free_slot: first slot whose descriptor is not open (-1 = none)
// ---------------------------------------------------------------------------

fn fd_find_free_slot(fd_table: FdTable) -> int {
    let mut slot = 0;
    while slot < 9 {
        if !fd_table_get(fd_table, slot).open {
            return slot;
        }
        slot = slot + 1;
    }
    return -1;
}

// ---------------------------------------------------------------------------
// fd_table_set: place fd in the given slot
// ---------------------------------------------------------------------------

fn fd_table_set(fd_table: FdTable, new_fd: FileDesc, slot: int, new_count: int) -> FdTable {
    if slot == 0 {
        return FdTable { pid: fd_table.pid, count: new_count,
            fd0: new_fd, fd1: fd_table.fd1, fd2: fd_table.fd2,
            fd3: fd_table.fd3, fd4: fd_table.fd4, fd5: fd_table.fd5,
            fd6: fd_table.fd6, fd7: fd_table.fd7, fd8: fd_table.fd8 };
    } elif slot == 1 {
        return FdTable { pid: fd_table.pid, count: new_count,
            fd0: fd_table.fd0, fd1: new_fd, fd2: fd_table.fd2,
            fd3: fd_table.fd3, fd4: fd_table.fd4, fd5: fd_table.fd5,
            fd6: fd_table.fd6, fd7: fd_table.fd7, fd8: fd_table.fd8 };
    } elif slot == 2 {
        return FdTable { pid: fd_table.pid, count: new_count,
            fd0: fd_table.fd0, fd1: fd_table.fd1, fd2: new_fd,
            fd3: fd_table.fd3, fd4: fd_table.fd4, fd5: fd_table.fd5,
            fd6: fd_table.fd6, fd7: fd_table.fd7, fd8: fd_table.fd8 };
    } elif slot == 3 {
        return FdTable { pid: fd_table.pid, count: new_count,
            fd0: fd_table.fd0, fd1: fd_table.fd1, fd2: fd_table.fd2,
            fd3: new_fd, fd4: fd_table.fd4, fd5: fd_table.fd5,
            fd6: fd_table.fd6, fd7: fd_table.fd7, fd8: fd_table.fd8 };
    } elif slot == 4 {
        return FdTable { pid: fd_table.pid, count: new_count,
            fd0: fd_table.fd0, fd1: fd_table.fd1, fd2: fd_table.fd2,
            fd3: fd_table.fd3, fd4: new_fd, fd5: fd_table.fd5,
            fd6: fd_table.fd6, fd7: fd_table.fd7, fd8: fd_table.fd8 };
    } elif slot == 5 {
        return FdTable { pid: fd_table.pid, count: new_count,
            fd0: fd_table.fd0, fd1: fd_table.fd1, fd2: fd_table.fd2,
            fd3: fd_table.fd3, fd4: fd_table.fd4, fd5: new_fd,
            fd6: fd_table.fd6, fd7: fd_table.fd7, fd8: fd_table.fd8 };
    } elif slot == 6 {
        return FdTable { pid: fd_table.pid, count: new_count,
            fd0: fd_table.fd0, fd1: fd_table.fd1, fd2: fd_table.fd2,
            fd3: fd_table.fd3, fd4: fd_table.fd4, fd5: fd_table.fd5,
            fd6: new_fd, fd7: fd_table.fd7, fd8: fd_table.fd8 };
    } elif slot == 7 {
        return FdTable { pid: fd_table.pid, count: new_count,
            fd0: fd_table.fd0, fd1: fd_table.fd1, fd2: fd_table.fd2,
            fd3: fd_table.fd3, fd4: fd_table.fd4, fd5: fd_table.fd5,
            fd6: fd_table.fd6, fd7: new_fd, fd8: fd_table.fd8 };
    } else {
        return FdTable { pid: fd_table.pid, count: new_count,
            fd0: fd_table.fd0, fd1: fd_table.fd1, fd2: fd_table.fd2,
            fd3: fd_table.fd3, fd4: fd_table.fd4, fd5: fd_table.fd5,
            fd6: fd_table.fd6, fd7: fd_table.fd7, fd8: new_fd };
    }
}

// ---------------------------------------------------------------------------
// sys_open: allocate the first free FD slot, bind to inode
// ---------------------------------------------------------------------------

fn sys_open(fd_table: FdTable, ino: int, mode: trit, inode_name: str) -> FdTable {
    io::print("[SYS_OPEN] ino=");
    io::print_int(ino);
    io::print(" name=");
    io::print(inode_name);
    io::print(" mode=");
    io::println(mode_name(mode));

    let slot = fd_find_free_slot(fd_table);
    if slot < 0 {
        io::println("  ERROR: FD table full (9 max) — EMFILE");
        return fd_table;
    }

    let new_fd = make_fd(slot, ino, mode);
    io::print("  allocated fd=");
    io::println_int(slot);
    return fd_table_set(fd_table, new_fd, slot, fd_table.count + 1);
}

// ---------------------------------------------------------------------------
// sys_close: release file descriptor
// Returns the exit code AND the updated table (slot freed, count reduced).
// ---------------------------------------------------------------------------

struct CloseResult {
    pub code: int,
    pub table: FdTable,
}

fn close_result(code: int, table: FdTable) -> CloseResult {
    return CloseResult { code: code, table: table };
}

fn sys_close(fd_num: int, fd_table: FdTable) -> CloseResult {
    io::print("[SYS_CLOSE] fd=");
    io::println_int(fd_num);
    if fd_num < 0 || fd_num > 8 {
        io::println("  ERROR: invalid fd — EBADF");
        return close_result(-1, fd_table);
    }
    if fd_table_get(fd_table, fd_num).open {
        io::println("  fd closed, offset reset");
        return close_result(0, fd_table_set(fd_table, empty_fd(), fd_num, fd_table.count - 1));
    }
    io::println("  ERROR: fd not open — EBADF");
    return close_result(-1, fd_table);
}

// ---------------------------------------------------------------------------
// sys_read: read N trytes from fd into buf
// ---------------------------------------------------------------------------

fn sys_read(fd_num: int, buf_addr: int, len: int) -> int {
    io::print("[SYS_READ] fd=");
    io::print_int(fd_num);
    io::print(" buf=");
    io::print_int(buf_addr);
    io::print(" len=");
    io::println_int(len);
    if fd_num < 0 || fd_num > 8 {
        io::println("  ERROR: invalid fd — EBADF");
        return -1;
    }
    if len <= 0 {
        io::println("  ERROR: invalid length — EINVAL");
        return -1;
    }
    io::print("  read ");
    io::print_int(len);
    io::println(" trytes");
    return len;
}

// ---------------------------------------------------------------------------
// sys_write: write N trytes from buf to fd
// ---------------------------------------------------------------------------

fn sys_write(fd_num: int, buf_addr: int, len: int) -> int {
    io::print("[SYS_WRITE] fd=");
    io::print_int(fd_num);
    io::print(" buf=");
    io::print_int(buf_addr);
    io::print(" len=");
    io::println_int(len);
    if fd_num < 0 || fd_num > 8 {
        io::println("  ERROR: invalid fd — EBADF");
        return -1;
    }
    if len <= 0 {
        io::println("  ERROR: invalid length — EINVAL");
        return -1;
    }
    io::print("  wrote ");
    io::print_int(len);
    io::println(" trytes");
    return len;
}

// ---------------------------------------------------------------------------
// print_fdtable: display open FDs
// ---------------------------------------------------------------------------

fn print_fdtable(t: FdTable) {
    io::print("[FDTABLE] PID=");
    io::print_int(t.pid);
    io::print("  open_fds=");
    io::println_int(t.count);
    let fds: [FileDesc] = [t.fd0, t.fd1, t.fd2, t.fd3, t.fd4,
                            t.fd5, t.fd6, t.fd7, t.fd8];
    let mut i = 0;
    while i < 9 {
        let fd = fds[i];
        if fd.open {
            io::print("  fd[");
            io::print_int(fd.fd);
            io::print("] ino=");
            io::print_int(fd.ino);
            io::print(" mode=");
            io::print(mode_name(fd.mode));
            io::print(" offset=");
            io::println_int(fd.offset);
        }
        i = i + 1;
    }
}

// ---------------------------------------------------------------------------
// main: FD table standalone demo
// ---------------------------------------------------------------------------
