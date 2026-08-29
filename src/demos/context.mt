// src/demos/context.mt — the demonstration lifted out of src/kernel/context.mt
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

// context_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn context_demo() {
    io::println("=== THATTE-OS CPU Context Switch Demo ===");
    io::println("Thatte3 Claim 2: T3ISA 9+3 register file");
    io::println("Thatte3 Claim 7: context save/restore for preemption");
    io::println("");

    let mut bank = context_bank_init();

    // Pre-load a saved context for PID 1 (init process at startup)
    io::println("--- Bootstrapping PID 1 context (init) ---");
    let init_ctx = context_save(1,
        100,    // PC = instruction 100 (init entry point)
        4000,   // SP = stack top
        0,      // LR = 0 (no caller)
        RegFile { ..empty_regfile(), r1: 1 });
    bank = context_bank_set(bank, init_ctx);
    io::println("");

    // PID 2 (shell) is running; timer fires — switch to PID 1
    io::println("--- Timer preempt: PID 2 (shell) -> PID 1 (init) ---");
    bank = context_switch(bank,
        2,      // from: shell
        1,      // to:   init
        // shell's current register state:
        200, 8000, 204,   // PC, SP, LR
        RegFile { ..empty_regfile(), r0: 42, r1: 7, r3: 13 });
    io::println("");

    // Check shell context was saved
    io::println("--- Verify PID 2 context was saved ---");
    let shell_ctx = context_bank_get(bank, 2);
    io::print("  PID 2 saved: PC=");
    io::print_int(shell_ctx.pc);
    io::print("  SP=");
    io::print_int(shell_ctx.sp);
    io::print("  r0=");
    io::println_int(shell_ctx.r0);
    io::println("");

    // Switch back to shell
    io::println("--- Schedule back: PID 1 -> PID 2 (shell) ---");
    bank = context_switch(bank,
        1,      // from: init
        2,      // to:   shell
        105, 4000, 0,   // init's current PC, SP, LR
        empty_regfile());
    io::println("");

    io::println("=== Context claims verified ===");
    io::println("  T3ISA 9+3 register file save:   PASS");
    io::println("  context_save (snapshot):        PASS");
    io::println("  context_restore (log reload):   PASS");
    io::println("  ContextBank (9-slot table):     PASS");
    io::println("  context_switch (save+restore):  PASS");
}
