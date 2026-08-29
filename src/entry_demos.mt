// entry_demos.mt — the kernel plus its 25 module demonstrations
// Author: Manish Jagdish Thatte
//
// HOSTED ONLY, and the reason is a measurement rather than a preference: with
// `run_all_demos()` calling all 25, every demo is reachable, nothing can
// eliminate them, and the T3 code image goes from 56,421 words to **60,760** —
// past the 60,000-word ceiling the stack grows down from. The assembler
// refuses it, correctly. src/kernel.manifest builds the same kernel without
// this module and fits on both backends.
//
// The demos were 25 separate `fn main`s until the 30 August 2026 merge. They
// are the only exercise most of the kernel has ever had, so they were renamed
// rather than deleted — and a renamed function nothing calls is dead code with
// a nicer name, which is what this module is for.

use std::io;
use std::env;
use std::str;

// Compare a command-line argument against a literal.
//
// THE `str::concat(..., "")` IS NOT DECORATION AND MUST NOT BE REMOVED. On
// maniTC as of 30 August 2026, `env::arg(i) == "demos"` is **always false** —
// so reliably that `env::arg(1) == env::arg(1)` is false too, a string that
// does not equal itself. The IR says why: `env::arg` lowers with
// `ret_ty: I64`, so `==` becomes INTEGER equality on the pointer, and two
// `strdup` calls never return the same address. `str::concat` lowers with
// `ret_ty: Ptr(I8)` and gets `StrEq`, which is why passing the argument
// through it repairs the comparison.
//
// It is silent: the argument PRINTS correctly, `str::len` reports 5, and the
// program simply takes the other branch. `env::arch() == "x86_64"` is false on
// this machine for the same reason. Filed as maniTC report.txt P92; this wart
// comes out when that lands.
fn arg_is(i: int, want: str) -> bool {
    return str::concat(env::arg(i), "") == want;
}

fn run_all_demos() {
    io::println("");
    io::println("########################################");
    io::println("# module demonstrations (25)");
    io::println("########################################");
    tmin2_demo();      klog_demo();        privilege_demo();
    panic_demo();      guard_demo();       context_demo();
    process_demo();    scheduler_demo();   timer_demo();
    signal_demo();     interrupt_demo();   pgtable_demo();
    vmem_demo();       mmu_demo();         inode_demo();
    perms_demo();      fdtable_demo();     tritfs_demo();
    messages_demo();   pipe_demo();        trit_stream_demo();
    tty_demo();        syscall_demo();     capability_demo();
    photon_cap_demo();
    io::println("");
    io::println("########################################");
    io::println("# all 25 module demonstrations complete");
    io::println("########################################");
}

fn main() {
    kernel_main();
    if env::argc() > 1 {
        if arg_is(1, "demos") { run_all_demos(); }
    } else {
        run_all_demos();
    }
}
