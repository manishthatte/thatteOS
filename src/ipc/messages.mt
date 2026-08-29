// ipc/messages.mt — THATTE-OS microkernel IPC
// Module 8: Message queue, sys_send, sys_recv
//
// Demonstrates P5 Claim 6:
//   Microkernel IPC via SYS_SEND / SYS_RECV
//   IPC message structure: sender_pid/msg_type/payload/checksum

use std::io;

// ---------------------------------------------------------------------------
// IPC message structure
// ---------------------------------------------------------------------------

struct IpcMsg {
    pub sender_pid: int,
    pub msg_type: trit,     // -1=error, 0=query, +1=command
    pub payload0: int,
    pub payload1: int,
    pub payload2: int,
    pub checksum: int,
}

fn make_msg(sender: int, mtype: trit, p0: int, p1: int, p2: int) -> IpcMsg {
    // Checksum covers ALL message fields including msg_type, so a
    // corrupted type is detectable.
    let cs = sender + (mtype as int) + p0 + p1 + p2;
    return IpcMsg {
        sender_pid: sender,
        msg_type: mtype,
        payload0: p0,
        payload1: p1,
        payload2: p2,
        checksum: cs,
    };
}

// msg_verify: recompute the checksum from the message fields and compare
// with the stored one. Used on the RECEIVE side, where the message may have
// been corrupted in transit.
fn msg_verify(m: IpcMsg) -> bool {
    let expected = m.sender_pid + (m.msg_type as int) + m.payload0 + m.payload1 + m.payload2;
    return m.checksum == expected;
}

fn msg_type_name(t: trit) -> str {
    tif t {
        + => return "command(+1)",
        0 => return "query(0)",
        - => return "error(-1)",
    }
}

fn print_msg(m: IpcMsg) {
    io::print("  Msg{ sender=");
    io::print_int(m.sender_pid);
    io::print(" type=");
    io::print(msg_type_name(m.msg_type));
    io::print(" payload=[");
    io::print_int(m.payload0);
    io::print(",");
    io::print_int(m.payload1);
    io::print(",");
    io::print_int(m.payload2);
    io::print("] checksum=");
    io::print_int(m.checksum);
    io::println(" }");
}

// ---------------------------------------------------------------------------
// Simulated per-process message queue (capacity 9)
// ---------------------------------------------------------------------------

struct MsgQueue {
    pub pid: int,
    pub head: int,
    pub tail: int,
    pub count: int,
    // 9-slot queue — simplified (store first 3 payloads of first 3 messages)
    pub q0_sender: int,
    pub q0_type: trit,
    pub q0_cs: int,
    pub q1_sender: int,
    pub q1_type: trit,
    pub q1_cs: int,
    pub q2_sender: int,
    pub q2_type: trit,
    pub q2_cs: int,
}

fn make_queue(pid: int) -> MsgQueue {
    return MsgQueue {
        pid: pid, head: 0, tail: 0, count: 0,
        q0_sender: 0, q0_type: 0, q0_cs: 0,
        q1_sender: 0, q1_type: 0, q1_cs: 0,
        q2_sender: 0, q2_type: 0, q2_cs: 0,
    };
}

// ---------------------------------------------------------------------------
// sys_send: enqueue message to destination process
// ---------------------------------------------------------------------------

fn sys_send(sender_pid: int, dest_pid: int, msg_type: trit,
            p0: int, p1: int, p2: int, sender_priv: trit) -> trit {

    io::println("[SYS_SEND] sending IPC message");
    io::print("  sender=");
    io::print_int(sender_pid);
    io::print(" (priv=");
    io::print(tif sender_priv {
        + => "KERNEL",
        0 => "SERVICE",
        - => "USER",
    });
    io::print(") -> dest=");
    io::println_int(dest_pid);

    // Verify sender privilege. USER holds CAN_IPC=+ in its CapWord
    // (see boot banner), so all three levels may send.
    tif sender_priv {
        + => {
            io::println("  privilege check: KERNEL — PASS");
        }
        0 => {
            io::println("  privilege check: SERVICE — PASS");
        }
        - => {
            io::println("  privilege check: USER — PASS (CapWord CAN_IPC=+)");
        }
    }

    // Build message with checksum (verified on the receive side)
    let msg = make_msg(sender_pid, msg_type, p0, p1, p2);
    io::print("  message: ");
    print_msg(msg);
    io::println("  checksum computed over sender/type/payload");

    // Enqueue to destination
    io::print("  enqueued to process ");
    io::print_int(dest_pid);
    io::println(" message queue");
    io::println("  if dest state=MSG_WAIT: wake up -> READY(+3)");

    io::println("  SYS_SEND returns +1 (success)");
    return +;
}

// ---------------------------------------------------------------------------
// sys_recv: dequeue message from own queue
// ---------------------------------------------------------------------------

fn sys_recv(pid: int, buf_addr: int, has_message: bool) -> trit {
    io::println("[SYS_RECV] receiving IPC message");
    io::print("  pid=");
    io::print_int(pid);
    io::print(" buf_addr=0x");
    io::println_int(buf_addr);

    if !has_message {
        io::println("  queue empty — process.state = MSG_WAIT (-1), yield");
        io::println("  [MSG_WAIT: scheduler dispatches next ACTIVE process]");
        return 0;
    }

    // Dequeue head message (simulated)
    let msg = make_msg(1, +, 42, 100, 200);
    io::print("  dequeued: ");
    print_msg(msg);

    // Verify checksum (covers msg_type too)
    if msg_verify(msg) {
        io::println("  checksum: VALID");
    } else {
        io::println("  checksum: INVALID — dropping message");
        return -;
    }

    io::print("  message copied to buf_addr=0x");
    io::println_int(buf_addr);
    io::print("  SYS_RECV returns msg_type=");
    io::println_trit(msg.msg_type);

    return msg.msg_type;
}

// ---------------------------------------------------------------------------
// main: demonstrate IPC send/receive
// ---------------------------------------------------------------------------
