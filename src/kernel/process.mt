// kernel/process.mt — THATTE-OS process management
// Module 3: PCB, sys_fork, sys_exec, sys_exit
//
// Demonstrates P5 Claims:
//   Claim 4 — Syscall ABI (SYS_FORK, SYS_EXEC, SYS_EXIT)
//   Claim 1 — Process state model

use std::io;

// ---------------------------------------------------------------------------
// PCB structure
// ---------------------------------------------------------------------------

// ONE PCB, 30 August 2026. There were three: this one, kernel/scheduler.mt's,
// and a dead one in boot.mt. They were not copies that had drifted -- they held
// DIFFERENT FIELDS, because each module had described the part of a process it
// personally cared about and nothing ever made them meet. This module knew a
// process's identity and privilege; the scheduler knew its priority, its age
// and how much of its quantum it had spent.
//
// A real process control block is the union, so that is what this is. The merge
// was a design decision at this site rather than a deletion: choosing either
// module's struct would have silently thrown away the other's three fields.
struct PCB {
    // identity and privilege (this module)
    pub pid: int,
    pub state: int,
    pub pc: int,
    pub sp: int,
    pub privilege: trit,
    pub page_table: int,
    pub parent_pid: int,
    // scheduling (kernel/scheduler.mt)
    pub priority: trit,    // HIGH(+) NORMAL(0) LOW(-)
    pub age: int,          // ticks since last dispatch (starvation counter)
    pub quantum_used: int, // ticks used in current quantum
    // authority (security/capability.mt) -- ENHANCEMENT_PLAN §2.3
    //
    // The plan named this field as 2.3's prerequisite and it was missing: a
    // nine-trit CapWord existed, `enforce` existed, and there was nowhere to
    // put a process's authority, so every one of `enforce`'s nine callers was
    // in its own demo. `security/capability.mt` now precedes this module in
    // both manifests -- it is self-contained (it calls nothing it does not
    // define and never mentions PCB), so the move is pure ordering.
    pub caps: CapWord,
}

// caps_for: the authority a process gets from its ring.
//
// Derived from privilege rather than passed in, which keeps `make_pcb` at four
// arguments. That is not tidiness: the T3 convention passes arguments in R1-R8
// with no stack argument area, and this kernel has already been bitten by it
// once -- `context_save` took 13 parameters and `context_switch` 15, so
// kernel/context.mt compiled on LLVM and could not be built for its own target
// at all. Every function added here stays inside eight.
fn caps_for(priv_level: trit, pid: int) -> CapWord {
    tif priv_level {
        + => { return kernel_caps(pid); }
        0 => { return service_caps(pid); }
        - => { return user_caps(pid); }
    }
}

fn make_pcb(pid: int, state: int, priv_level: trit, parent: int) -> PCB {
    return PCB {
        pid: pid,
        state: state,
        pc: 0,
        sp: 0,
        privilege: priv_level,
        page_table: 0,
        parent_pid: parent,
        // A process created here has not been scheduled yet: NORMAL priority,
        // no age, no quantum spent. `make_pcb_prio` in kernel/scheduler.mt is
        // the constructor for the other direction.
        priority: 0,
        age: 0,
        quantum_used: 0,
        caps: caps_for(priv_level, pid),
    };
}

fn print_pcb(p: PCB) {
    io::print("  PCB: pid=");
    io::print_int(p.pid);
    io::print(" state=");
    io::print_int(p.state);
    io::print(" priv=");
    io::print_trit(p.privilege);
    io::print(" parent=");
    io::println_int(p.parent_pid);
}

// `state_name` moved out, 30 August 2026. This module had a four-arm version
// answering "READY(+3)", "EXITED(-3)", "KILLED(-4)" and "FAULTED(-5)" for
// everything else -- so it named four of the nine states a process can be in
// and misreported the other five. kernel/scheduler.mt's names all nine and is
// now the only one. The suffixed spelling is the loss and it is a small one:
// every caller here prints the number beside the name already.

// ---------------------------------------------------------------------------
// THE PROCESS TABLE — ENHANCEMENT_PLAN §2.0
// ---------------------------------------------------------------------------
//
// ADDED 30 August 2026. Phase 2 listed four items -- timer->scheduler,
// capability enforcement, signal delivery, and the event loop -- and every one
// of them turned out to block on a table that did not exist. `scheduler_run()`
// took no arguments, returned nothing, and built its own hardcoded nine-PCB
// table as a LOCAL on every call, aged it, scheduled it, and discarded it.
// `process_init()` beside it printed a description of a table and initialised
// none. There was no process table in this kernel; there were two functions
// that each pretended to have one.
//
// WHY IT IS THREADED RATHER THAN GLOBAL, measured and not assumed. ManiT does
// have global mutable state -- `NEXT_PID` below is one -- but a module-level
// `let` is stored as a SINGLE WORD written before `main` runs, and its
// initialiser must be a compile-time constant. An array of nine PCBs is
// neither, and the compiler says so in as many words. So the table is a value
// the kernel passes; the alternative is not available.
//
// WHY THE OPERATIONS MUTATE INSTEAD OF RETURNING A NEW TABLE. Three
// measurements, all taken on both backends before this was written:
//
//   1. A struct parameter is a MUTABLE REFERENCE. `fn f(t: T) { t.count = 1; }`
//      is visible to the caller. So a function that took a table, "copied" it,
//      and returned the copy would be handing back a second name for the same
//      object -- honest-looking and false.
//   2. An array field ALIASES. `let mut s = t.slots; s[i] = p;` writes through
//      to the argument's array, because the assignment copies the pointer.
//      A functional-looking wrapper around that is the same lie one level down.
//   3. `T { ..p, f: v }` genuinely copies, and on T3 that costs heap. The heap
//      is 2,536 words (maniTC report.txt P63) with no free, an 11-field PCB is
//      ~12 of them, and a scheduling pass touches nine PCBs. Copy-constructing
//      each pass is ~108 words, so roughly 23 passes exhaust the heap -- and
//      §2.1 is about to call the scheduler from the timer, which multiplies
//      exactly that number.
//
// So these mutate, and say so in their names and signatures. The aliasing is
// then the contract rather than a surprise.
//
// NINE SLOTS, matching the sleep queue and the PID allocator below: PIDs are
// capped at 8 by `alloc_pid`, so a tenth process cannot exist to be tabled.

struct ProcTable {
    pub count: int,     // live slots
    pub current: int,   // index of the running process; -1 if none
    pub p0: PCB, pub p1: PCB, pub p2: PCB,
    pub p3: PCB, pub p4: PCB, pub p5: PCB,
    pub p6: PCB, pub p7: PCB, pub p8: PCB,
}

// NINE NAMED FIELDS AND NOT `slots: [PCB]`, AND THAT IS A MEASUREMENT.
//
// The array version was written first and corrupted on T3 while hosted stayed
// correct: `count` one short, every pid garbage --
//     admitted: 1 processes, 9 of them live
//     DBG count=1 pid0=6979952655 pid1=429043474
// -- and the boot then trapped storing through one of those values.
//
// CORRECTION, 30 August 2026. This block used to end "it needs the whole
// 37,000-word kernel to reproduce, which is why no smaller repro exists to
// hand to maniTC". BOTH HALVES WERE WRONG. It reproduces in EIGHT LINES and
// 76 words, it is not about this struct or this kernel, and it is now maniTC
// report.txt **P94**:
//
//     fn mkarr() -> [int] { let a: [int] = [-1,-2,-3]; return a; }
//     fn show(a: [int]) { /* print a[0..2] */ }
//     fn main() { show(mkarr()); }        // T3 prints junk; LLVM is correct
//
// THE MECHANISM. The T3 backend puts every array alloca in the CALLER'S FRAME
// and does no escape analysis -- `regalloc::is_heap_alloca` answers `true`
// only for a struct -- so an array that is returned, bare or inside a struct,
// is a pointer to a frame that has been popped. The next CALL writes over it.
// LLVM `malloc`s the same array, so the backends disagree about an array's
// storage class. That a STRUCT survives the same journey is exactly why this
// hid: the shape that breaks is the shape a struct makes safe.
//
// The corrupt elements are the LAST k, where k is the next callee's frame
// size -- measured over array lengths 3,5,6,7,8,9,12, and at length 6 the
// standalone program reproduces `6979952655`, the value printed above.
//
// WHY THIS SHAPE ANYWAY, now that the cause is known. `slots: [PCB; 9]` --
// with the length in the type -- makes the caller copy the elements into its
// own live frame and IS correct here on both backends, verified. It then
// costs +53 heap words against a 55-word margin and the kernel trades a
// correct boot for `TRAP: heap exhausted` (max-heap 2,534 of 2,536, against
// 2,481 as shipped). So the named fields are kept for a SECOND, independent
// reason -- the T3 heap, report.txt P63 -- and not only for the defect.
// Note also that a sized array is the defect stepped around at each use, not
// repaired: `proc_table_init`'s own assembly is byte-identical either way.
//
// It follows the shape THIS KERNEL ALREADY PROVES: `SleepQueue` in
// kernel/timer.mt is also a nine-slot table, is also written as nine named
// fields rather than an array, and has been correct on both backends for
// months. The cost is that slots cannot be indexed, so `slot_at` below is an
// explicit nine-arm dispatch -- verbose, and sound.

fn free_pcb() -> PCB {
    return make_pcb(-1, -3, -, -1);
}

fn slot_is_free(p: PCB) -> bool {
    return p.pid < 0;
}

fn proc_table_init() -> ProcTable {
    return ProcTable {
        count: 0, current: -1,
        p0: free_pcb(), p1: free_pcb(), p2: free_pcb(),
        p3: free_pcb(), p4: free_pcb(), p5: free_pcb(),
        p6: free_pcb(), p7: free_pcb(), p8: free_pcb(),
    };
}

// slot_at: the indexing the named fields cost us. READ-ONLY -- see below.
//
// A struct PARAMETER is a mutable reference in this language, but a struct
// RETURNED from a function is a COPY. Measured on both backends:
//
//     age(t.p0)           direct field as argument   -> mutation propagates
//     age(at(t, 1))       call result as argument    -> mutation LOST
//     at(t, 0).age = 7    assign into a call result  -> assignment LOST
//
// The first version of this table used `slot_at` for writes as well and three
// assertions caught it -- the quantum charge, the dormant age and set_state --
// while a fourth passed for the wrong reason ("ACTIVE age reset to 0" is 0
// whether or not the aging happened). Every mutating path therefore dispatches
// on the field DIRECTLY, in `table_age`, `table_schedule` and
// `table_set_state` below. Verbose, and the only sound form.
fn slot_at(t: ProcTable, i: int) -> PCB {
    if i == 0 { return t.p0; }
    elif i == 1 { return t.p1; }
    elif i == 2 { return t.p2; }
    elif i == 3 { return t.p3; }
    elif i == 4 { return t.p4; }
    elif i == 5 { return t.p5; }
    elif i == 6 { return t.p6; }
    elif i == 7 { return t.p7; }
    else { return t.p8; }
}

// table_put: place `p` in slot `i`. MUTATES `t`.
fn table_put(t: ProcTable, i: int, p: PCB) {
    if i == 0 { t.p0 = p; }
    elif i == 1 { t.p1 = p; }
    elif i == 2 { t.p2 = p; }
    elif i == 3 { t.p3 = p; }
    elif i == 4 { t.p4 = p; }
    elif i == 5 { t.p5 = p; }
    elif i == 6 { t.p6 = p; }
    elif i == 7 { t.p7 = p; }
    else { t.p8 = p; }
}

// table_find: index of the slot holding `pid`, or -1.
fn table_find(t: ProcTable, pid: int) -> int {
    let mut i = 0;
    while i < 9 {
        if slot_at(t, i).pid == pid {
            return i;
        }
        i = i + 1;
    }
    return -1;
}

// table_admit: put `p` in the first free slot; returns its index, or -1 when
// the table is full. MUTATES `t`.
fn table_admit(t: ProcTable, p: PCB) -> int {
    // The slot is CHOSEN in the loop and WRITTEN outside it: ManiT's move
    // checker is flow-insensitive across a loop body, so moving `p` inside the
    // `while` is refused even though the `return` means it happens at most
    // once. Assignment moves in this language; passing to a function does not.
    let mut idx = -1;
    let mut i = 0;
    while i < 9 {
        if idx < 0 && slot_is_free(slot_at(t, i)) {
            idx = i;
        }
        i = i + 1;
    }
    if idx < 0 {
        return -1;
    }
    table_put(t, idx, p);
    t.count = t.count + 1;
    return idx;
}

// table_set_state: the one-field update the scheduler, the signal layer and
// the syscall layer all want. Returns false if no such pid. MUTATES `t`.
fn table_set_state(t: ProcTable, pid: int, new_state: int) -> bool {
    let idx = table_find(t, pid);
    if idx < 0 {
        return false;
    }
    if idx == 0 { t.p0.state = new_state; }
    elif idx == 1 { t.p1.state = new_state; }
    elif idx == 2 { t.p2.state = new_state; }
    elif idx == 3 { t.p3.state = new_state; }
    elif idx == 4 { t.p4.state = new_state; }
    elif idx == 5 { t.p5.state = new_state; }
    elif idx == 6 { t.p6.state = new_state; }
    elif idx == 7 { t.p7.state = new_state; }
    else { t.p8.state = new_state; }
    return true;
}

// table_set_pc: point a process at a new instruction. Used by the signal
// layer to enter a handler (§2.4).
fn table_set_pc(t: ProcTable, pid: int, new_pc: int) -> bool {
    let idx = table_find(t, pid);
    if idx < 0 {
        return false;
    }
    if idx == 0 { t.p0.pc = new_pc; }
    elif idx == 1 { t.p1.pc = new_pc; }
    elif idx == 2 { t.p2.pc = new_pc; }
    elif idx == 3 { t.p3.pc = new_pc; }
    elif idx == 4 { t.p4.pc = new_pc; }
    elif idx == 5 { t.p5.pc = new_pc; }
    elif idx == 6 { t.p6.pc = new_pc; }
    elif idx == 7 { t.p7.pc = new_pc; }
    else { t.p8.pc = new_pc; }
    return true;
}

// table_age / table_schedule: the two mutating passes the scheduler makes.
// Each hands the FIELD to the mutator, never `slot_at`'s copy.
fn table_age(t: ProcTable, i: int) {
    if i == 0 { age_tick(t.p0); }
    elif i == 1 { age_tick(t.p1); }
    elif i == 2 { age_tick(t.p2); }
    elif i == 3 { age_tick(t.p3); }
    elif i == 4 { age_tick(t.p4); }
    elif i == 5 { age_tick(t.p5); }
    elif i == 6 { age_tick(t.p6); }
    elif i == 7 { age_tick(t.p7); }
    else { age_tick(t.p8); }
}

// Records `t.current` when the slot was actually dispatched, so the table
// knows which process is running. Only a dispatch sets it: a dormant or
// terminal slot leaves the previous runner in place, which is what "currently
// running" means between two scheduling passes.
fn table_schedule(t: ProcTable, i: int) {
    let mut ran = false;
    if i == 0 { ran = schedule_pcb(0, t.p0); }
    elif i == 1 { ran = schedule_pcb(1, t.p1); }
    elif i == 2 { ran = schedule_pcb(2, t.p2); }
    elif i == 3 { ran = schedule_pcb(3, t.p3); }
    elif i == 4 { ran = schedule_pcb(4, t.p4); }
    elif i == 5 { ran = schedule_pcb(5, t.p5); }
    elif i == 6 { ran = schedule_pcb(6, t.p6); }
    elif i == 7 { ran = schedule_pcb(7, t.p7); }
    else { ran = schedule_pcb(8, t.p8); }
    if ran {
        t.current = i;
    }
}

// table_live: how many slots hold a process that is not terminal. Derived by
// walking the table rather than tracked in a counter, because a counter is a
// second source of truth about something the slots already say.
fn table_live(t: ProcTable) -> int {
    let mut n = 0;
    let mut i = 0;
    while i < 9 {
        if !slot_is_free(slot_at(t, i)) && slot_at(t, i).state > -3 {
            n = n + 1;
        }
        i = i + 1;
    }
    return n;
}

// ---------------------------------------------------------------------------
// Simulated process table
// ---------------------------------------------------------------------------

// Global PID allocator: PIDs 0 (idle) and 1 (init) are taken at boot;
// the 9-slot table caps live PIDs at 8. Never reuses a live PID and never
// hands out a PID past the table.
let mut NEXT_PID: int = 2;

fn alloc_pid() -> int {
    if NEXT_PID > 8 {
        return -1;   // process table full
    }
    let pid = NEXT_PID;
    NEXT_PID = NEXT_PID + 1;
    return pid;
}

// ---------------------------------------------------------------------------
// sys_fork: duplicate parent process (copy-on-write)
// ---------------------------------------------------------------------------

fn sys_fork(parent: PCB) -> PCB {
    io::println("[SYS_FORK] forking process");
    io::print("  parent: ");
    print_pcb(parent);

    // Allocate new PCB with copy-on-write page table
    let child_pid = alloc_pid();
    if child_pid < 0 {
        io::println("  SYS_FORK failed: process table full (9 slots) — EAGAIN");
        io::println("  SYS_FORK returns -1");
        return make_pcb(-1, -3, parent.privilege, parent.pid);
    }
    let child = make_pcb(child_pid, 3, parent.privilege, parent.pid);

    io::println("  copy-on-write: child page table — read_perm=0 (CoW)");
    io::print("  child:  ");
    print_pcb(child);
    io::print("  SYS_FORK returns child_pid=");
    io::println_int(child_pid);

    return child;
}

// ---------------------------------------------------------------------------
// sys_exec: load program image into process
// ---------------------------------------------------------------------------

fn sys_exec(p: PCB, image_addr: int) -> PCB {
    io::println("[SYS_EXEC] loading program image");
    io::print("  pid=");
    io::print_int(p.pid);
    io::print(" image_addr=0x");
    io::println_int(image_addr);

    // Fresh image: PC starts at image_addr, state READY
    // `PCB { ..p, ... }` rather than a field-by-field copy, and the reason is
    // the merge that produced this struct: a spelled-out literal has to be
    // revisited every time PCB gains a field, and the ten-field union it became
    // on 30 August 2026 broke every one of the seven literals in this kernel at
    // once. An update expression cannot forget a field.
    let new_p = PCB { ..p, state: 3, pc: image_addr };
    io::print("  process.pc = 0x");
    io::println_int(new_p.pc);
    io::println("  process.state = READY (+3)");
    io::println("  SYS_EXEC: image loaded");

    return new_p;
}

// ---------------------------------------------------------------------------
// sys_exit: terminate process
// ---------------------------------------------------------------------------

fn sys_exit(p: PCB, code: trit) -> PCB {
    io::println("[SYS_EXIT] process exiting");
    io::print("  pid=");
    io::print_int(p.pid);
    io::print(" exit_code=");
    io::println_trit(code);

    let new_state: int = tif code {
        + => -3,    // SYS_EXIT with code+ -> EXITED
        0 => -3,    // SYS_EXIT with code0 -> EXITED
        - => -4,    // SYS_EXIT with code- -> KILLED
    };

    // `PCB { ..p, .. }` and NOT `make_pcb(..)`, which is what this line used to
    // be. Rebuilding from four arguments silently discarded the other six
    // fields -- priority, age and quantum_used were reset by exiting, and once
    // PCB gained `caps` it would have handed a terminating process a FRESH
    // capability word derived from its ring, discarding any attenuation it was
    // running under. sys_exec twelve lines above already says why: "an update
    // expression cannot forget a field". This one was not using it.
    let exited = PCB { ..p, state: new_state };

    io::print("  process.state = ");
    io::println(state_name(new_state));
    io::print("  SYS_SEND to parent_pid=");
    io::print_int(p.parent_pid);
    io::println(" — exit notification");

    return exited;
}

// ---------------------------------------------------------------------------
// main: demonstrate process lifecycle
// ---------------------------------------------------------------------------
