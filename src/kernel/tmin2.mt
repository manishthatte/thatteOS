// kernel/tmin2.mt — THATTE-OS TMIN2 gate for permission enforcement
// Module: Hardware TMIN2 (ternary AND) gate and three-ring security model
//
// Demonstrates Claims:
//   Claim 4  — TMIN2 gate function (minimum of two trits)
//   Claim 15 — TMIN2-based permission checking in hardware
//
// Three-ring security model (balanced ternary privilege):
//   +1 = KERNEL   — full access, all permissions
//    0 = SERVICE  — restricted access, service-level permissions
//   -1 = USER     — minimal access, user-level permissions
//
// Page permission encoding:
//   +1 = PRIVATE    — kernel-only page
//    0 = RESTRICTED — kernel + service access
//   -1 = PUBLIC     — accessible to all rings
//
// The TMIN2 gate returns min(a, b). In balanced ternary, min acts as
// logical AND: the result can never exceed the lesser of the two inputs.
// This is the hardware primitive for permission intersection — if either
// the ring or the page permission is restrictive, the result is restrictive.

use std::io;


// ---------------------------------------------------------------------------
// Demo assertions — shared by every module in src/kernel.manifest
// ---------------------------------------------------------------------------
//
// These live in the first module the manifest lists, so the whole kernel can
// reach them.
//
// They exist because the twenty-five module demos were printing verdicts they
// never read. Thirty-seven `let` bindings across eight modules took the result
// of a predicate — `permission_check`, `can_access`, `enforce`, `sys_kill`,
// `schedule_check` — and dropped it, while the demo ended with hardcoded lines
// like "KERNEL accesses all pages: PASS". The predicate printed something as a
// side effect, so the demo LOOKED like it was checking. It was narrating.
//
// An unread verdict is not a check, and a PASS that is a string literal is not
// a result. Stating the claim beside the answer is the cheap design that makes
// a demo worth running (ENHANCEMENT_PLAN.md §5.3).





// ---------------------------------------------------------------------------
// tmin2: hardware TMIN2 gate — returns the minimum of two trits
// ---------------------------------------------------------------------------
//
// Truth table (balanced ternary min):
//
//   a \ b  |  +1  |   0  |  -1
//   -------+------+------+------
//    +1    |  +1  |   0  |  -1
//     0    |   0  |   0  |  -1
//    -1    |  -1  |  -1  |  -1
//
// This IS the ternary AND gate. One gate, one clock cycle, no branching.

fn tmin2(a: trit, b: trit) -> trit {
    // Evaluate a first
    tif a {
        + => {
            // a = +1: result is b (since min(+1, b) = b for all b)
            return b;
        }
        0 => {
            // a = 0: result is min(0, b)
            tif b {
                + => return 0,
                0 => return 0,
                - => return -,
            }
        }
        - => {
            // a = -1: result is always -1 (nothing is less than -1)
            return -;
        }
    }
}

// ---------------------------------------------------------------------------
// Ring and permission name helpers
// ---------------------------------------------------------------------------

fn ring_name(r: trit) -> str {
    tif r {
        + => return "KERNEL (+1)",
        0 => return "SERVICE (0)",
        - => return "USER   (-1)",
    }
}

// Renamed from `perm_name` in the 30 Aug merge. Five modules defined that
// name and they meant three different things: the fs layer's UNIX-ish
// permission bits ("rwx"), this module's memory ZONE class, and
// mm/pgtable.mt's page-fault ACTION. They were never one function that had
// been copied — they were three functions wearing one name, which is only
// possible while nothing compiles them together.
fn zone_name(p: trit) -> str {
    tif p {
        + => return "PRIVATE (+1)",
        0 => return "RESTRICTED (0)",
        - => return "PUBLIC  (-1)",
    }
}

fn bool3_name(v: bool3) -> str {
    tif v {
        + => return "TRUE (+1)",
        0 => return "MAYBE (0)",
        - => return "FALSE (-1)",
    }
}

// ---------------------------------------------------------------------------
// permission_check: TMIN2-based page access control
// ---------------------------------------------------------------------------
//
// Compares the current ring against the page permission using tmin2.
// If tmin2(ring, page_perm) == page_perm, the ring is at or above the
// required level. If tmin2 < page_perm, the ring is below — trap.
//
//   ring=KERNEL(+1), page=PRIVATE(+1)    -> min=+1, +1==+1 -> ALLOW
//   ring=SERVICE(0), page=PRIVATE(+1)    -> min= 0,  0!=+1 -> TRAP
//   ring=USER(-1),   page=RESTRICTED(0)  -> min=-1, -1!= 0 -> TRAP
//   ring=SERVICE(0), page=RESTRICTED(0)  -> min= 0,  0== 0 -> ALLOW
//   ring=USER(-1),   page=PUBLIC(-1)     -> min=-1, -1==-1 -> ALLOW

fn permission_check(page_perm: trit, ring: trit) -> bool3 {
    let gate_out = tmin2(ring, page_perm);

    io::print("  permission_check: ring=");
    io::print(ring_name(ring));
    io::print("  page=");
    io::print(zone_name(page_perm));
    io::print("  tmin2=");
    io::print_trit(gate_out);

    // Access allowed iff tmin2(ring, page_perm) == page_perm
    // i.e. the ring did not pull the result below the required level
    tif gate_out {
        + => {
            tif page_perm {
                + => { io::println("  -> ALLOW"); return +; }
                0 => { io::println("  -> TRAP (ring below page)"); return -; }
                - => { io::println("  -> TRAP (ring below page)"); return -; }
            }
        }
        0 => {
            tif page_perm {
                + => { io::println("  -> TRAP (ring below page)"); return -; }
                0 => { io::println("  -> ALLOW"); return +; }
                - => { io::println("  -> TRAP (ring below page)"); return -; }
            }
        }
        - => {
            tif page_perm {
                + => { io::println("  -> TRAP (ring below page)"); return -; }
                0 => { io::println("  -> TRAP (ring below page)"); return -; }
                - => { io::println("  -> ALLOW"); return +; }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// can_access: returns true (+1) if current ring >= required permission
// ---------------------------------------------------------------------------
//
// Simplified check: is the caller's ring at least as privileged as
// the required level? Uses tmin2 internally — if min(current, required)
// equals required, then current >= required.

fn can_access(required: trit, current: trit) -> bool3 {
    let gate_out = tmin2(current, required);

    io::print("  can_access: required=");
    io::print(zone_name(required));
    io::print("  current=");
    io::print(ring_name(current));

    // current >= required iff tmin2(current, required) == required
    tif gate_out {
        + => {
            tif required {
                + => { io::println("  -> TRUE (access granted)"); return +; }
                0 => { io::println("  -> FALSE (insufficient privilege)"); return -; }
                - => { io::println("  -> FALSE (insufficient privilege)"); return -; }
            }
        }
        0 => {
            tif required {
                + => { io::println("  -> FALSE (insufficient privilege)"); return -; }
                0 => { io::println("  -> TRUE (access granted)"); return +; }
                - => { io::println("  -> FALSE (insufficient privilege)"); return -; }
            }
        }
        - => {
            tif required {
                + => { io::println("  -> FALSE (insufficient privilege)"); return -; }
                0 => { io::println("  -> FALSE (insufficient privilege)"); return -; }
                - => { io::println("  -> TRUE (access granted)"); return +; }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// main: demonstrate TMIN2 gate and three-ring permission model
// ---------------------------------------------------------------------------
