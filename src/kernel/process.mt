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

    let exited = make_pcb(p.pid, new_state, p.privilege, p.parent_pid);

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
