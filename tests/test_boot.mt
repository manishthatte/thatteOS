// test_boot.mt — THATTE-OS boot sequence tests
// Verifies boot order, StatusReg construction, privilege transitions,
// and privilege_name correctness.

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
// Minimal reproductions of boot.mt types and functions
// ---------------------------------------------------------------------------

struct StatusReg {
    pub privilege: trit,
    pub irq_enable: trit,
    pub flags: trit,
}

fn make_status(priv_level: trit, irq: trit, flags: trit) -> StatusReg {
    return StatusReg { privilege: priv_level, irq_enable: irq, flags: flags };
}

fn privilege_name(p: trit) -> str {
    tif p {
        + => return "KERNEL (+1) VDD",
        0 => return "SERVICE (0) GND",
        - => return "USER (-1) VSS",
    }
}

// Simulate boot subsystem init order — each returns an int step number
fn interrupt_init() -> int { return 1; }
fn process_init() -> int { return 2; }
fn vmem_init() -> int { return 3; }
fn syscall_init() -> int { return 4; }

fn tty_init(sr: StatusReg) -> StatusReg {
    // Drops KERNEL -> SERVICE
    return make_status(0, sr.irq_enable, sr.flags);
}

fn launch_init(sr: StatusReg) -> StatusReg {
    // Drops SERVICE -> USER
    return make_status(-, sr.irq_enable, sr.flags);
}

// ---------------------------------------------------------------------------
// Trit comparison helpers
// ---------------------------------------------------------------------------

fn trit_eq(a: trit, b: trit) -> bool {
    tif a {
        + => {
            tif b {
                + => return true,
                0 => return false,
                - => return false,
            }
        }
        0 => {
            tif b {
                + => return false,
                0 => return true,
                - => return false,
            }
        }
        - => {
            tif b {
                + => return false,
                0 => return false,
                - => return true,
            }
        }
    }
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn main() {
    io::println("=== THATTE-OS Boot Sequence Tests ===");
    let mut passed = 0;
    let mut total = 0;

    // -----------------------------------------------------------------------
    // Test 1-4: Boot order — subsystems initialise in correct sequence
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Boot order verification ---");

    let step1 = interrupt_init();
    let step2 = process_init();
    let step3 = vmem_init();
    let step4 = syscall_init();

    total = total + 1;
    passed = passed + assert_true(step1 == 1, "interrupt_init is step 1", total);

    total = total + 1;
    passed = passed + assert_true(step2 == 2, "process_init is step 2", total);

    total = total + 1;
    passed = passed + assert_true(step3 == 3, "vmem_init is step 3", total);

    total = total + 1;
    passed = passed + assert_true(step4 == 4, "syscall_init is step 4", total);

    // Verify sequential order
    total = total + 1;
    passed = passed + assert_true(step1 < step2, "interrupt before process", total);

    total = total + 1;
    passed = passed + assert_true(step2 < step3, "process before vmem", total);

    // -----------------------------------------------------------------------
    // Test 7-9: StatusReg construction
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- StatusReg construction ---");

    let sr_kernel = make_status(+, +, 0);
    total = total + 1;
    passed = passed + assert_true(trit_eq(sr_kernel.privilege, +), "StatusReg KERNEL privilege = +", total);

    total = total + 1;
    passed = passed + assert_true(trit_eq(sr_kernel.irq_enable, +), "StatusReg irq_enable = +", total);

    total = total + 1;
    passed = passed + assert_true(trit_eq(sr_kernel.flags, 0), "StatusReg flags = 0", total);

    // -----------------------------------------------------------------------
    // Test 10-12: Privilege transitions KERNEL->SERVICE->USER
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Privilege transitions ---");

    // KERNEL -> SERVICE via tty_init
    let sr_service = tty_init(sr_kernel);
    total = total + 1;
    passed = passed + assert_true(trit_eq(sr_service.privilege, 0), "tty_init drops KERNEL -> SERVICE", total);

    // SERVICE -> USER via launch_init
    let sr_user = launch_init(sr_service);
    total = total + 1;
    passed = passed + assert_true(trit_eq(sr_user.privilege, -), "launch_init drops SERVICE -> USER", total);

    // irq_enable preserved through transitions
    total = total + 1;
    passed = passed + assert_true(trit_eq(sr_user.irq_enable, +), "irq_enable preserved through transitions", total);

    // -----------------------------------------------------------------------
    // Test 13-15: privilege_name returns correct strings
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- privilege_name verification ---");

    total = total + 1;
    passed = passed + assert_true(privilege_name(+) == "KERNEL (+1) VDD", "privilege_name(+) = KERNEL", total);

    total = total + 1;
    passed = passed + assert_true(privilege_name(0) == "SERVICE (0) GND", "privilege_name(0) = SERVICE", total);

    total = total + 1;
    passed = passed + assert_true(privilege_name(-) == "USER (-1) VSS", "privilege_name(-) = USER", total);

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
