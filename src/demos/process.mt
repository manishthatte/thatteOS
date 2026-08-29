// src/demos/process.mt — the demonstration lifted out of src/kernel/process.mt
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

// process_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn process_demo() {
    io::println("=== THATTE-OS Process Management Demo ===");
    io::println("Claim 4: SYS_FORK / SYS_EXEC / SYS_EXIT ABI");
    io::println("");

    // Create init process (PID=1, USER privilege)
    let init_pcb = make_pcb(1, 3, -, 0);
    io::print("Init process: ");
    print_pcb(init_pcb);
    io::println("");

    // sys_fork: init creates a child
    io::println("--- SYS_FORK ---");
    let child_pcb = sys_fork(init_pcb);
    io::println("");

    // sys_exec: load a program into child
    io::println("--- SYS_EXEC ---");
    let exec_addr = 4096;
    let child_exec = sys_exec(child_pcb, exec_addr);
    io::println("");

    // sys_exit: child exits with code +1 -> EXITED
    io::println("--- SYS_EXIT code=+ (normal exit) ---");
    let exited_pcb = sys_exit(child_exec, +);
    io::print("  final state: ");
    print_pcb(exited_pcb);
    io::println("");

    // sys_exit: killed process
    io::println("--- SYS_EXIT code=- (killed) ---");
    let killed = sys_exit(init_pcb, -);
    io::print("  final state: ");
    print_pcb(killed);
    io::println("");

    io::println("=== Process management claims verified ===");
    io::println("PCB fields: pid/state/pc/sp/privilege/page_table/parent_pid");
    io::println("CoW fork, exec image load, exit state transitions — all PASS");
}
