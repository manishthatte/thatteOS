// test_memory.mt — THATTE-OS memory subsystem tests
// Tests all 9 permission combos, MST address sign extraction, guard pages,
// and conditional permission paths (CoW, demand-zero, JIT).

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
// Reproduced from mm/pgtable.mt and mm/vmem.mt
// ---------------------------------------------------------------------------

struct PageEntry {
    pub frame_addr: int,
    pub read_perm: trit,
    pub write_perm: trit,
    pub exec_perm: trit,
}

fn make_page(frame: int, r: trit, w: trit, x: trit) -> PageEntry {
    return PageEntry { frame_addr: frame, read_perm: r, write_perm: w, exec_perm: x };
}

// Returns: +1=allow, 0=conditional, -1=deny
// access_type: +=READ, 0=WRITE, -=EXEC
fn check_access(access_type: trit, entry: PageEntry) -> trit {
    tif access_type {
        + => return entry.read_perm,
        0 => return entry.write_perm,
        - => return entry.exec_perm,
    }
}

fn addr_mst(addr: int) -> trit {
    if addr > 0 { return +; }
    elif addr < 0 { return -; }
    else { return 0; }
}

fn check_address_privilege(addr: int, current_priv: trit) -> bool {
    let mst = addr_mst(addr);
    tif mst {
        + => {
            tif current_priv {
                + => return true,
                0 => return false,
                - => return false,
            }
        }
        0 => return true,
        - => return true,
    }
}

// ---------------------------------------------------------------------------
// Trit comparison helper
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
    io::println("=== THATTE-OS Memory Subsystem Tests ===");
    let mut passed = 0;
    let mut total = 0;

    // -----------------------------------------------------------------------
    // Part 1: All 9 permission combos (3 access types x 3 permission trits)
    // access_type: +=READ, 0=WRITE, -=EXEC
    // permission trit: +=allow, 0=conditional, -=deny
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Permission combos (9 combinations) ---");

    // Page with all-allow
    let p_allow = make_page(100, +, +, +);
    // Page with all-conditional
    let p_cond  = make_page(200, 0, 0, 0);
    // Page with all-deny
    let p_deny  = make_page(300, -, -, -);

    // READ + allow -> +
    total = total + 1;
    passed = passed + assert_true(trit_eq(check_access(+, p_allow), +),
        "READ on allow page -> allow(+)", total);

    // READ + conditional -> 0 (CoW)
    total = total + 1;
    passed = passed + assert_true(trit_eq(check_access(+, p_cond), 0),
        "READ on conditional page -> CoW(0)", total);

    // READ + deny -> -
    total = total + 1;
    passed = passed + assert_true(trit_eq(check_access(+, p_deny), -),
        "READ on deny page -> deny(-)", total);

    // WRITE + allow -> +
    total = total + 1;
    passed = passed + assert_true(trit_eq(check_access(0, p_allow), +),
        "WRITE on allow page -> allow(+)", total);

    // WRITE + conditional -> 0 (demand-zero)
    total = total + 1;
    passed = passed + assert_true(trit_eq(check_access(0, p_cond), 0),
        "WRITE on conditional page -> demand-zero(0)", total);

    // WRITE + deny -> -
    total = total + 1;
    passed = passed + assert_true(trit_eq(check_access(0, p_deny), -),
        "WRITE on deny page -> deny(-)", total);

    // EXEC + allow -> +
    total = total + 1;
    passed = passed + assert_true(trit_eq(check_access(-, p_allow), +),
        "EXEC on allow page -> allow(+)", total);

    // EXEC + conditional -> 0 (JIT)
    total = total + 1;
    passed = passed + assert_true(trit_eq(check_access(-, p_cond), 0),
        "EXEC on conditional page -> JIT(0)", total);

    // EXEC + deny -> -
    total = total + 1;
    passed = passed + assert_true(trit_eq(check_access(-, p_deny), -),
        "EXEC on deny page -> deny(-)", total);

    // -----------------------------------------------------------------------
    // Part 2: MST address sign extraction
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- MST address sign extraction ---");

    total = total + 1;
    passed = passed + assert_true(trit_eq(addr_mst(5000), +),
        "addr=5000 -> MST=+ (kernel space)", total);

    total = total + 1;
    passed = passed + assert_true(trit_eq(addr_mst(0), 0),
        "addr=0 -> MST=0 (shared space)", total);

    total = total + 1;
    passed = passed + assert_true(trit_eq(addr_mst(-3000), -),
        "addr=-3000 -> MST=- (user space)", total);

    // -----------------------------------------------------------------------
    // Part 3: Guard page detection (deny all = fault)
    // A guard page has read=-,write=-,exec=- (all deny)
    // Any access type should return deny(-)
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Guard page detection ---");

    let guard = make_page(0, -, -, -);
    let read_denied  = trit_eq(check_access(+, guard), -);
    let write_denied = trit_eq(check_access(0, guard), -);
    let exec_denied  = trit_eq(check_access(-, guard), -);

    total = total + 1;
    passed = passed + assert_true(read_denied, "guard page: READ -> deny (fault)", total);

    total = total + 1;
    passed = passed + assert_true(write_denied, "guard page: WRITE -> deny (fault)", total);

    total = total + 1;
    passed = passed + assert_true(exec_denied, "guard page: EXEC -> deny (fault)", total);

    // All three denied = guard page confirmed
    total = total + 1;
    let is_guard = read_denied && write_denied && exec_denied;
    passed = passed + assert_true(is_guard,
        "all-deny page is guard page (triple fault)", total);

    // -----------------------------------------------------------------------
    // Part 4: Conditional permission paths (CoW, demand-zero, JIT)
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Conditional permission paths ---");

    // CoW page: read=0 (conditional), write=-, exec=-
    let cow_page = make_page(400, 0, -, -);
    total = total + 1;
    let cow_result = check_access(+, cow_page);
    passed = passed + assert_true(trit_eq(cow_result, 0),
        "CoW page READ -> conditional(0), triggers copy", total);

    // Demand-zero page: read=+, write=0 (conditional), exec=-
    let dz_page = make_page(500, +, 0, -);
    total = total + 1;
    let dz_result = check_access(0, dz_page);
    passed = passed + assert_true(trit_eq(dz_result, 0),
        "demand-zero page WRITE -> conditional(0), alloc zeroed", total);

    // JIT page: read=+, write=-, exec=0 (conditional)
    let jit_page = make_page(600, +, -, 0);
    total = total + 1;
    let jit_result = check_access(-, jit_page);
    passed = passed + assert_true(trit_eq(jit_result, 0),
        "JIT page EXEC -> conditional(0), compile first", total);

    // Verify the non-conditional paths on mixed pages
    total = total + 1;
    passed = passed + assert_true(trit_eq(check_access(0, cow_page), -),
        "CoW page WRITE -> deny (not writable)", total);

    total = total + 1;
    passed = passed + assert_true(trit_eq(check_access(+, dz_page), +),
        "demand-zero page READ -> allow (readable)", total);

    total = total + 1;
    passed = passed + assert_true(trit_eq(check_access(+, jit_page), +),
        "JIT page READ -> allow (readable)", total);

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
