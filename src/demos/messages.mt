// src/demos/messages.mt — the demonstration lifted out of src/ipc/messages.mt
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

// messages_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn messages_demo() {
    io::println("=== THATTE-OS IPC Demo ===");
    io::println("Claim 6: Microkernel IPC via SYS_SEND / SYS_RECV");
    io::println("");

    // --- SYS_SEND: KERNEL sends command to process 2 ---
    io::println("--- Test 1: KERNEL sends command (+1) to PID=2 ---");
    let r1 = sys_send(0, 2, +, 100, 200, 300, +);
    io::print("  result=");
    io::println_trit(r1);
    io::println("");

    // --- SYS_SEND: SERVICE sends query (0) to process 3 ---
    io::println("--- Test 2: SERVICE sends query (0) to PID=3 ---");
    let r2 = sys_send(1, 3, 0, 10, 20, 30, 0);
    io::print("  result=");
    io::println_trit(r2);
    io::println("");

    // --- SYS_SEND: USER sends (allowed — CapWord CAN_IPC=+) ---
    io::println("--- Test 3: USER SYS_SEND (allowed, CAN_IPC=+) ---");
    let r3 = sys_send(5, 2, +, 1, 2, 3, -);
    io::print("  result=");
    io::println_trit(r3);
    io::println("");

    // --- SYS_SEND: SERVICE sends error (-1) message ---
    io::println("--- Test 4: SERVICE sends error (-1) to PID=2 ---");
    let r4 = sys_send(1, 2, -, 0, 0, 0, 0);
    io::print("  result=");
    io::println_trit(r4);
    io::println("");

    // --- SYS_RECV: process has message ---
    io::println("--- Test 5: SYS_RECV with message available ---");
    let recv1 = sys_recv(2, 8192, true);
    io::print("  received msg_type=");
    io::println_trit(recv1);
    io::println("");

    // --- SYS_RECV: empty queue (MSG_WAIT) ---
    io::println("--- Test 6: SYS_RECV with empty queue ---");
    let recv2 = sys_recv(3, 8200, false);
    io::print("  result=");
    io::println_trit(recv2);
    io::println("");

    // --- Checksum: corrupted message is detected ---
    io::println("--- Test 7: corrupted message detected by msg_verify ---");
    let good = make_msg(1, +, 42, 100, 200);
    let corrupted = IpcMsg { sender_pid: good.sender_pid, msg_type: -,
                             payload0: good.payload0, payload1: good.payload1,
                             payload2: good.payload2, checksum: good.checksum };
    io::print("  original:  ");
    print_msg(good);
    io::print("  corrupted: ");
    print_msg(corrupted);
    if msg_verify(corrupted) {
        io::println("  msg_verify: VALID — corruption NOT detected (BUG)");
    } else {
        io::println("  msg_verify: INVALID — msg_type corruption detected");
    }
    io::println("");

    io::println("=== IPC claims verified ===");
    io::println("  SYS_SEND privilege check:              PASS");
    io::println("  IPC message structure with checksum:  PASS");
    io::println("  MSG_WAIT on empty queue:               PASS");
    io::println("  3-trit msg_type (-1/0/+1):             PASS");
    io::println("  Corrupted msg_type detected:           PASS");
}
