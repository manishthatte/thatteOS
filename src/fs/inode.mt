// fs/inode.mt — THATTE-OS inode layer and filesystem image
// Extracted from tritfs.mt (GOD file split).
//
// Responsibilities:
//   - Inode struct and type helpers
//   - TritFS image struct (flat inode table, 9 entries)
//   - tritfs_init: bootstrap root filesystem
//   - sys_mkdir, create_file: inode allocation
//   - sys_stat: display inode metadata
//
// TODO: when module imports are added, `use fs::inode;` replaces inline defs.

use std::io;

// ---------------------------------------------------------------------------
// Inode type and permission helpers
// ---------------------------------------------------------------------------

fn itype_name(t: trit) -> str {
    tif t {
        + => return "FILE",
        0 => return "DIR ",
        - => return "DEV ",
    }
}

fn perm_name(p: trit) -> str {
    tif p {
        + => return "rwx",
        0 => return "r-x",
        - => return "r--",
    }
}

// ---------------------------------------------------------------------------
// Inode: trit-typed metadata record
//   itype: +1=file, 0=directory, -1=device
//   perm:  +1=rwx,  0=r-x,       -1=r--
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

fn make_inode(ino: int, itype: trit, perm: trit, name: str, parent: int) -> Inode {
    return Inode { ino: ino, itype: itype, perm: perm,
                   size: 0, data_addr: 0, name: name,
                   parent_ino: parent, valid: true };
}

fn empty_inode() -> Inode {
    return Inode { ino: 0, itype: 0, perm: 0, size: 0, data_addr: 0,
                   name: "", parent_ino: 0, valid: false };
}

fn print_inode(inode: Inode) {
    io::print("  [");
    io::print_int(inode.ino);
    io::print("] ");
    io::print(itype_name(inode.itype));
    io::print(" ");
    io::print(perm_name(inode.perm));
    io::print(" size=");
    io::print_int(inode.size);
    io::print(" ");
    io::println(inode.name);
}

// ---------------------------------------------------------------------------
// TritFS: flat inode table (9 entries, ternary-sized)
// ---------------------------------------------------------------------------

struct TritFS {
    pub next_ino: int,
    pub i0: Inode, pub i1: Inode, pub i2: Inode,
    pub i3: Inode, pub i4: Inode, pub i5: Inode,
    pub i6: Inode, pub i7: Inode, pub i8: Inode,
}

fn tritfs_init() -> TritFS {
    io::println("[TRITFS] tritfs_init: ternary filesystem bootstrap");
    io::println("  inode types: FILE(+1) DIR(0) DEV(-1)");
    io::println("  permissions: rwx(+1) r-x(0) r--(-)");

    let root    = make_inode(0, 0, 0, "/",        -1);
    let dev     = make_inode(1, 0, 0, "/dev",      0);
    let tty_dev = make_inode(2, -, +, "/dev/tty",  1);
    let proc_d  = make_inode(3, 0, -, "/proc",     0);
    let tmp     = make_inode(4, 0, +, "/tmp",      0);
    let bin     = make_inode(5, 0, 0, "/bin",      0);

    return TritFS {
        next_ino: 6,
        i0: root, i1: dev, i2: tty_dev,
        i3: proc_d, i4: tmp, i5: bin,
        i6: empty_inode(), i7: empty_inode(), i8: empty_inode(),
    };
}

// ---------------------------------------------------------------------------
// inode_set: return TritFS with slot[idx] replaced
// ---------------------------------------------------------------------------

fn inode_set(fs: TritFS, new_inode: Inode) -> TritFS {
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
// sys_mkdir: create a directory inode
// ---------------------------------------------------------------------------

fn sys_mkdir(fs: TritFS, name: str, parent_ino: int) -> TritFS {
    io::print("[SYS_MKDIR] name=");
    io::print(name);
    io::print(" parent_ino=");
    io::println_int(parent_ino);
    if fs.next_ino >= 9 {
        io::println("  ERROR: inode table full");
        return fs;
    }
    let new_inode = make_inode(fs.next_ino, 0, +, name, parent_ino);
    io::print("  ino=");
    io::println_int(fs.next_ino);
    print_inode(new_inode);
    return inode_set(fs, new_inode);
}

// ---------------------------------------------------------------------------
// create_file: create a regular file inode
// ---------------------------------------------------------------------------

fn create_file(fs: TritFS, name: str, parent_ino: int, perm: trit) -> TritFS {
    io::print("[TRITFS] create_file: name=");
    io::print(name);
    io::print(" parent_ino=");
    io::println_int(parent_ino);
    if fs.next_ino >= 9 {
        io::println("  ERROR: inode table full");
        return fs;
    }
    let new_inode = make_inode(fs.next_ino, +, perm, name, parent_ino);
    io::print("  ino=");
    io::println_int(fs.next_ino);
    print_inode(new_inode);
    return inode_set(fs, new_inode);
}

// ---------------------------------------------------------------------------
// sys_stat: print inode metadata
// ---------------------------------------------------------------------------

fn sys_stat(inode: Inode) {
    io::println("[SYS_STAT]");
    io::print("  inode: "); io::println_int(inode.ino);
    io::print("  type:  "); io::println(itype_name(inode.itype));
    io::print("  perm:  "); io::println(perm_name(inode.perm));
    io::print("  size:  "); io::println_int(inode.size);
    io::print("  name:  "); io::println(inode.name);
}

// ---------------------------------------------------------------------------
// main: inode layer standalone demo
// ---------------------------------------------------------------------------
