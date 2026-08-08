// test_privilege.mt — THATTE-OS exhaustive privilege tests
// Tests all 9 privilege transition combinations and all 9 address enforcement
// combinations (3 MST signs x 3 privilege levels).

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
// Reproduced from kernel/privilege.mt
// ---------------------------------------------------------------------------

fn int_to_trit(n: int) -> trit {
    if n > 0 { return +; }
    elif n < 0 { return -; }
    else { return 0; }
}

// sys_priv_set: returns new privilege level, or current on failure
fn sys_priv_set(current_priv: int, requested: int) -> int {
    let ct = int_to_trit(current_priv);
    tif ct {
        + => {
            // KERNEL can transition to any level
            return requested;
        }
        0 => {
            // SERVICE: can stay or drop to USER, cannot escalate to KERNEL
            let rt = int_to_trit(requested);
            tif rt {
                + => return current_priv,   // FAULT — no escalation
                0 => return current_priv,    // no-op
                - => return requested,       // downgrade allowed
            }
        }
        - => {
            // USER cannot escalate at all
            return current_priv;
        }
    }
}

// check_address_privilege: returns true if access allowed
fn check_address_privilege(addr: int, current_priv: int) -> bool {
    let mst = int_to_trit(addr);
    tif mst {
        + => {
            // Kernel space: only KERNEL allowed
            if current_priv > 0 { return true; }
            else { return false; }
        }
        0 => {
            // Shared space: all allowed
            return true;
        }
        - => {
            // User space: all allowed
            return true;
        }
    }
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn main() {
    io::println("=== THATTE-OS Privilege Tests (Exhaustive) ===");
    let mut passed = 0;
    let mut total = 0;

    // -----------------------------------------------------------------------
    // Part 1: All 9 privilege transition combinations
    // current x requested: KERNEL(1), SERVICE(0), USER(-1)
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Privilege transitions (9 combinations) ---");

    // KERNEL -> KERNEL (allowed, stays KERNEL)
    let r = sys_priv_set(1, 1);
    total = total + 1;
    passed = passed + assert_true(r == 1, "KERNEL -> KERNEL = 1 (allowed)", total);

    // KERNEL -> SERVICE (allowed, drops to SERVICE)
    let r = sys_priv_set(1, 0);
    total = total + 1;
    passed = passed + assert_true(r == 0, "KERNEL -> SERVICE = 0 (allowed)", total);

    // KERNEL -> USER (allowed, drops to USER)
    let r = sys_priv_set(1, -1);
    total = total + 1;
    passed = passed + assert_true(r == -1, "KERNEL -> USER = -1 (allowed)", total);

    // SERVICE -> KERNEL (FAULT, stays SERVICE)
    let r = sys_priv_set(0, 1);
    total = total + 1;
    passed = passed + assert_true(r == 0, "SERVICE -> KERNEL = 0 (fault, blocked)", total);

    // SERVICE -> SERVICE (no-op, stays SERVICE)
    let r = sys_priv_set(0, 0);
    total = total + 1;
    passed = passed + assert_true(r == 0, "SERVICE -> SERVICE = 0 (no-op)", total);

    // SERVICE -> USER (allowed, drops to USER)
    let r = sys_priv_set(0, -1);
    total = total + 1;
    passed = passed + assert_true(r == -1, "SERVICE -> USER = -1 (allowed)", total);

    // USER -> KERNEL (FAULT, stays USER)
    let r = sys_priv_set(-1, 1);
    total = total + 1;
    passed = passed + assert_true(r == -1, "USER -> KERNEL = -1 (fault, blocked)", total);

    // USER -> SERVICE (FAULT, stays USER)
    let r = sys_priv_set(-1, 0);
    total = total + 1;
    passed = passed + assert_true(r == -1, "USER -> SERVICE = -1 (fault, blocked)", total);

    // USER -> USER (no-op, stays USER)
    let r = sys_priv_set(-1, -1);
    total = total + 1;
    passed = passed + assert_true(r == -1, "USER -> USER = -1 (no-op)", total);

    // -----------------------------------------------------------------------
    // Part 2: Address enforcement (9 combinations: 3 MST x 3 priv)
    // MST(+) = kernel-space, MST(0) = shared, MST(-) = user-space
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Address enforcement (9 combinations) ---");

    // Kernel-space addr (positive) + KERNEL priv -> ALLOW
    total = total + 1;
    passed = passed + assert_true(check_address_privilege(1000, 1) == true,
        "addr(+) priv=KERNEL -> ALLOW", total);

    // Kernel-space addr (positive) + SERVICE priv -> DENY
    total = total + 1;
    passed = passed + assert_true(check_address_privilege(1000, 0) == false,
        "addr(+) priv=SERVICE -> DENY", total);

    // Kernel-space addr (positive) + USER priv -> DENY
    total = total + 1;
    passed = passed + assert_true(check_address_privilege(1000, -1) == false,
        "addr(+) priv=USER -> DENY", total);

    // Shared-space addr (zero) + KERNEL priv -> ALLOW
    total = total + 1;
    passed = passed + assert_true(check_address_privilege(0, 1) == true,
        "addr(0) priv=KERNEL -> ALLOW", total);

    // Shared-space addr (zero) + SERVICE priv -> ALLOW
    total = total + 1;
    passed = passed + assert_true(check_address_privilege(0, 0) == true,
        "addr(0) priv=SERVICE -> ALLOW", total);

    // Shared-space addr (zero) + USER priv -> ALLOW
    total = total + 1;
    passed = passed + assert_true(check_address_privilege(0, -1) == true,
        "addr(0) priv=USER -> ALLOW", total);

    // User-space addr (negative) + KERNEL priv -> ALLOW
    total = total + 1;
    passed = passed + assert_true(check_address_privilege(-500, 1) == true,
        "addr(-) priv=KERNEL -> ALLOW", total);

    // User-space addr (negative) + SERVICE priv -> ALLOW
    total = total + 1;
    passed = passed + assert_true(check_address_privilege(-500, 0) == true,
        "addr(-) priv=SERVICE -> ALLOW", total);

    // User-space addr (negative) + USER priv -> ALLOW
    total = total + 1;
    passed = passed + assert_true(check_address_privilege(-500, -1) == true,
        "addr(-) priv=USER -> ALLOW", total);

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
