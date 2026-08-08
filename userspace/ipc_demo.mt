// userspace/ipc_demo.mt — THATTEOS IPC message passing demo
//
// Simulates the THATTEOS signed-integer IPC protocol:
//   positive message IDs  = resource requests
//   zero message ID       = heartbeat / null op
//   negative message IDs  = error notifications
//
// Demonstrates a "producer / consumer" exchange where the producer
// sends a sequence of signed messages and the consumer dispatches
// on sign(msg_id) using TBRANCH semantics.
//
// Author: Manish Jagdish Thatte

use std::io;

fn msg_type(id: int) -> str {
    if id > 0  { return "REQUEST "; }
    elif id == 0 { return "HEARTBT "; }
    else       { return "ERROR   "; }
}

fn msg_name(id: int) -> str {
    if id == -4 { return "MSG_FATAL   : fatal error, terminate sender"; }
    elif id == -3 { return "MSG_ERR     : recoverable error"; }
    elif id == -2 { return "MSG_TIMEOUT : operation timed out"; }
    elif id == -1 { return "MSG_DENIED  : permission denied"; }
    elif id == 0  { return "MSG_HEARTBT : null / keep-alive"; }
    elif id == 1  { return "MSG_ALLOC   : request memory allocation"; }
    elif id == 2  { return "MSG_OPEN    : request file open"; }
    elif id == 3  { return "MSG_READ    : request data read"; }
    elif id == 4  { return "MSG_WRITE   : request data write"; }
    else {
        if id > 4  { return "MSG_USER+   : user-defined positive"; }
        else       { return "MSG_USER-   : user-defined negative"; }
    }
}

fn dispatch_msg(id: int, payload: int) {
    io::print("  [");
    io::print(msg_type(id));
    io::print("id=");
    io::print_int(id);
    io::print("] ");
    io::print(msg_name(id));
    io::print("  payload=");
    io::print_int(payload);
    io::println("");
    // TBRANCH on sign(id):
    if id > 0 {
        io::println("    TBRANCH(+): positive path → service layer handles");
    } elif id == 0 {
        io::println("    TBRANCH(0): zero path     → kernel acknowledges");
    } else {
        io::println("    TBRANCH(-): negative path → error handler invoked");
    }
}

fn main() {
    io::println("=== THATTEOS ipc_demo — signed-integer message passing ===");
    io::println("");
    io::println("  Protocol: sign(msg_id) determines dispatch path");
    io::println("    (+) positive IDs → resource requests → service layer");
    io::println("    ( 0) zero ID     → heartbeat / null  → kernel");
    io::println("    (-) negative IDs → error events      → error handler");
    io::println("");

    // Simulate producer sending 9 messages (balanced: -4 to +4)
    io::println("  --- Producer → Consumer (9 messages) ---");
    io::println("");

    let mut seq = -4;
    while seq <= 4 {
        dispatch_msg(seq, seq * seq);  // payload = id^2
        io::println("");
        seq = seq + 1;
    }

    io::println("  --- Message queue statistics ---");
    io::println("  positive messages (requests):   5  (IDs +1..+4 + future)");
    io::println("  zero messages    (heartbeats):  1  (ID 0)");
    io::println("  negative messages (errors):     4  (IDs -1..-4)");
    io::println("");
    io::println("  THATTEOS IPC guarantees:");
    io::println("  • message IDs are signed integers — sign encodes semantics");
    io::println("  • TBRANCH on sign(id) gives O(1) three-way dispatch");
    io::println("  • negative IDs never confused with positive requests");
    io::println("  • zero ID is a valid distinct operation (probe/heartbeat)");
    io::println("");
    io::println("=== ipc_demo complete ===");
}
