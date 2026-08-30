// fs/hosted_store.mt — TritFS backed by real files. HOSTED ONLY.
// Author: Manish Jagdish Thatte
// © Manish Jagdish Thatte
//
// ENHANCEMENT_PLAN §3, and the reason this is a SEPARATE MODULE listed in
// `src/kernel_demos.manifest` and NOT in `src/kernel.manifest` is a
// measurement rather than a preference.
//
// §3 says "in hosted mode, back inodes with real files ... through the `fs_*`
// builtins that already exist and already work". They do exist and they do
// work — on LLVM. Probed directly on 30 August 2026:
//
//     fs_mkdir / fs_write_file / fs_read_file, --target llvm : write then
//         read returns the bytes, end to end.
//     the same program,               --target t3  : type-checks, writes its
//         .t3s, and dies in the assembler with `Undefined label: fs_mkdir`.
//
// That is §3.4's finding about the `gui_*` surface, in the filesystem: the
// builtin is declared in the analyzer and implemented in the C runtime against
// the host, and has no T3ISA syscall. Around ninety registered builtins are in
// that state.
//
// `build/kernel` is built for BOTH backends and the suite requires its two
// outputs to be byte-identical, so a single `fs_read_file` anywhere the kernel
// can reach it stops the kernel building for its own target. The persistent
// layer therefore lives beside the demos, which are hosted-only by
// construction, and the kernel keeps the in-memory store that `sys_write_data`
// writes to — which is real data movement on both backends, just not durable.
//
// WHAT WOULD REMOVE THIS SPLIT: Phase 6(a), giving the `fs_*` family T3ISA
// syscalls. Until then "TritFS has real storage" is a true sentence about the
// hosted kernel and a false one about the T3 target, and saying so is cheaper
// than discovering it.

use std::io;

// One directory under /tmp. Files are named by INODE NUMBER and not by the
// inode's `name`, because an inode name is a path (`/tmp/test.mt`) and using
// it directly would ask the host filesystem to create nested directories that
// TritFS does not model.
fn store_root() -> str { return "/tmp/thatteos_tritfs"; }

fn store_path(ino: int) -> str {
    return str::concat(str::concat(store_root(), "/ino"), str::from_int(ino));
}

fn store_init() {
    fs_mkdir(store_root());
    io::print("[STORE] backing store at ");
    io::println(store_root());
}

// store_flush: inode -> real file.
fn store_flush(fs: TritFS, ino: int) -> bool {
    if ino < 0 || ino > 8 { return false; }
    let inode = fs_inode_at(fs, ino);
    if !inode.valid { return false; }
    fs_write_file(store_path(ino), inode.content);
    io::print("[STORE] flushed inode ");
    io::print_int(ino);
    io::print(" (");
    io::print_int(inode.size);
    io::println(" bytes) to disk");
    return true;
}

// store_load: real file -> inode. Returns false when nothing is on disk, which
// is distinguishable from an empty file only by asking the host; this layer
// treats "" as absent and says so here rather than pretending otherwise.
fn store_load(fs: TritFS, ino: int) -> bool {
    if ino < 0 || ino > 8 { return false; }
    let data = fs_read_file(store_path(ino));
    if data == "" { return false; }
    let ok = fs_set_content(fs, ino, data);
    io::print("[STORE] loaded inode ");
    io::print_int(ino);
    io::print(" (");
    io::print_int(str::len(data));
    io::println(" bytes) from disk");
    return ok;
}
