// ipc/pipe.mt — THATTE-OS unnamed pipe
// Module: Byte-stream IPC via ring buffer
//
// Demonstrates Thatte3/Thatte6 Claims:
//   Claim 4  — IPC pipe as in-kernel ring buffer
//   Claim 6  — Shell pipe operator (cmd1 | cmd2)
//
// A pipe is a fixed-size ring buffer of 9 string slots (ternary-sized).
// pipe_write appends a message; pipe_read consumes the oldest message.
// State trit: +1=OPEN, 0=HALF_CLOSED, -1=CLOSED
//
// Used by the shell '|' operator to chain command output to input.

use std::io;

// ---------------------------------------------------------------------------
// Pipe state constants
// ---------------------------------------------------------------------------

fn PIPE_OPEN() -> trit { return +; }
fn PIPE_HALF_CLOSED() -> trit { return 0; }
fn PIPE_CLOSED() -> trit { return -; }
fn PIPE_CAPACITY() -> int { return 9; }

fn pipe_state_name(s: trit) -> str {
    tif s {
        + => return "OPEN(+1)",
        0 => return "HALF_CLOSED(0)",
        - => return "CLOSED(-1)",
    }
}

// ---------------------------------------------------------------------------
// Pipe ring buffer (9 string slots)
// ---------------------------------------------------------------------------

struct Pipe {
    pub id: int,
    pub state: trit,
    pub head: int,   // next read position
    pub tail: int,   // next write position
    pub count: int,  // items currently in buffer
    pub s0: str, pub s1: str, pub s2: str,
    pub s3: str, pub s4: str, pub s5: str,
    pub s6: str, pub s7: str, pub s8: str,
}

fn pipe_empty_slots() -> Pipe {
    return Pipe { id: 0, state: PIPE_CLOSED(),
        head: 0, tail: 0, count: 0,
        s0: "", s1: "", s2: "",
        s3: "", s4: "", s5: "",
        s6: "", s7: "", s8: "" };
}

// ---------------------------------------------------------------------------
// pipe_create: open a new pipe
// ---------------------------------------------------------------------------

fn pipe_create(id: int) -> Pipe {
    io::print("[PIPE] pipe_create: id=");
    io::println_int(id);
    return Pipe { id: id, state: PIPE_OPEN(),
        head: 0, tail: 0, count: 0,
        s0: "", s1: "", s2: "",
        s3: "", s4: "", s5: "",
        s6: "", s7: "", s8: "" };
}

// ---------------------------------------------------------------------------
// WriteResult: pipe after write + success flag
// ---------------------------------------------------------------------------

struct WriteResult {
    pub ok: bool,
    pub pipe: Pipe,
}

fn write_failed(p: Pipe) -> WriteResult {
    return WriteResult { ok: false, pipe: p };
}

// Helper: set slot[idx % 9] = msg, return updated pipe.
fn pipe_set_slot(p: Pipe, idx: int, msg: str) -> Pipe {
    let slot = idx - (idx / 9) * 9;  // idx % 9
    return Pipe { id: p.id, state: p.state, head: p.head, tail: p.tail, count: p.count,
        s0: if slot == 0 { msg } else { p.s0 },
        s1: if slot == 1 { msg } else { p.s1 },
        s2: if slot == 2 { msg } else { p.s2 },
        s3: if slot == 3 { msg } else { p.s3 },
        s4: if slot == 4 { msg } else { p.s4 },
        s5: if slot == 5 { msg } else { p.s5 },
        s6: if slot == 6 { msg } else { p.s6 },
        s7: if slot == 7 { msg } else { p.s7 },
        s8: if slot == 8 { msg } else { p.s8 } };
}

// Helper: get slot[idx % 9].
fn pipe_get_slot(p: Pipe, idx: int) -> str {
    let slot = idx - (idx / 9) * 9;
    if slot == 0 { return p.s0; }
    elif slot == 1 { return p.s1; }
    elif slot == 2 { return p.s2; }
    elif slot == 3 { return p.s3; }
    elif slot == 4 { return p.s4; }
    elif slot == 5 { return p.s5; }
    elif slot == 6 { return p.s6; }
    elif slot == 7 { return p.s7; }
    else { return p.s8; }
}

// ---------------------------------------------------------------------------
// pipe_write: enqueue a message string
// ---------------------------------------------------------------------------

fn pipe_write(p: Pipe, msg: str) -> WriteResult {
    if p.state == PIPE_CLOSED() {
        io::println("[PIPE] write: pipe is CLOSED — EPIPE");
        return write_failed(p);
    }
    if p.state == PIPE_HALF_CLOSED() {
        io::println("[PIPE] write: write end closed — EPIPE");
        return write_failed(p);
    }
    if p.count >= PIPE_CAPACITY() {
        io::println("[PIPE] write: buffer full — EWOULDBLOCK");
        return write_failed(p);
    }
    let new_tail = p.tail + 1;
    let next_tail = new_tail - (new_tail / 9) * 9;  // new_tail % 9
    let updated = pipe_set_slot(p, p.tail, msg);
    let final_pipe = Pipe { id: updated.id, state: updated.state,
        head: updated.head, tail: next_tail, count: updated.count + 1,
        s0: updated.s0, s1: updated.s1, s2: updated.s2,
        s3: updated.s3, s4: updated.s4, s5: updated.s5,
        s6: updated.s6, s7: updated.s7, s8: updated.s8 };
    return WriteResult { ok: true, pipe: final_pipe };
}

// ---------------------------------------------------------------------------
// ReadResult: consumed message + updated pipe
// ---------------------------------------------------------------------------

struct ReadResult {
    pub ok: bool,
    pub msg: str,
    pub pipe: Pipe,
}

fn read_failed(p: Pipe) -> ReadResult {
    return ReadResult { ok: false, msg: "", pipe: p };
}

// ---------------------------------------------------------------------------
// pipe_read: dequeue the oldest message
// ---------------------------------------------------------------------------

fn pipe_read(p: Pipe) -> ReadResult {
    if p.count <= 0 {
        if p.state == PIPE_CLOSED() || p.state == PIPE_HALF_CLOSED() {
            io::println("[PIPE] read: EOF (pipe drained and closed)");
        } else {
            io::println("[PIPE] read: buffer empty — EWOULDBLOCK");
        }
        return read_failed(p);
    }
    let msg = pipe_get_slot(p, p.head);
    let new_head = p.head + 1;
    let next_head = new_head - (new_head / 9) * 9;
    let final_pipe = Pipe { id: p.id, state: p.state,
        head: next_head, tail: p.tail, count: p.count - 1,
        s0: p.s0, s1: p.s1, s2: p.s2,
        s3: p.s3, s4: p.s4, s5: p.s5,
        s6: p.s6, s7: p.s7, s8: p.s8 };
    return ReadResult { ok: true, msg: msg, pipe: final_pipe };
}

// ---------------------------------------------------------------------------
// pipe_close: transition state (OPEN→HALF_CLOSED→CLOSED)
// ---------------------------------------------------------------------------

fn pipe_close(p: Pipe) -> Pipe {
    tif p.state {
        + => {
            io::print("[PIPE] close: pipe ");
            io::print_int(p.id);
            io::println(" -> HALF_CLOSED (write end closed)");
            return Pipe { id: p.id, state: PIPE_HALF_CLOSED(),
                head: p.head, tail: p.tail, count: p.count,
                s0: p.s0, s1: p.s1, s2: p.s2,
                s3: p.s3, s4: p.s4, s5: p.s5,
                s6: p.s6, s7: p.s7, s8: p.s8 };
        }
        0 => {
            io::print("[PIPE] close: pipe ");
            io::print_int(p.id);
            io::println(" -> CLOSED (read end closed)");
            return Pipe { id: p.id, state: PIPE_CLOSED(),
                head: p.head, tail: p.tail, count: p.count,
                s0: p.s0, s1: p.s1, s2: p.s2,
                s3: p.s3, s4: p.s4, s5: p.s5,
                s6: p.s6, s7: p.s7, s8: p.s8 };
        }
        - => {
            io::println("[PIPE] close: already CLOSED");
            return p;
        }
    }
}

// ---------------------------------------------------------------------------
// print_pipe: display pipe status
// ---------------------------------------------------------------------------

fn print_pipe(p: Pipe) {
    io::print("[PIPE] id=");
    io::print_int(p.id);
    io::print("  state=");
    io::print(pipe_state_name(p.state));
    io::print("  count=");
    io::print_int(p.count);
    io::print(" / ");
    io::print_int(PIPE_CAPACITY());
    io::print("  head=");
    io::print_int(p.head);
    io::print("  tail=");
    io::println_int(p.tail);
}

// ---------------------------------------------------------------------------
// main: demonstrate unnamed pipe
// ---------------------------------------------------------------------------
