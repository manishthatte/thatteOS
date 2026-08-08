// test_integration.mt — THATTE-OS full integration tests
// Simulates complete lifecycle: boot -> init -> fork -> exec -> IPC ->
// signal -> exit -> reap. Tests privilege drops, multi-process scenarios,
// fault recovery, and capability enforcement.

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
// Minimal reproduction of kernel types
// ---------------------------------------------------------------------------

// Process states
// EXECUTING=+4  READY=+3  YIELDED=+2  IO_WAIT=0  MSG_WAIT=-1  SLEEP=-2
// EXITED=-3  KILLED=-4  FAULTED=-5

fn state_name(s: int) -> str {
    if s == 4 { return "EXECUTING"; }
    elif s == 3 { return "READY"; }
    elif s == 2 { return "YIELDED"; }
    elif s == 0 { return "IO_WAIT"; }
    elif s == -1 { return "MSG_WAIT"; }
    elif s == -2 { return "SLEEP"; }
    elif s == -3 { return "EXITED"; }
    elif s == -4 { return "KILLED"; }
    else { return "FAULTED"; }
}

struct PCB {
    pub pid: int,
    pub state: int,
    pub privilege: trit,    // +1=KERNEL, 0=SERVICE, -1=USER
    pub parent_pid: int,
    pub exit_code: int,
}

fn make_pcb(pid: int, state: int, priv_level: trit, parent: int) -> PCB {
    return PCB {
        pid: pid, state: state,
        privilege: priv_level,
        parent_pid: parent,
        exit_code: 0,
    };
}

// Capability word (simplified: 9 trits as individual fields)
struct CapWord {
    pub c0: trit,   // CAN_FORK
    pub c1: trit,   // CAN_EXEC
    pub c2: trit,   // CAN_IPC
    pub c3: trit,   // CAN_IO
    pub c4: trit,   // CAN_MOD
    pub c5: trit,   // CAN_PRIV
    pub c6: trit,   // CAN_ALLOC
    pub c7: trit,   // CAN_SIGNAL
    pub c8: trit,   // CAN_FS
}

fn kernel_caps() -> CapWord {
    return CapWord { c0: +, c1: +, c2: +, c3: +, c4: +, c5: +, c6: +, c7: +, c8: + };
}

fn service_caps() -> CapWord {
    return CapWord { c0: +, c1: +, c2: +, c3: +, c4: -, c5: -, c6: +, c7: +, c8: + };
}

fn user_caps() -> CapWord {
    return CapWord { c0: +, c1: +, c2: -, c3: -, c4: -, c5: -, c6: +, c7: -, c8: + };
}

fn get_cap(caps: CapWord, idx: int) -> trit {
    if idx == 0 { return caps.c0; }
    elif idx == 1 { return caps.c1; }
    elif idx == 2 { return caps.c2; }
    elif idx == 3 { return caps.c3; }
    elif idx == 4 { return caps.c4; }
    elif idx == 5 { return caps.c5; }
    elif idx == 6 { return caps.c6; }
    elif idx == 7 { return caps.c7; }
    else { return caps.c8; }
}

fn cap_granted(caps: CapWord, idx: int) -> bool {
    let v = get_cap(caps, idx);
    tif v {
        + => return true,
        0 => return false,
        - => return false,
    }
}

// Privilege transition
fn sys_priv_set(current: trit, requested: trit) -> trit {
    tif current {
        + => {
            // KERNEL can transition to any level
            return requested;
        }
        0 => {
            // SERVICE can only drop to USER
            tif requested {
                + => return current,    // denied
                0 => return current,    // no-op
                - => return requested,  // allowed
            }
        }
        - => {
            // USER cannot escalate
            return current;
        }
    }
}

// sys_fork: returns child PCB
fn sys_fork(parent: PCB, child_pid: int) -> PCB {
    return make_pcb(child_pid, 3, parent.privilege, parent.pid);
}

// sys_exec: load program, returns updated PCB
fn sys_exec(p: PCB) -> PCB {
    return PCB { pid: p.pid, state: 3, privilege: p.privilege,
                 parent_pid: p.parent_pid, exit_code: 0 };
}

// sys_exit: returns PCB with EXITED state
fn sys_exit(p: PCB, code: int) -> PCB {
    return PCB { pid: p.pid, state: -3, privilege: p.privilege,
                 parent_pid: p.parent_pid, exit_code: code };
}

// sys_kill: send signal, returns new state for target
fn sys_kill(target_state: int, sig: int) -> int {
    if sig == -4 { return -4; }         // SIG_KILL -> KILLED
    elif sig == -3 { return -2; }       // SIG_STOP -> SLEEP
    elif sig == -2 { return -3; }       // SIG_TERM -> EXITED
    elif sig == 1 { return 3; }         // SIG_CONT -> READY
    else { return target_state; }
}

// IPC send (simplified)
fn ipc_send(sender_priv: trit) -> bool {
    tif sender_priv {
        + => return true,
        0 => return true,
        - => return false,
    }
}

// Reap: check if process is terminal and can be cleaned up
fn can_reap(state: int) -> bool {
    return state == -3 || state == -4 || state == -5;
}

// Fault: trigger privilege fault -> FAULTED(-5)
fn trigger_privilege_fault(p: PCB) -> PCB {
    return PCB { pid: p.pid, state: -5, privilege: p.privilege,
                 parent_pid: p.parent_pid, exit_code: -1 };
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn main() {
    io::println("=== THATTE-OS Integration Tests ===");
    let mut passed = 0;
    let mut total = 0;

    // =========================================================================
    // Lifecycle: boot -> init -> fork -> exec -> IPC -> signal -> exit -> reap
    // =========================================================================
    io::println("");
    io::println("--- Lifecycle simulation ---");

    // Step 1: Boot — kernel starts at KERNEL privilege
    let kernel = make_pcb(0, 4, +, -1);

    total = total + 1;
    let boot_priv: bool = tif kernel.privilege { + => true, 0 => false, - => false };
    passed = passed + assert_true(boot_priv, "boot: kernel at KERNEL privilege", total);

    total = total + 1;
    passed = passed + assert_true(kernel.state == 4, "boot: kernel state EXECUTING(+4)", total);

    // Step 2: Kernel spawns tty driver at SERVICE privilege
    let tty = make_pcb(1, 3, 0, 0);

    total = total + 1;
    let tty_priv: bool = tif tty.privilege { + => false, 0 => true, - => false };
    passed = passed + assert_true(tty_priv, "tty spawned at SERVICE privilege", total);

    // Step 3: Kernel spawns init at USER privilege
    let init = make_pcb(2, 3, -, 0);

    total = total + 1;
    let init_priv: bool = tif init.privilege { + => false, 0 => false, - => true };
    passed = passed + assert_true(init_priv, "init spawned at USER privilege", total);

    // Step 4: Init forks a child
    let child = sys_fork(init, 3);

    total = total + 1;
    passed = passed + assert_true(child.pid == 3, "fork: child gets pid=3", total);

    total = total + 1;
    passed = passed + assert_true(child.state == 3, "fork: child state READY(+3)", total);

    total = total + 1;
    passed = passed + assert_true(child.parent_pid == 2, "fork: child parent_pid=2 (init)", total);

    total = total + 1;
    let child_priv: bool = tif child.privilege { + => false, 0 => false, - => true };
    passed = passed + assert_true(child_priv, "fork: child inherits USER privilege", total);

    // Step 5: Exec child
    let child_exec = sys_exec(child);

    total = total + 1;
    passed = passed + assert_true(child_exec.state == 3, "exec: child state READY(+3)", total);

    // Step 6: IPC — tty (SERVICE) sends to init (USER)
    total = total + 1;
    let ipc_ok = ipc_send(0);
    passed = passed + assert_true(ipc_ok, "IPC: SERVICE can send messages", total);

    // Step 7: Signal — send SIG_TERM to child
    total = total + 1;
    let child_after_sig = sys_kill(child_exec.state, -2);
    passed = passed + assert_true(child_after_sig == -3, "signal: SIG_TERM -> EXITED(-3)", total);

    // Step 8: Exit child
    let child_exited = sys_exit(child_exec, 0);

    total = total + 1;
    passed = passed + assert_true(child_exited.state == -3, "exit: child state EXITED(-3)", total);

    total = total + 1;
    passed = passed + assert_true(child_exited.exit_code == 0, "exit: code 0 (normal)", total);

    // Step 9: Reap child
    total = total + 1;
    passed = passed + assert_true(can_reap(child_exited.state), "reap: EXITED process reapable", total);

    // =========================================================================
    // Privilege drop tests: KERNEL -> SERVICE -> USER
    // =========================================================================
    io::println("");
    io::println("--- Privilege drop tests ---");

    // KERNEL -> SERVICE
    total = total + 1;
    let priv1 = sys_priv_set(+, 0);
    let priv1_ok: bool = tif priv1 { + => false, 0 => true, - => false };
    passed = passed + assert_true(priv1_ok, "KERNEL -> SERVICE allowed", total);

    // KERNEL -> USER
    total = total + 1;
    let priv2 = sys_priv_set(+, -);
    let priv2_ok: bool = tif priv2 { + => false, 0 => false, - => true };
    passed = passed + assert_true(priv2_ok, "KERNEL -> USER allowed", total);

    // SERVICE -> USER
    total = total + 1;
    let priv3 = sys_priv_set(0, -);
    let priv3_ok: bool = tif priv3 { + => false, 0 => false, - => true };
    passed = passed + assert_true(priv3_ok, "SERVICE -> USER allowed", total);

    // SERVICE -> KERNEL (denied)
    total = total + 1;
    let priv4 = sys_priv_set(0, +);
    let priv4_ok: bool = tif priv4 { + => false, 0 => true, - => false };
    passed = passed + assert_true(priv4_ok, "SERVICE -> KERNEL denied (stays SERVICE)", total);

    // USER -> KERNEL (denied)
    total = total + 1;
    let priv5 = sys_priv_set(-, +);
    let priv5_ok: bool = tif priv5 { + => false, 0 => false, - => true };
    passed = passed + assert_true(priv5_ok, "USER -> KERNEL denied (stays USER)", total);

    // USER -> SERVICE (denied)
    total = total + 1;
    let priv6 = sys_priv_set(-, 0);
    let priv6_ok: bool = tif priv6 { + => false, 0 => false, - => true };
    passed = passed + assert_true(priv6_ok, "USER -> SERVICE denied (stays USER)", total);

    // =========================================================================
    // Multi-process: init forks child, child does IPC, parent reaps
    // =========================================================================
    io::println("");
    io::println("--- Multi-process scenario ---");

    let parent_proc = make_pcb(2, 4, -, 0);
    let child_proc = sys_fork(parent_proc, 4);

    total = total + 1;
    passed = passed + assert_true(child_proc.pid == 4, "multi: child pid=4", total);

    // Child attempts IPC (USER -> denied)
    total = total + 1;
    let child_ipc = ipc_send(-);
    passed = passed + assert_true(!child_ipc, "multi: USER child IPC denied", total);

    // Child exits
    let child_done = sys_exit(child_proc, 1);

    total = total + 1;
    passed = passed + assert_true(child_done.state == -3, "multi: child exited", total);

    // Parent reaps child
    total = total + 1;
    passed = passed + assert_true(can_reap(child_done.state), "multi: parent reaps child", total);

    // =========================================================================
    // Fault recovery: privilege fault -> FAULTED(-5)
    // =========================================================================
    io::println("");
    io::println("--- Fault recovery ---");

    let user_proc = make_pcb(5, 4, -, 2);

    // Trigger privilege fault (e.g., USER tries kernel-only operation)
    let faulted = trigger_privilege_fault(user_proc);

    total = total + 1;
    passed = passed + assert_true(faulted.state == -5, "fault: process state FAULTED(-5)", total);

    total = total + 1;
    passed = passed + assert_true(faulted.exit_code == -1, "fault: exit_code -1", total);

    total = total + 1;
    passed = passed + assert_true(can_reap(faulted.state), "fault: FAULTED process reapable", total);

    // Verify faulted process is in TERMINAL category
    total = total + 1;
    let faulted_terminal = faulted.state < -2;
    passed = passed + assert_true(faulted_terminal, "fault: FAULTED is TERMINAL (state < -2)", total);

    // =========================================================================
    // Capability enforcement in syscall chain
    // =========================================================================
    io::println("");
    io::println("--- Capability enforcement ---");

    let k_caps = kernel_caps();
    let s_caps = service_caps();
    let u_caps = user_caps();

    // KERNEL has all capabilities
    total = total + 1;
    passed = passed + assert_true(cap_granted(k_caps, 0), "KERNEL: CAN_FORK granted", total);

    total = total + 1;
    passed = passed + assert_true(cap_granted(k_caps, 4), "KERNEL: CAN_MOD granted", total);

    total = total + 1;
    passed = passed + assert_true(cap_granted(k_caps, 5), "KERNEL: CAN_PRIV granted", total);

    // SERVICE: fork and IPC yes, mod and priv no
    total = total + 1;
    passed = passed + assert_true(cap_granted(s_caps, 0), "SERVICE: CAN_FORK granted", total);

    total = total + 1;
    passed = passed + assert_true(cap_granted(s_caps, 2), "SERVICE: CAN_IPC granted", total);

    total = total + 1;
    passed = passed + assert_true(!cap_granted(s_caps, 4), "SERVICE: CAN_MOD denied", total);

    total = total + 1;
    passed = passed + assert_true(!cap_granted(s_caps, 5), "SERVICE: CAN_PRIV denied", total);

    // USER: fork and alloc yes, IPC and signal no
    total = total + 1;
    passed = passed + assert_true(cap_granted(u_caps, 0), "USER: CAN_FORK granted", total);

    total = total + 1;
    passed = passed + assert_true(!cap_granted(u_caps, 2), "USER: CAN_IPC denied", total);

    total = total + 1;
    passed = passed + assert_true(!cap_granted(u_caps, 3), "USER: CAN_IO denied", total);

    total = total + 1;
    passed = passed + assert_true(cap_granted(u_caps, 6), "USER: CAN_ALLOC granted", total);

    total = total + 1;
    passed = passed + assert_true(!cap_granted(u_caps, 7), "USER: CAN_SIGNAL denied", total);

    // =========================================================================
    // Signal lifecycle tests
    // =========================================================================
    io::println("");
    io::println("--- Signal lifecycle ---");

    // SIG_KILL -> KILLED(-4)
    total = total + 1;
    let killed_state = sys_kill(3, -4);
    passed = passed + assert_true(killed_state == -4, "SIG_KILL: READY -> KILLED(-4)", total);

    // SIG_STOP -> SLEEP(-2)
    total = total + 1;
    let stopped_state = sys_kill(3, -3);
    passed = passed + assert_true(stopped_state == -2, "SIG_STOP: READY -> SLEEP(-2)", total);

    // SIG_CONT -> READY(+3)
    total = total + 1;
    let resumed_state = sys_kill(-2, 1);
    passed = passed + assert_true(resumed_state == 3, "SIG_CONT: SLEEP -> READY(+3)", total);

    // SIG_NULL does not change state
    total = total + 1;
    let null_state = sys_kill(3, 0);
    passed = passed + assert_true(null_state == 3, "SIG_NULL: state unchanged", total);

    // Reapability of various terminal states
    total = total + 1;
    passed = passed + assert_true(can_reap(-3), "EXITED(-3) is reapable", total);

    total = total + 1;
    passed = passed + assert_true(can_reap(-4), "KILLED(-4) is reapable", total);

    total = total + 1;
    passed = passed + assert_true(can_reap(-5), "FAULTED(-5) is reapable", total);

    total = total + 1;
    passed = passed + assert_true(!can_reap(3), "READY(+3) is NOT reapable", total);

    total = total + 1;
    passed = passed + assert_true(!can_reap(0), "IO_WAIT(0) is NOT reapable", total);

    // --- Results ---
    io::println("");
    io::print("Results: ");
    io::print_int(passed);
    io::print("/");
    io::print_int(total);
    io::println(" passed");
}
