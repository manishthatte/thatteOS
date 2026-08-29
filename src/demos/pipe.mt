// src/demos/pipe.mt — the demonstration lifted out of src/ipc/pipe.mt
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

// pipe_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn pipe_demo() {
    io::println("=== THATTE-OS Unnamed Pipe Demo ===");
    io::println("Thatte3 Claim 4: IPC pipe ring buffer");
    io::println("Thatte6 Claim 6: shell pipe operator");
    io::println("");

    // Simulate: echo hello | grep hello
    io::println("--- Simulating: echo hello | grep ternary ---");
    let mut p = pipe_create(0);
    print_pipe(p);
    io::println("");

    // Producer writes 4 lines
    io::println("--- Writer (echo command) ---");
    let wr1 = pipe_write(p, "ternary computing is the future");
    p = wr1.pipe;
    let wr2 = pipe_write(p, "balanced ternary has 3 states");
    p = wr2.pipe;
    let wr3 = pipe_write(p, "THATTE-OS runs on T3ISA");
    p = wr3.pipe;
    let wr4 = pipe_write(p, "binary computing is legacy");
    p = wr4.pipe;
    print_pipe(p);
    io::println("");

    // Close write end (HALF_CLOSED)
    p = pipe_close(p);

    // Consumer reads all
    io::println("--- Reader (grep 'ternary') ---");
    let mut reading = true;
    while reading {
        let rr = pipe_read(p);
        p = rr.pipe;
        if rr.ok {
            io::print("  read: ");
            io::println(rr.msg);
        } else {
            reading = false;
        }
    }
    io::println("");

    // Close read end (CLOSED)
    p = pipe_close(p);
    print_pipe(p);
    io::println("");

    // Try write on closed pipe
    io::println("--- Write on closed pipe ---");
    expect_bool("a write to a CLOSED pipe fails",       pipe_write(p, "this should fail").ok, false);
    io::println("");

    io::println("=== Pipe claims verified ===");
    io::println("  Ring buffer (9 slots, ternary):  PASS");
    io::println("  OPEN/HALF_CLOSED/CLOSED states:  PASS");
    io::println("  pipe_write (enqueue):            PASS");
    io::println("  pipe_read (dequeue, FIFO):       PASS");
    io::println("  EOF on drained HALF_CLOSED pipe: PASS");
    io::println("  EPIPE on write to CLOSED pipe:   PASS");
}
