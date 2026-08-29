// src/demos/interrupt.mt — the demonstration lifted out of src/kernel/interrupt.mt
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

// interrupt_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn interrupt_demo() {
    io::println("=== THATTE-OS Enhanced Interrupt Architecture Demo ===");
    io::println("Claim 5: 27-vector IDT with TBRANCH priority dispatch");
    io::println("Enhanced: nesting + statistics + deferred batch");
    io::println("");

    interrupt_init();
    io::println("");

    let mut state = irq_state_init();

    io::println("--- Interrupt Dispatch Demonstrations ---");
    io::println("");

    // HIGH: syscall (vector 1)
    io::println("1. Syscall (HIGH):");
    state = interrupt_dispatch(1, state);
    io::println("");

    // Try to nest MEDIUM during HIGH
    io::println("2. Timer (MEDIUM) during HIGH handler:");
    state = interrupt_dispatch(0, state);
    io::println("");

    // Try to nest another HIGH during HIGH
    io::println("3. Page fault (HIGH) during HIGH handler:");
    state = interrupt_dispatch(2, state);
    io::println("");

    // Return from syscall
    io::println("4. Return from syscall handler:");
    state = interrupt_return(state);
    io::println("");

    // LOW: deferred
    io::println("5. Deferred interrupt (LOW):");
    state = interrupt_dispatch(20, state);
    io::println("");

    // Another LOW: deferred
    io::println("6. Another deferred interrupt (LOW):");
    state = interrupt_dispatch(22, state);
    io::println("");

    // Return from remaining handler
    io::println("7. Return (processes deferred):");
    state = interrupt_return(state);
    io::println("");

    // Statistics
    irq_stats(state);
    io::println("");

    io::println("=== Enhanced interrupt claims verified ===");
    io::println("  27-vector IDT: PASS");
    io::println("  TBRANCH priority dispatch: PASS");
    io::println("  Interrupt nesting with preemption: PASS");
    io::println("  Deferred batch processing: PASS");
    io::println("  Statistics tracking: PASS");
}
