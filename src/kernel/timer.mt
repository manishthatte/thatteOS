// kernel/timer.mt — THATTE-OS timer subsystem
// Module 15: System tick, sleep queue, timer interrupt handler
//
// Demonstrates P5 Claims:
//   Claim 1  — Process SLEEP(-2) state and wakeup
//   Claim 5  — Timer interrupt (vector 0, MEDIUM priority)
//
// Tick granularity: 1 system tick per timer interrupt
// Quantum: 3 ticks (ternary) per scheduling round

use std::io;

// ---------------------------------------------------------------------------
// Timer state
// ---------------------------------------------------------------------------

struct TimerState {
    pub tick: int,
    pub quantum: int,         // ticks per scheduling quantum (3)
    pub ticks_this_quantum: int,
}

fn timer_init() -> TimerState {
    io::println("[TIMER] timer_init: system timer started");
    io::println("  tick counter: 0");
    io::println("  quantum: 3 ticks (ternary)");
    io::println("  timer vector: 0 (MEDIUM priority)");
    return TimerState { tick: 0, quantum: 3, ticks_this_quantum: 0 };
}

// ---------------------------------------------------------------------------
// Sleep queue entry
// ---------------------------------------------------------------------------

struct SleepEntry {
    pub pid: int,
    pub wake_tick: int,
    pub valid: bool,
}

fn make_sleep_entry(pid: int, wake_tick: int) -> SleepEntry {
    return SleepEntry { pid: pid, wake_tick: wake_tick, valid: true };
}

fn empty_sleep_entry() -> SleepEntry {
    return SleepEntry { pid: 0, wake_tick: 0, valid: false };
}

// ---------------------------------------------------------------------------
// Sleep queue (9 entries, ternary-sized)
// ---------------------------------------------------------------------------

struct SleepQueue {
    pub count: int,
    pub s0: SleepEntry,
    pub s1: SleepEntry,
    pub s2: SleepEntry,
    pub s3: SleepEntry,
    pub s4: SleepEntry,
    pub s5: SleepEntry,
    pub s6: SleepEntry,
    pub s7: SleepEntry,
    pub s8: SleepEntry,
}

fn sleep_queue_init() -> SleepQueue {
    return SleepQueue {
        count: 0,
        s0: empty_sleep_entry(), s1: empty_sleep_entry(), s2: empty_sleep_entry(),
        s3: empty_sleep_entry(), s4: empty_sleep_entry(), s5: empty_sleep_entry(),
        s6: empty_sleep_entry(), s7: empty_sleep_entry(), s8: empty_sleep_entry(),
    };
}

// ---------------------------------------------------------------------------
// sys_sleep: put process to SLEEP(-2) for N ticks
// ---------------------------------------------------------------------------

fn sys_sleep(timer: TimerState, queue: SleepQueue, pid: int, ticks: int) -> SleepQueue {
    io::print("[SYS_SLEEP] pid=");
    io::print_int(pid);
    io::print(" ticks=");
    io::println_int(ticks);

    if ticks <= 0 {
        io::println("  invalid sleep duration — returning immediately");
        return queue;
    }

    if queue.count >= 9 {
        io::println("  sleep queue full — cannot sleep");
        return queue;
    }

    let wake_tick = timer.tick + ticks;
    let entry = make_sleep_entry(pid, wake_tick);

    io::print("  process.state = SLEEP(-2), wake at tick=");
    io::println_int(wake_tick);

    // Add to first empty slot
    let new_count = queue.count + 1;
    if !queue.s0.valid {
        return SleepQueue { count: new_count, s0: entry, s1: queue.s1, s2: queue.s2,
            s3: queue.s3, s4: queue.s4, s5: queue.s5, s6: queue.s6, s7: queue.s7, s8: queue.s8 };
    } elif !queue.s1.valid {
        return SleepQueue { count: new_count, s0: queue.s0, s1: entry, s2: queue.s2,
            s3: queue.s3, s4: queue.s4, s5: queue.s5, s6: queue.s6, s7: queue.s7, s8: queue.s8 };
    } elif !queue.s2.valid {
        return SleepQueue { count: new_count, s0: queue.s0, s1: queue.s1, s2: entry,
            s3: queue.s3, s4: queue.s4, s5: queue.s5, s6: queue.s6, s7: queue.s7, s8: queue.s8 };
    } elif !queue.s3.valid {
        return SleepQueue { count: new_count, s0: queue.s0, s1: queue.s1, s2: queue.s2,
            s3: entry, s4: queue.s4, s5: queue.s5, s6: queue.s6, s7: queue.s7, s8: queue.s8 };
    } elif !queue.s4.valid {
        return SleepQueue { count: new_count, s0: queue.s0, s1: queue.s1, s2: queue.s2,
            s3: queue.s3, s4: entry, s5: queue.s5, s6: queue.s6, s7: queue.s7, s8: queue.s8 };
    } elif !queue.s5.valid {
        return SleepQueue { count: new_count, s0: queue.s0, s1: queue.s1, s2: queue.s2,
            s3: queue.s3, s4: queue.s4, s5: entry, s6: queue.s6, s7: queue.s7, s8: queue.s8 };
    } elif !queue.s6.valid {
        return SleepQueue { count: new_count, s0: queue.s0, s1: queue.s1, s2: queue.s2,
            s3: queue.s3, s4: queue.s4, s5: queue.s5, s6: entry, s7: queue.s7, s8: queue.s8 };
    } elif !queue.s7.valid {
        return SleepQueue { count: new_count, s0: queue.s0, s1: queue.s1, s2: queue.s2,
            s3: queue.s3, s4: queue.s4, s5: queue.s5, s6: queue.s6, s7: entry, s8: queue.s8 };
    } else {
        return SleepQueue { count: new_count, s0: queue.s0, s1: queue.s1, s2: queue.s2,
            s3: queue.s3, s4: queue.s4, s5: queue.s5, s6: queue.s6, s7: queue.s7, s8: entry };
    }
}

// ---------------------------------------------------------------------------
// TickResult: combined return from timer_tick (timer + updated queue)
// ---------------------------------------------------------------------------

struct TickResult {
    pub timer: TimerState,
    pub queue: SleepQueue,
}

// ---------------------------------------------------------------------------
// wake_entry_if_due: check one entry; log wakeup and clear it if expired
// ---------------------------------------------------------------------------

fn wake_entry_if_due(entry: SleepEntry, current_tick: int, t: ProcTable) -> SleepEntry {
    if entry.valid && current_tick >= entry.wake_tick {
        io::print("  [TIMER] waking PID=");
        io::print_int(entry.pid);
        io::print(" (sleep expired at tick=");
        io::print_int(entry.wake_tick);
        io::println(")");
        // IT NOW WAKES IT. ENHANCEMENT_PLAN §2.1.
        // This line used to be the whole of the waking: the queue entry was
        // invalidated and the sleeper's own PCB was never touched, because
        // until §2.0 there was no process table to touch. A process that had
        // called sys_sleep stayed in SLEEP(-2) for ever while the timer
        // printed that it had been made READY.
        if table_set_state(t, entry.pid, 3) {
            io::println("    process.state = READY(+3)");
        } else {
            io::println("    process.state = READY(+3) — pid not in the table");
        }
        // Clear the entry so it does not fire again next tick
        return SleepEntry { pid: entry.pid, wake_tick: entry.wake_tick, valid: false };
    }
    return entry;
}

// ---------------------------------------------------------------------------
// timer_tick: called on every timer interrupt (vector 0)
// Returns updated TimerState AND the cleaned SleepQueue.
// ---------------------------------------------------------------------------

fn timer_tick(timer: TimerState, queue: SleepQueue, t: ProcTable) -> TickResult {
    let new_tick = timer.tick + 1;
    let new_quantum_ticks = timer.ticks_this_quantum + 1;

    io::print("[TIMER] tick=");
    io::println_int(new_tick);

    // Wake and invalidate any expired sleep entries
    let e0 = wake_entry_if_due(queue.s0, new_tick, t);
    let e1 = wake_entry_if_due(queue.s1, new_tick, t);
    let e2 = wake_entry_if_due(queue.s2, new_tick, t);
    let e3 = wake_entry_if_due(queue.s3, new_tick, t);
    let e4 = wake_entry_if_due(queue.s4, new_tick, t);
    let e5 = wake_entry_if_due(queue.s5, new_tick, t);
    let e6 = wake_entry_if_due(queue.s6, new_tick, t);
    let e7 = wake_entry_if_due(queue.s7, new_tick, t);
    let e8 = wake_entry_if_due(queue.s8, new_tick, t);

    // Count how many entries were woken (valid before, invalidated now) so
    // queue.count reflects the number of occupied slots.
    let mut woken = 0;
    if queue.s0.valid && !e0.valid { woken = woken + 1; }
    if queue.s1.valid && !e1.valid { woken = woken + 1; }
    if queue.s2.valid && !e2.valid { woken = woken + 1; }
    if queue.s3.valid && !e3.valid { woken = woken + 1; }
    if queue.s4.valid && !e4.valid { woken = woken + 1; }
    if queue.s5.valid && !e5.valid { woken = woken + 1; }
    if queue.s6.valid && !e6.valid { woken = woken + 1; }
    if queue.s7.valid && !e7.valid { woken = woken + 1; }
    if queue.s8.valid && !e8.valid { woken = woken + 1; }

    let new_queue = SleepQueue {
        count: queue.count - woken,
        s0: e0, s1: e1, s2: e2,
        s3: e3, s4: e4, s5: e5,
        s6: e6, s7: e7, s8: e8,
    };

    // Check quantum expiry
    let mut final_quantum_ticks = new_quantum_ticks;
    if new_quantum_ticks >= timer.quantum {
        io::println("  [TIMER] quantum expired (3 ticks) — preempt current process");
        // AND IT NOW INVOKES IT. ENHANCEMENT_PLAN §2.1.
        // The line under this one used to read `-> scheduler_run() invoked`,
        // which was true only as a description. It was one of four sites in
        // the kernel printing that sentence, none of which called the
        // function -- and while `scheduler_run` built its own table and threw
        // it away, printing was the honest choice.
        scheduler_run(t);
        final_quantum_ticks = 0;
    }

    return TickResult {
        timer: TimerState { tick: new_tick, quantum: timer.quantum, ticks_this_quantum: final_quantum_ticks },
        queue: new_queue,
    };
}

// ---------------------------------------------------------------------------
// uptime: format uptime
// ---------------------------------------------------------------------------

fn uptime(timer: TimerState) {
    io::print("[TIMER] uptime: ");
    io::print_int(timer.tick);
    io::println(" ticks");
}

// ---------------------------------------------------------------------------
// main: demonstrate timer subsystem
// ---------------------------------------------------------------------------
