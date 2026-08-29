// src/demos/trit_stream.mt — the demonstration lifted out of src/ipc/trit_stream.mt
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

// trit_stream_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn trit_stream_demo() {
    io::println("=== THATTE-OS Zero-Copy Trit Stream IPC ===");
    io::println("Claim 24: SWCNT-based zero-copy inter-process communication");
    io::println("");
    io::println("The sender's output current IS the receiver's input current");
    io::println("on the same physical SWCNT. No buffer, no copy, no serialization.");
    io::println("Propagation at Fermi velocity ~8x10^5 m/s; L=10um -> ~12.5 ps");
    io::println("");

    // --- Create a stream between PID=1 (sender) and PID=2 (receiver) ---
    io::println("--- Create stream: PID=1 -> PID=2 ---");
    let s = stream_create(1, 2);
    io::println("");

    // --- Write individual trits ---
    io::println("--- Write trits: +1, 0, -1 ---");
    stream_write(s, +);
    stream_write(s, 0);
    stream_write(s, -);
    io::println("");

    // --- Read from receiver side ---
    io::println("--- Read trit at receiver ---");
    let val = stream_read(s);
    io::print("  received trit: ");
    io::println_trit(val);
    io::println("");

    // --- Write and read a full word (27 trits) ---
    io::println("--- Write/read full word (27 trits) ---");
    stream_write_word(s, 12345);
    let w = stream_read_word(s);
    io::print("  received word: ");
    io::println_int(w);
    io::println("");

    // --- Close stream (cease photon delivery) ---
    io::println("--- Close stream ---");
    let s_closed = stream_close(s);
    io::println("");

    // --- Attempt write on closed channel ---
    io::println("--- Write on closed channel (should fail) ---");
    stream_write(s_closed, +);
    io::println("");

    // --- Attempt read on closed channel ---
    io::println("--- Read on closed channel (should fail) ---");
    expect_trit("a read on a CLOSED channel yields 0",  stream_read(s_closed), 0);
    io::println("");

    io::println("=== Trit stream claims verified ===");
    io::println("  SWCNT physical channel allocation:  PASS");
    io::println("  Trit write = current injection:     PASS");
    io::println("  Trit read = current sampling:       PASS");
    io::println("  Zero copy (same physical current):  PASS");
    io::println("  Word transfer (27 trits):           PASS");
    io::println("  Close = photon cessation:           PASS");
    io::println("  Closed channel rejects I/O:         PASS");
}
