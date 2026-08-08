// test_ipc.mt — THATTE-OS IPC subsystem tests
// Verifies message types, send/recv, privilege enforcement,
// checksum validation, and queue operations.

use std::io;

// ---------------------------------------------------------------------------
// Test helper
// ---------------------------------------------------------------------------

fn assert_true(cond: bool, name: str, test_num: int) -> int {
    io::print("  test ");
    io::print_int(test_num);
    io::print(": ");
    io::print(name);
    if cond {
        io::println(" — PASS");
        return 1;
    } else {
        io::println(" — FAIL");
        return 0;
    }
}

// ---------------------------------------------------------------------------
// Minimal reproduction of IPC types and functions
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
    let cs = sender + p0 + p1 + p2;
    return IpcMsg {
        sender_pid: sender,
        msg_type: mtype,
        payload0: p0,
        payload1: p1,
        payload2: p2,
        checksum: cs,
    };
}

fn verify_checksum(m: IpcMsg) -> bool {
    let expected = m.sender_pid + m.payload0 + m.payload1 + m.payload2;
    return m.checksum == expected;
}

struct MsgQueue {
    pub pid: int,
    pub count: int,
    pub q0_sender: int,
    pub q0_type: trit,
    pub q1_sender: int,
    pub q1_type: trit,
    pub q2_sender: int,
    pub q2_type: trit,
}

fn make_queue(pid: int) -> MsgQueue {
    return MsgQueue {
        pid: pid, count: 0,
        q0_sender: 0, q0_type: 0,
        q1_sender: 0, q1_type: 0,
        q2_sender: 0, q2_type: 0,
    };
}

fn queue_is_empty(q: MsgQueue) -> bool {
    return q.count == 0;
}

fn enqueue(q: MsgQueue, sender: int, mtype: trit) -> MsgQueue {
    if q.count >= 3 { return q; }
    if q.count == 0 {
        return MsgQueue { pid: q.pid, count: 1,
            q0_sender: sender, q0_type: mtype,
            q1_sender: q.q1_sender, q1_type: q.q1_type,
            q2_sender: q.q2_sender, q2_type: q.q2_type };
    } elif q.count == 1 {
        return MsgQueue { pid: q.pid, count: 2,
            q0_sender: q.q0_sender, q0_type: q.q0_type,
            q1_sender: sender, q1_type: mtype,
            q2_sender: q.q2_sender, q2_type: q.q2_type };
    } else {
        return MsgQueue { pid: q.pid, count: 3,
            q0_sender: q.q0_sender, q0_type: q.q0_type,
            q1_sender: q.q1_sender, q1_type: q.q1_type,
            q2_sender: sender, q2_type: mtype };
    }
}

// sys_send: returns trit (+1=success, -1=error)
fn sys_send(sender_pid: int, dest_pid: int, msg_type: trit,
            p0: int, p1: int, p2: int, sender_priv: trit) -> trit {
    // Privilege check: require SERVICE(0) or KERNEL(+1)
    tif sender_priv {
        + => { }
        0 => { }
        - => { return -; }
    }

    // Build and verify checksum
    let msg = make_msg(sender_pid, msg_type, p0, p1, p2);
    if !verify_checksum(msg) {
        return -;
    }

    return +;
}

// sys_recv: returns trit (msg_type if available, 0 if empty = MSG_WAIT)
fn sys_recv(pid: int, has_message: bool) -> trit {
    if !has_message {
        return 0;  // MSG_WAIT
    }
    return +;  // simulated: got a command message
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn main() {
    io::println("=== THATTE-OS IPC Tests ===");
    let mut passed = 0;
    let mut total = 0;

    // --- Test 1: Send command message (+1) ---
    total = total + 1;
    let r1 = sys_send(0, 2, +, 100, 200, 300, +);
    let r1_ok: bool = tif r1 { + => true, 0 => false, - => false };
    passed = passed + assert_true(r1_ok, "send command(+1) from KERNEL succeeds", total);

    // --- Test 2: Send query message (0) ---
    total = total + 1;
    let r2 = sys_send(1, 3, 0, 10, 20, 30, 0);
    let r2_ok: bool = tif r2 { + => true, 0 => false, - => false };
    passed = passed + assert_true(r2_ok, "send query(0) from SERVICE succeeds", total);

    // --- Test 3: Send error message (-1) ---
    total = total + 1;
    let r3 = sys_send(1, 2, -, 0, 0, 0, 0);
    let r3_ok: bool = tif r3 { + => true, 0 => false, - => false };
    passed = passed + assert_true(r3_ok, "send error(-1) from SERVICE succeeds", total);

    // --- Test 4: Receive with message available ---
    total = total + 1;
    let recv1 = sys_recv(2, true);
    let recv1_ok: bool = tif recv1 { + => true, 0 => false, - => false };
    passed = passed + assert_true(recv1_ok, "recv with message returns msg_type", total);

    // --- Test 5: Receive with empty queue (MSG_WAIT) ---
    total = total + 1;
    let recv2 = sys_recv(3, false);
    let recv2_wait: bool = tif recv2 { + => false, 0 => true, - => false };
    passed = passed + assert_true(recv2_wait, "recv empty queue returns 0 (MSG_WAIT)", total);

    // --- Test 6: Privilege — KERNEL allowed ---
    total = total + 1;
    let priv_k = sys_send(0, 1, +, 1, 2, 3, +);
    let priv_k_ok: bool = tif priv_k { + => true, 0 => false, - => false };
    passed = passed + assert_true(priv_k_ok, "KERNEL privilege allowed for IPC", total);

    // --- Test 7: Privilege — SERVICE allowed ---
    total = total + 1;
    let priv_s = sys_send(1, 2, +, 1, 2, 3, 0);
    let priv_s_ok: bool = tif priv_s { + => true, 0 => false, - => false };
    passed = passed + assert_true(priv_s_ok, "SERVICE privilege allowed for IPC", total);

    // --- Test 8: Privilege — USER denied ---
    total = total + 1;
    let priv_u = sys_send(5, 2, +, 1, 2, 3, -);
    let priv_u_denied: bool = tif priv_u { + => false, 0 => false, - => true };
    passed = passed + assert_true(priv_u_denied, "USER privilege denied for IPC", total);

    // --- Test 9: Checksum valid ---
    total = total + 1;
    let msg_valid = make_msg(1, +, 42, 100, 200);
    let cs_ok = verify_checksum(msg_valid);
    passed = passed + assert_true(cs_ok, "valid message checksum verified", total);

    // --- Test 10: Checksum invalid (tampered) ---
    total = total + 1;
    let msg_bad = IpcMsg {
        sender_pid: 1,
        msg_type: +,
        payload0: 42,
        payload1: 100,
        payload2: 200,
        checksum: 999,
    };
    let cs_bad = verify_checksum(msg_bad);
    passed = passed + assert_true(!cs_bad, "tampered checksum detected", total);

    // --- Test 11: Queue init is empty ---
    total = total + 1;
    let q = make_queue(2);
    passed = passed + assert_true(queue_is_empty(q), "new queue is empty", total);

    // --- Test 12: Enqueue one message ---
    total = total + 1;
    let q1 = enqueue(q, 1, +);
    passed = passed + assert_true(!queue_is_empty(q1), "queue non-empty after enqueue", total);

    // --- Test 13: Enqueue count increments ---
    total = total + 1;
    passed = passed + assert_true(q1.count == 1, "queue count is 1 after one enqueue", total);

    // --- Test 14: Enqueue fills to capacity ---
    total = total + 1;
    let q2 = enqueue(q1, 2, 0);
    let q3 = enqueue(q2, 3, -);
    passed = passed + assert_true(q3.count == 3, "queue fills to capacity 3", total);

    // --- Test 15: Enqueue beyond capacity does not overflow ---
    total = total + 1;
    let q4 = enqueue(q3, 4, +);
    passed = passed + assert_true(q4.count == 3, "enqueue beyond capacity stays at 3", total);

    // --- Test 16: Message type preserved in queue slot ---
    total = total + 1;
    let slot_ok: bool = tif q1.q0_type { + => true, 0 => false, - => false };
    passed = passed + assert_true(slot_ok, "enqueued message type (+1) preserved", total);

    // --- Test 17: Sender PID preserved in queue slot ---
    total = total + 1;
    passed = passed + assert_true(q1.q0_sender == 1, "enqueued sender_pid preserved", total);

    // --- Test 18: Message construction preserves all fields ---
    total = total + 1;
    let m = make_msg(7, -, 10, 20, 30);
    let fields_ok = m.sender_pid == 7 && m.payload0 == 10
                    && m.payload1 == 20 && m.payload2 == 30;
    passed = passed + assert_true(fields_ok, "make_msg preserves all payload fields", total);

    // --- Test 19: Checksum formula is sender+p0+p1+p2 ---
    total = total + 1;
    let expected_cs = 7 + 10 + 20 + 30;
    passed = passed + assert_true(m.checksum == expected_cs, "checksum = sender+p0+p1+p2", total);

    // --- Test 20: Queue PID matches init PID ---
    total = total + 1;
    passed = passed + assert_true(q.pid == 2, "queue pid matches init value", total);

    // --- Results ---
    io::println("");
    io::print("Results: ");
    io::print_int(passed);
    io::print("/");
    io::print_int(total);
    io::println(" passed");
}
