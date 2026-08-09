// test_tmin2.mt — THATTE-OS TMIN2 gate exhaustive tests
// Tests the full 3x3 truth table, permission_check for all 9 ring x page
// combinations, can_access for privilege escalation/denial, and edge cases.
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
// Reproduced from kernel/tmin2.mt
// ---------------------------------------------------------------------------

fn tmin2(a: trit, b: trit) -> trit {
    tif a {
        + => {
            return b;
        }
        0 => {
            tif b {
                + => return 0,
                0 => return 0,
                - => return -,
            }
        }
        - => {
            return -;
        }
    }
}

fn trit_eq(a: trit, b: trit) -> bool {
    tif a {
        + => {
            tif b { + => return true, 0 => return false, - => return false }
        }
        0 => {
            tif b { + => return false, 0 => return true, - => return false }
        }
        - => {
            tif b { + => return false, 0 => return false, - => return true }
        }
    }
}

fn permission_check(page_perm: trit, ring: trit) -> bool3 {
    let gate_out = tmin2(ring, page_perm);
    // Access allowed iff tmin2(ring, page_perm) == page_perm
    tif gate_out {
        + => {
            tif page_perm {
                + => return +,
                0 => return -,
                - => return -,
            }
        }
        0 => {
            tif page_perm {
                + => return -,
                0 => return +,
                - => return -,
            }
        }
        - => {
            tif page_perm {
                + => return -,
                0 => return -,
                - => return +,
            }
        }
    }
}

fn can_access(required: trit, current: trit) -> bool3 {
    let gate_out = tmin2(current, required);
    // current >= required iff tmin2(current, required) == required
    tif gate_out {
        + => {
            tif required {
                + => return +,
                0 => return -,
                - => return -,
            }
        }
        0 => {
            tif required {
                + => return -,
                0 => return +,
                - => return -,
            }
        }
        - => {
            tif required {
                + => return -,
                0 => return -,
                - => return +,
            }
        }
    }
}

fn is_true(v: bool3) -> bool {
    tif v { + => return true, 0 => return false, - => return false }
}

fn is_false(v: bool3) -> bool {
    tif v { + => return false, 0 => return false, - => return true }
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn main() {
    io::println("=== THATTE-OS TMIN2 Gate Tests (Exhaustive) ===");
    let mut passed = 0;
    let mut total = 0;

    // -----------------------------------------------------------------------
    // Part 1: Full 3x3 truth table of tmin2(a, b)
    //
    //   a \ b  |  +1  |   0  |  -1
    //   -------+------+------+------
    //    +1    |  +1  |   0  |  -1
    //     0    |   0  |   0  |  -1
    //    -1    |  -1  |  -1  |  -1
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- TMIN2 truth table (9 combinations) ---");

    // Row a = +1
    total = total + 1;
    passed = passed + assert_true(trit_eq(tmin2(+, +), +), "tmin2(+1, +1) = +1", total);

    total = total + 1;
    passed = passed + assert_true(trit_eq(tmin2(+, 0), 0), "tmin2(+1,  0) =  0", total);

    total = total + 1;
    passed = passed + assert_true(trit_eq(tmin2(+, -), -), "tmin2(+1, -1) = -1", total);

    // Row a = 0
    total = total + 1;
    passed = passed + assert_true(trit_eq(tmin2(0, +), 0), "tmin2( 0, +1) =  0", total);

    total = total + 1;
    passed = passed + assert_true(trit_eq(tmin2(0, 0), 0), "tmin2( 0,  0) =  0", total);

    total = total + 1;
    passed = passed + assert_true(trit_eq(tmin2(0, -), -), "tmin2( 0, -1) = -1", total);

    // Row a = -1
    total = total + 1;
    passed = passed + assert_true(trit_eq(tmin2(-, +), -), "tmin2(-1, +1) = -1", total);

    total = total + 1;
    passed = passed + assert_true(trit_eq(tmin2(-, 0), -), "tmin2(-1,  0) = -1", total);

    total = total + 1;
    passed = passed + assert_true(trit_eq(tmin2(-, -), -), "tmin2(-1, -1) = -1", total);

    // -----------------------------------------------------------------------
    // Part 2: permission_check for all 9 ring x page combinations
    //
    // KERNEL(+1) accesses anything.
    // SERVICE(0) accesses RESTRICTED(0) and PUBLIC(-1), not PRIVATE(+1).
    // USER(-1) accesses only PUBLIC(-1).
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- permission_check (9 ring x page) ---");

    // KERNEL(+) vs all pages
    total = total + 1;
    passed = passed + assert_true(is_true(permission_check(+, +)),
        "KERNEL + PRIVATE   -> ALLOW", total);

    total = total + 1;
    passed = passed + assert_true(is_true(permission_check(0, +)),
        "KERNEL + RESTRICTED -> ALLOW", total);

    total = total + 1;
    passed = passed + assert_true(is_true(permission_check(-, +)),
        "KERNEL + PUBLIC    -> ALLOW", total);

    // SERVICE(0) vs all pages
    total = total + 1;
    passed = passed + assert_true(is_false(permission_check(+, 0)),
        "SERVICE + PRIVATE  -> TRAP", total);

    total = total + 1;
    passed = passed + assert_true(is_true(permission_check(0, 0)),
        "SERVICE + RESTRICTED -> ALLOW", total);

    total = total + 1;
    passed = passed + assert_true(is_true(permission_check(-, 0)),
        "SERVICE + PUBLIC   -> ALLOW", total);

    // USER(-) vs all pages
    total = total + 1;
    passed = passed + assert_true(is_false(permission_check(+, -)),
        "USER + PRIVATE     -> TRAP", total);

    total = total + 1;
    passed = passed + assert_true(is_false(permission_check(0, -)),
        "USER + RESTRICTED  -> TRAP", total);

    total = total + 1;
    passed = passed + assert_true(is_true(permission_check(-, -)),
        "USER + PUBLIC      -> ALLOW", total);

    // -----------------------------------------------------------------------
    // Part 3: can_access for privilege escalation/denial scenarios
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- can_access (escalation/denial) ---");

    // Privilege sufficient
    total = total + 1;
    passed = passed + assert_true(is_true(can_access(+, +)),
        "KERNEL meets PRIVATE requirement", total);

    total = total + 1;
    passed = passed + assert_true(is_true(can_access(0, +)),
        "KERNEL exceeds RESTRICTED requirement", total);

    total = total + 1;
    passed = passed + assert_true(is_true(can_access(-, +)),
        "KERNEL exceeds PUBLIC requirement", total);

    total = total + 1;
    passed = passed + assert_true(is_true(can_access(0, 0)),
        "SERVICE meets RESTRICTED requirement", total);

    total = total + 1;
    passed = passed + assert_true(is_true(can_access(-, 0)),
        "SERVICE exceeds PUBLIC requirement", total);

    total = total + 1;
    passed = passed + assert_true(is_true(can_access(-, -)),
        "USER meets PUBLIC requirement", total);

    // Privilege insufficient (escalation denied)
    total = total + 1;
    passed = passed + assert_true(is_false(can_access(+, 0)),
        "SERVICE cannot access PRIVATE (denied)", total);

    total = total + 1;
    passed = passed + assert_true(is_false(can_access(+, -)),
        "USER cannot access PRIVATE (denied)", total);

    total = total + 1;
    passed = passed + assert_true(is_false(can_access(0, -)),
        "USER cannot access RESTRICTED (denied)", total);

    // -----------------------------------------------------------------------
    // Part 4: Edge cases — same privilege level
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Edge cases: same privilege level ---");

    // tmin2 is idempotent: min(x, x) = x for all x
    total = total + 1;
    passed = passed + assert_true(trit_eq(tmin2(+, +), +),
        "tmin2 idempotent: min(+1,+1) = +1", total);

    total = total + 1;
    passed = passed + assert_true(trit_eq(tmin2(0, 0), 0),
        "tmin2 idempotent: min(0,0) = 0", total);

    total = total + 1;
    passed = passed + assert_true(trit_eq(tmin2(-, -), -),
        "tmin2 idempotent: min(-1,-1) = -1", total);

    // tmin2 is commutative: min(a, b) = min(b, a)
    total = total + 1;
    let fwd = tmin2(+, -);
    let rev = tmin2(-, +);
    passed = passed + assert_true(trit_eq(fwd, rev),
        "tmin2 commutative: min(+1,-1) = min(-1,+1)", total);

    total = total + 1;
    let fwd2 = tmin2(+, 0);
    let rev2 = tmin2(0, +);
    passed = passed + assert_true(trit_eq(fwd2, rev2),
        "tmin2 commutative: min(+1,0) = min(0,+1)", total);

    total = total + 1;
    let fwd3 = tmin2(0, -);
    let rev3 = tmin2(-, 0);
    passed = passed + assert_true(trit_eq(fwd3, rev3),
        "tmin2 commutative: min(0,-1) = min(-1,0)", total);

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
