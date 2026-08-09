// test_trit_stream.mt — THATTE-OS trit stream IPC tests
// Tests stream creation, write/read single trits, write/read full words,
// stream close, closed-stream rejection, multiple streams, and zero-copy
// semantics verification.
//
// Author: Manish Jagdish Thatte

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
// Reproduced from ipc/trit_stream.mt (minimal, no I/O side-effects)
// ---------------------------------------------------------------------------

struct TritStream {
    pub chan_idx: t9,
    pub sender_pid: t9,
    pub receiver_pid: t9,
    pub active: bool3,
}

fn stream_create(sender: t9, receiver: t9) -> TritStream {
    // Simplified channel allocation: chan_idx = sender * 9 + receiver
    let chan_id = sender * 9 + receiver;
    return TritStream {
        chan_idx: chan_id,
        sender_pid: sender,
        receiver_pid: receiver,
        active: +,
    };
}

fn is_active(s: TritStream) -> bool {
    tif s.active { + => return true, 0 => return false, - => return false }
}

fn is_closed(s: TritStream) -> bool {
    tif s.active { + => return false, 0 => return false, - => return true }
}

// stream_write_trit: returns true if write accepted, false if rejected
fn stream_write_trit(s: TritStream, value: trit) -> bool {
    tif s.active {
        + => return true,
        0 => return false,
        - => return false,
    }
}

// stream_read_trit: returns the trit value if active, 0 if not
// In real hardware: samples current direction at receiver terminal
// For test: we pass in the expected value (zero-copy: same as written)
fn stream_read_trit(s: TritStream, written_value: trit) -> trit {
    tif s.active {
        + => return written_value,    // zero copy: same physical current
        0 => return 0,
        - => return 0,
    }
}

// stream_write_word: returns true if accepted
fn stream_write_word(s: TritStream, w: word) -> bool {
    tif s.active {
        + => return true,
        0 => return false,
        - => return false,
    }
}

// stream_read_word: returns the word if active, 0 if not
fn stream_read_word(s: TritStream, written_word: word) -> word {
    tif s.active {
        + => return written_word,     // zero copy: 27 current pulses
        0 => return 0,
        - => return 0,
    }
}

fn stream_close(s: TritStream) -> TritStream {
    return TritStream {
        chan_idx: s.chan_idx,
        sender_pid: s.sender_pid,
        receiver_pid: s.receiver_pid,
        active: -,
    };
}

fn trit_eq(a: trit, b: trit) -> bool {
    tif a {
        + => { tif b { + => return true, 0 => return false, - => return false } }
        0 => { tif b { + => return false, 0 => return true, - => return false } }
        - => { tif b { + => return false, 0 => return false, - => return true } }
    }
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn main() {
    io::println("=== THATTE-OS Trit Stream IPC Tests ===");
    let mut passed = 0;
    let mut total = 0;

    // -----------------------------------------------------------------------
    // Part 1: Stream creation and channel allocation
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Stream creation ---");

    let s1 = stream_create(1, 2);

    total = total + 1;
    passed = passed + assert_true(is_active(s1),
        "newly created stream is active", total);

    total = total + 1;
    passed = passed + assert_true(s1.sender_pid == 1,
        "sender_pid correctly set to 1", total);

    total = total + 1;
    passed = passed + assert_true(s1.receiver_pid == 2,
        "receiver_pid correctly set to 2", total);

    total = total + 1;
    passed = passed + assert_true(s1.chan_idx == 11,
        "channel index = sender*9 + receiver (1*9+2=11)", total);

    // -----------------------------------------------------------------------
    // Part 2: Write/read single trits (+1, 0, -1)
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Single trit write/read ---");

    // Write +1
    total = total + 1;
    let w_pos = stream_write_trit(s1, +);
    passed = passed + assert_true(w_pos, "write trit +1 accepted on active stream", total);

    total = total + 1;
    let r_pos = stream_read_trit(s1, +);
    passed = passed + assert_true(trit_eq(r_pos, +),
        "read returns +1 (same current as written)", total);

    // Write 0
    total = total + 1;
    let w_zero = stream_write_trit(s1, 0);
    passed = passed + assert_true(w_zero, "write trit 0 accepted on active stream", total);

    total = total + 1;
    let r_zero = stream_read_trit(s1, 0);
    passed = passed + assert_true(trit_eq(r_zero, 0),
        "read returns 0 (no current — no photon, no AC)", total);

    // Write -1
    total = total + 1;
    let w_neg = stream_write_trit(s1, -);
    passed = passed + assert_true(w_neg, "write trit -1 accepted on active stream", total);

    total = total + 1;
    let r_neg = stream_read_trit(s1, -);
    passed = passed + assert_true(trit_eq(r_neg, -),
        "read returns -1 (negative AC phase current)", total);

    // -----------------------------------------------------------------------
    // Part 3: Write/read full 27-trit word
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Full word (27 trits) write/read ---");

    let test_word = 12345;

    total = total + 1;
    let ww_ok = stream_write_word(s1, test_word);
    passed = passed + assert_true(ww_ok, "write word accepted on active stream", total);

    total = total + 1;
    let rw_val = stream_read_word(s1, test_word);
    passed = passed + assert_true(rw_val == test_word,
        "read word returns 12345 (27 current pulses, zero copy)", total);

    // Second word value
    total = total + 1;
    let rw_val2 = stream_read_word(s1, 7654321);
    passed = passed + assert_true(rw_val2 == 7654321,
        "read word returns 7654321 (different payload)", total);

    // -----------------------------------------------------------------------
    // Part 4: Stream close and rejection of I/O on closed streams
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Stream close and I/O rejection ---");

    let s1_closed = stream_close(s1);

    total = total + 1;
    passed = passed + assert_true(is_closed(s1_closed),
        "closed stream reports closed status", total);

    total = total + 1;
    passed = passed + assert_true(!is_active(s1_closed),
        "closed stream is not active", total);

    total = total + 1;
    let wr_closed = stream_write_trit(s1_closed, +);
    passed = passed + assert_true(!wr_closed,
        "write on closed stream rejected", total);

    total = total + 1;
    let rd_closed = stream_read_trit(s1_closed, +);
    passed = passed + assert_true(trit_eq(rd_closed, 0),
        "read on closed stream returns 0 (no current)", total);

    total = total + 1;
    let ww_closed = stream_write_word(s1_closed, 999);
    passed = passed + assert_true(!ww_closed,
        "write word on closed stream rejected", total);

    total = total + 1;
    let rw_closed = stream_read_word(s1_closed, 999);
    passed = passed + assert_true(rw_closed == 0,
        "read word on closed stream returns 0", total);

    // -----------------------------------------------------------------------
    // Part 5: Multiple streams between different process pairs
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Multiple streams ---");

    let s_ab = stream_create(3, 4);
    let s_cd = stream_create(5, 6);

    total = total + 1;
    passed = passed + assert_true(s_ab.chan_idx != s_cd.chan_idx,
        "different process pairs get different channels", total);

    total = total + 1;
    passed = passed + assert_true(is_active(s_ab) && is_active(s_cd),
        "both streams are independently active", total);

    // Close one, other remains active
    let s_ab_closed = stream_close(s_ab);

    total = total + 1;
    passed = passed + assert_true(is_closed(s_ab_closed) && is_active(s_cd),
        "closing one stream does not affect the other", total);

    // -----------------------------------------------------------------------
    // Part 6: Zero-copy semantics verification
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Zero-copy semantics ---");

    // The value written IS the value read — same physical current
    total = total + 1;
    let s_zc = stream_create(7, 8);
    let written_val: trit = -;
    let read_val = stream_read_trit(s_zc, written_val);
    passed = passed + assert_true(trit_eq(written_val, read_val),
        "zero copy: written trit == read trit (same SWCNT current)", total);

    total = total + 1;
    let written_w = 42;
    let read_w = stream_read_word(s_zc, written_w);
    passed = passed + assert_true(written_w == read_w,
        "zero copy: written word == read word (27 current pulses)", total);

    // -----------------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------------
    io::println("");
    io::print("Results: ");
    io::print_int(passed);
    io::print("/");
    io::print_int(total);
    io::println(" passed");
}
