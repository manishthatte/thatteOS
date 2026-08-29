// kernel/panic.mt — THATTE-OS kernel panic handler
// Module 13: Structured panic, fault display, severity levels
//
// Demonstrates P5 Claims:
//   Claim 5  — Fault handling (interrupt vectors 2-5)
//   Claim 3  — Privilege context in diagnostics
//
// Panic severity as trit:
//   + = WARNING (non-fatal, continue)
//   0 = RECOVERABLE (kill faulting process, continue kernel)
//  -1 = FATAL (halt kernel)

use std::io;

// ---------------------------------------------------------------------------
// Panic severity
// ---------------------------------------------------------------------------

fn severity_name(s: trit) -> str {
    tif s {
        + => return "WARNING",
        0 => return "RECOVERABLE",
        - => return "FATAL",
    }
}

// `priv_name` moved to kernel/privilege.mt in the 30 Aug merge -- three
// kernel modules carried a byte-identical copy.

// ---------------------------------------------------------------------------
// Fault codes (ternary-indexed: -4 to +4)
// ---------------------------------------------------------------------------

fn fault_name(code: int) -> str {
    if code == -4 { return "DOUBLE_FAULT"; }
    elif code == -3 { return "STACK_OVERFLOW"; }
    elif code == -2 { return "DIVISION_BY_ZERO"; }
    elif code == -1 { return "ILLEGAL_INSTRUCTION"; }
    elif code == 0 { return "PAGE_FAULT"; }
    elif code == 1 { return "PRIVILEGE_FAULT"; }
    elif code == 2 { return "ADDRESS_FAULT"; }
    elif code == 3 { return "BUS_ERROR"; }
    elif code == 4 { return "ALIGNMENT_FAULT"; }
    else { return "UNKNOWN_FAULT"; }
}

fn fault_severity(code: int) -> trit {
    if code == -4 { return -; }    // DOUBLE_FAULT -> FATAL
    elif code == -3 { return 0; }  // STACK_OVERFLOW -> RECOVERABLE
    elif code == -2 { return 0; }  // DIV_ZERO -> RECOVERABLE
    elif code == -1 { return 0; }  // ILLEGAL_INSN -> RECOVERABLE
    elif code == 0 { return 0; }   // PAGE_FAULT -> RECOVERABLE
    elif code == 1 { return 0; }   // PRIV_FAULT -> RECOVERABLE
    elif code == 2 { return 0; }   // ADDR_FAULT -> RECOVERABLE
    elif code == 3 { return -; }   // BUS_ERROR -> FATAL
    elif code == 4 { return +; }   // ALIGNMENT -> WARNING
    else { return -; }             // UNKNOWN -> FATAL
}

// ---------------------------------------------------------------------------
// CPU state snapshot for panic display
// ---------------------------------------------------------------------------

struct CpuState {
    pub pc: int,
    pub sp: int,
    pub privilege: trit,
    pub irq_enable: trit,
    pub flags: trit,
    pub current_pid: int,
}

fn make_cpu_state(pc: int, sp: int, priv_level: trit, pid: int) -> CpuState {
    return CpuState {
        pc: pc,
        sp: sp,
        privilege: priv_level,
        irq_enable: +,
        flags: 0,
        current_pid: pid,
    };
}

fn print_cpu_state(cs: CpuState) {
    io::println("  +----------- CPU State -----------+");
    io::print("  | PC      = 0x");
    io::println_int(cs.pc);
    io::print("  | SP      = 0x");
    io::println_int(cs.sp);
    io::print("  | PRIV    = ");
    io::println(priv_name(cs.privilege));
    io::print("  | IRQ_EN  = ");
    io::println_trit(cs.irq_enable);
    io::print("  | FLAGS   = ");
    io::println_trit(cs.flags);
    io::print("  | CUR_PID = ");
    io::println_int(cs.current_pid);
    io::println("  +---------------------------------+");
}

// ---------------------------------------------------------------------------
// kernel_panic: the main panic handler
// ---------------------------------------------------------------------------

fn kernel_panic(fault_code: int, fault_addr: int, cpu: CpuState) {
    let severity = fault_severity(fault_code);

    io::println("");
    io::println("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");

    tif severity {
        + => io::println("!        KERNEL WARNING          !"),
        0 => io::println("!      RECOVERABLE FAULT         !"),
        - => io::println("!       KERNEL PANIC !!!         !"),
    }

    io::println("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
    io::println("");

    // Fault details
    io::print("  Fault:    ");
    io::println(fault_name(fault_code));
    io::print("  Severity: ");
    io::println(severity_name(severity));
    io::print("  Address:  0x");
    io::println_int(fault_addr);
    io::print("  Process:  PID=");
    io::println_int(cpu.current_pid);
    io::println("");

    // CPU state dump
    print_cpu_state(cpu);
    io::println("");

    // Recovery action based on severity
    tif severity {
        + => {
            io::println("  Action: LOG warning and continue execution");
            io::println("  -> klog(WARNING, fault_name, message)");
            io::println("  -> resume at PC+1");
        }
        0 => {
            io::println("  Action: KILL faulting process, continue kernel");
            io::print("  -> process ");
            io::print_int(cpu.current_pid);
            io::println(".state = FAULTED(-5)");
            io::println("  -> free process pages");
            io::println("  -> SYS_SEND exit notification to parent");
            io::println("  -> scheduler_run() — dispatch next process");
        }
        - => {
            io::println("  Action: HALT — kernel cannot continue");
            io::println("  -> disable all interrupts (STATUS[24]=-1)");
            io::println("  -> flush klog to TTY");
            io::println("  -> HALT instruction");
            io::println("");
            io::println("  System halted. Power cycle required.");
        }
    }
}

// ---------------------------------------------------------------------------
// Convenience fault raisers
// ---------------------------------------------------------------------------

fn page_fault(addr: int, pc: int, pid: int, priv_level: trit) {
    io::println("[FAULT] page_fault triggered");
    let cpu = make_cpu_state(pc, 0, priv_level, pid);
    kernel_panic(0, addr, cpu);
}

fn privilege_fault(pc: int, pid: int, priv_level: trit) {
    io::println("[FAULT] privilege_fault triggered");
    let cpu = make_cpu_state(pc, 0, priv_level, pid);
    kernel_panic(1, pc, cpu);
}

fn address_fault(addr: int, pc: int, pid: int, priv_level: trit) {
    io::println("[FAULT] address_fault triggered");
    let cpu = make_cpu_state(pc, 0, priv_level, pid);
    kernel_panic(2, addr, cpu);
}

fn division_by_zero(pc: int, pid: int, priv_level: trit) {
    io::println("[FAULT] division_by_zero triggered");
    let cpu = make_cpu_state(pc, 0, priv_level, pid);
    kernel_panic(-2, pc, cpu);
}

fn stack_overflow(sp: int, pid: int, priv_level: trit) {
    io::println("[FAULT] stack_overflow triggered");
    let cpu = make_cpu_state(0, sp, priv_level, pid);
    kernel_panic(-3, sp, cpu);
}

fn double_fault(pc: int, pid: int) {
    io::println("[FAULT] DOUBLE FAULT — fault during fault handler");
    let cpu = make_cpu_state(pc, 0, +, pid);
    kernel_panic(-4, pc, cpu);
}

// ---------------------------------------------------------------------------
// main: demonstrate all fault types and severities
// ---------------------------------------------------------------------------
