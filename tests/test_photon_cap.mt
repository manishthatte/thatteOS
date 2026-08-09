// test_photon_cap.mt — THATTE-OS photon capability tests
// Tests schedule creation, granting, time-windowed authorization,
// revocation, delegation, denial, and multiple grants.
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
// Reproduced from security/photon_cap.mt (minimal, no I/O side-effects)
// ---------------------------------------------------------------------------

struct PhotonCapEntry {
    pub zone_id: t9,
    pub wavelength_nm: t9,
    pub start_cycle: word,
    pub duration_cycles: word,
    pub target_pid: t9,
}

fn empty_entry() -> PhotonCapEntry {
    return PhotonCapEntry {
        zone_id: 0, wavelength_nm: 0,
        start_cycle: 0, duration_cycles: 0, target_pid: 0,
    };
}

struct PhotonSchedule {
    pub e0: PhotonCapEntry, pub e1: PhotonCapEntry, pub e2: PhotonCapEntry,
    pub e3: PhotonCapEntry, pub e4: PhotonCapEntry, pub e5: PhotonCapEntry,
    pub e6: PhotonCapEntry, pub e7: PhotonCapEntry, pub e8: PhotonCapEntry,
    pub count: t9,
}

fn schedule_create() -> PhotonSchedule {
    return PhotonSchedule {
        e0: empty_entry(), e1: empty_entry(), e2: empty_entry(),
        e3: empty_entry(), e4: empty_entry(), e5: empty_entry(),
        e6: empty_entry(), e7: empty_entry(), e8: empty_entry(),
        count: 0,
    };
}

fn get_entry(s: PhotonSchedule, idx: int) -> PhotonCapEntry {
    if idx == 0 { return s.e0; }
    elif idx == 1 { return s.e1; }
    elif idx == 2 { return s.e2; }
    elif idx == 3 { return s.e3; }
    elif idx == 4 { return s.e4; }
    elif idx == 5 { return s.e5; }
    elif idx == 6 { return s.e6; }
    elif idx == 7 { return s.e7; }
    elif idx == 8 { return s.e8; }
    else { return empty_entry(); }
}

fn set_entry(s: PhotonSchedule, idx: int, e: PhotonCapEntry) -> PhotonSchedule {
    return PhotonSchedule {
        e0: if idx == 0 { e } else { s.e0 },
        e1: if idx == 1 { e } else { s.e1 },
        e2: if idx == 2 { e } else { s.e2 },
        e3: if idx == 3 { e } else { s.e3 },
        e4: if idx == 4 { e } else { s.e4 },
        e5: if idx == 5 { e } else { s.e5 },
        e6: if idx == 6 { e } else { s.e6 },
        e7: if idx == 7 { e } else { s.e7 },
        e8: if idx == 8 { e } else { s.e8 },
        count: s.count,
    };
}

fn schedule_grant(s: PhotonSchedule, zone: t9, wavelength: t9,
                  pid: t9, start: word, duration: word) -> PhotonSchedule {
    let idx: int = s.count;
    if idx >= 9 { return s; }

    let entry = PhotonCapEntry {
        zone_id: zone, wavelength_nm: wavelength,
        start_cycle: start, duration_cycles: duration, target_pid: pid,
    };

    let s2 = set_entry(s, idx, entry);
    return PhotonSchedule {
        e0: s2.e0, e1: s2.e1, e2: s2.e2,
        e3: s2.e3, e4: s2.e4, e5: s2.e5,
        e6: s2.e6, e7: s2.e7, e8: s2.e8,
        count: idx + 1,
    };
}

fn schedule_check(s: PhotonSchedule, zone: t9, pid: t9, cycle: word) -> bool3 {
    let mut i = 0;
    while i < 9 {
        let e = get_entry(s, i);
        if e.zone_id == zone tand e.target_pid == pid {
            if cycle >= e.start_cycle tand cycle < e.start_cycle + e.duration_cycles {
                return +;
            } else {
                return -;
            }
        }
        i = i + 1;
    }
    return -;
}

fn schedule_revoke(s: PhotonSchedule, zone: t9, pid: t9) -> PhotonSchedule {
    let mut result = s;
    let mut i = 0;
    while i < 9 {
        let e = get_entry(result, i);
        if e.zone_id == zone tand e.target_pid == pid {
            result = set_entry(result, i, empty_entry());
        }
        i = i + 1;
    }
    return result;
}

fn schedule_delegate(s: PhotonSchedule, from_pid: t9, to_pid: t9,
                     zone: t9) -> PhotonSchedule {
    let mut result = s;
    let mut i = 0;
    while i < 9 {
        let e = get_entry(result, i);
        if e.zone_id == zone tand e.target_pid == from_pid {
            let delegated = PhotonCapEntry {
                zone_id: e.zone_id, wavelength_nm: e.wavelength_nm,
                start_cycle: e.start_cycle, duration_cycles: e.duration_cycles,
                target_pid: to_pid,
            };
            result = set_entry(result, i, delegated);
        }
        i = i + 1;
    }
    return result;
}

fn is_authorized(v: bool3) -> bool {
    tif v { + => return true, 0 => return false, - => return false }
}

fn is_denied(v: bool3) -> bool {
    tif v { + => return false, 0 => return false, - => return true }
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn main() {
    io::println("=== THATTE-OS Photon Capability Tests ===");
    let mut passed = 0;
    let mut total = 0;

    // -----------------------------------------------------------------------
    // Part 1: Schedule creation (empty)
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Schedule creation ---");

    let sched = schedule_create();

    total = total + 1;
    passed = passed + assert_true(sched.count == 0,
        "empty schedule has count 0", total);

    total = total + 1;
    let e0 = get_entry(sched, 0);
    passed = passed + assert_true(e0.duration_cycles == 0,
        "empty schedule entry has zero duration", total);

    // -----------------------------------------------------------------------
    // Part 2: Granting capabilities to specific zones/PIDs
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Granting capabilities ---");

    // Grant PID=1 zone 0 at wavelength channel A, cycles 0..1000
    let mut s = schedule_grant(sched, 0, 101, 1, 0, 1000);

    total = total + 1;
    passed = passed + assert_true(s.count == 1,
        "schedule count is 1 after first grant", total);

    total = total + 1;
    let g0 = get_entry(s, 0);
    passed = passed + assert_true(g0.zone_id == 0 && g0.target_pid == 1,
        "first grant: zone=0, pid=1", total);

    total = total + 1;
    passed = passed + assert_true(g0.wavelength_nm == 101,
        "first grant: wavelength=wavelength channel A", total);

    total = total + 1;
    passed = passed + assert_true(g0.start_cycle == 0 && g0.duration_cycles == 1000,
        "first grant: cycles 0..1000", total);

    // Grant PID=2 zone 1 at wavelength channel B, cycles 100..600
    s = schedule_grant(s, 1, 102, 2, 100, 500);

    total = total + 1;
    passed = passed + assert_true(s.count == 2,
        "schedule count is 2 after second grant", total);

    // -----------------------------------------------------------------------
    // Part 3: Time-windowed authorization (in-window vs expired)
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Time-windowed authorization ---");

    // PID=1, zone=0, cycle=500 (within 0..1000) -> AUTHORIZED
    total = total + 1;
    passed = passed + assert_true(is_authorized(schedule_check(s, 0, 1, 500)),
        "PID=1 zone=0 cycle=500 -> AUTHORIZED (in window)", total);

    // PID=1, zone=0, cycle=0 (start boundary) -> AUTHORIZED
    total = total + 1;
    passed = passed + assert_true(is_authorized(schedule_check(s, 0, 1, 0)),
        "PID=1 zone=0 cycle=0 -> AUTHORIZED (start boundary)", total);

    // PID=1, zone=0, cycle=999 (last valid cycle) -> AUTHORIZED
    total = total + 1;
    passed = passed + assert_true(is_authorized(schedule_check(s, 0, 1, 999)),
        "PID=1 zone=0 cycle=999 -> AUTHORIZED (end boundary)", total);

    // PID=1, zone=0, cycle=1000 (expired — past end) -> DENIED
    total = total + 1;
    passed = passed + assert_true(is_denied(schedule_check(s, 0, 1, 1000)),
        "PID=1 zone=0 cycle=1000 -> DENIED (expired)", total);

    // PID=2, zone=1, cycle=50 (before start 100) -> DENIED
    total = total + 1;
    passed = passed + assert_true(is_denied(schedule_check(s, 1, 2, 50)),
        "PID=2 zone=1 cycle=50 -> DENIED (before start)", total);

    // PID=2, zone=1, cycle=300 (within 100..600) -> AUTHORIZED
    total = total + 1;
    passed = passed + assert_true(is_authorized(schedule_check(s, 1, 2, 300)),
        "PID=2 zone=1 cycle=300 -> AUTHORIZED (in window)", total);

    // -----------------------------------------------------------------------
    // Part 4: Capability revocation (instant)
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Revocation ---");

    let s_revoked = schedule_revoke(s, 1, 2);

    // PID=2 zone=1 should now be denied even at valid cycle
    total = total + 1;
    passed = passed + assert_true(is_denied(schedule_check(s_revoked, 1, 2, 300)),
        "PID=2 zone=1 cycle=300 -> DENIED (revoked, photons ceased)", total);

    // PID=1 zone=0 should still be authorized (unaffected by PID=2 revocation)
    total = total + 1;
    passed = passed + assert_true(is_authorized(schedule_check(s_revoked, 0, 1, 500)),
        "PID=1 zone=0 still AUTHORIZED after PID=2 revocation", total);

    // -----------------------------------------------------------------------
    // Part 5: Capability delegation (transfer from one PID to another)
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Delegation ---");

    // Delegate PID=1's zone=0 access to PID=3
    let s_delegated = schedule_delegate(s, 1, 3, 0);

    // PID=1 should now be denied (delegated away)
    total = total + 1;
    passed = passed + assert_true(is_denied(schedule_check(s_delegated, 0, 1, 500)),
        "PID=1 zone=0 -> DENIED (delegated to PID=3)", total);

    // PID=3 should now be authorized (received delegation)
    total = total + 1;
    passed = passed + assert_true(is_authorized(schedule_check(s_delegated, 0, 3, 500)),
        "PID=3 zone=0 -> AUTHORIZED (received delegation)", total);

    // -----------------------------------------------------------------------
    // Part 6: Denial when no grant exists
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- No-grant denial ---");

    // PID=99 has no grant at all
    total = total + 1;
    passed = passed + assert_true(is_denied(schedule_check(s, 0, 99, 100)),
        "PID=99 zone=0 -> DENIED (no grant exists)", total);

    // Valid PID but wrong zone
    total = total + 1;
    passed = passed + assert_true(is_denied(schedule_check(s, 5, 1, 500)),
        "PID=1 zone=5 -> DENIED (no grant for that zone)", total);

    // -----------------------------------------------------------------------
    // Part 7: Multiple grants to same zone for different PIDs
    // -----------------------------------------------------------------------
    io::println("");
    io::println("--- Multiple grants, same zone ---");

    let mut sm = schedule_create();
    sm = schedule_grant(sm, 0, 101, 1, 0, 1000);
    sm = schedule_grant(sm, 0, 101, 2, 0, 1000);

    total = total + 1;
    passed = passed + assert_true(is_authorized(schedule_check(sm, 0, 1, 500)),
        "PID=1 zone=0 AUTHORIZED (multi-grant)", total);

    total = total + 1;
    passed = passed + assert_true(is_authorized(schedule_check(sm, 0, 2, 500)),
        "PID=2 zone=0 AUTHORIZED (multi-grant)", total);

    // Revoke PID=1 only; PID=2 unaffected
    let sm_r = schedule_revoke(sm, 0, 1);

    total = total + 1;
    passed = passed + assert_true(is_denied(schedule_check(sm_r, 0, 1, 500)),
        "PID=1 revoked; PID=2 still has zone=0 grant", total);

    total = total + 1;
    passed = passed + assert_true(is_authorized(schedule_check(sm_r, 0, 2, 500)),
        "PID=2 zone=0 still AUTHORIZED after PID=1 revocation", total);

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
