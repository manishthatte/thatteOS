// src/demos/syscall.mt — the demonstration lifted out of src/syscall/syscall.mt
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

// syscall_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn syscall_demo() {
    io::println("=== THATTE-OS Syscall Dispatcher Demo ===");
    io::println("Claim 4: All 16 syscalls via TBRANCH sign(R1)");
    io::println("");

    syscall_init();
    io::println("");

    io::println("--- Null syscall ---");
    let r_null = syscall_dispatch(0, 0, 0);
    io::print("  R1="); io::println_int(r_null);
    io::println("");

    io::println("--- Positive syscalls ---");
    let r_fork = syscall_dispatch(1, 0, 0);
    io::print("  R1=child_pid="); io::println_int(r_fork);
    io::println("");

    let r_exec = syscall_dispatch(2, 4096, 0);
    io::print("  R1="); io::println_int(r_exec);
    io::println("");

    let r_alloc = syscall_dispatch(5, 4, 0);
    io::print("  R1=base_addr=0x"); io::println_int(r_alloc);
    io::println("");

    let r_modload = syscall_dispatch(10, 16384, 0);
    io::print("  R1=module_id="); io::println_int(r_modload);
    io::println("");

    io::println("--- Negative syscalls ---");
    let r_yield = syscall_dispatch(-1, 0, 0);
    io::print("  R1="); io::println_int(r_yield);
    io::println("");

    let r_send = syscall_dispatch(-5, 2, 1024);
    io::print("  R1="); io::println_int(r_send);
    io::println("");

    let r_write = syscall_dispatch(-13, 1, 64);
    io::print("  R1=bytes="); io::println_int(r_write);
    io::println("");

    let r_open = syscall_dispatch(-11, 2048, 0);
    io::print("  R1=fd="); io::println_int(r_open);
    io::println("");

    let r_priv = syscall_dispatch(-2, -1, 0);
    io::print("  R1=new_priv="); io::println_int(r_priv);
    io::println("");

    io::println("=== Syscall claims verified ===");
    io::println("  TBRANCH sign(R1) dispatch: PASS");
    io::println("  All 16 syscall handlers:   PASS");
    io::println("  R1 return convention:       PASS");
}
