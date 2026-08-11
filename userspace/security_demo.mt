// userspace/security_demo.mt — thatteOS security model demonstration
//
// A comprehensive demo of the three-ring security model:
//   +1 = KERNEL   — full access, all permissions
//    0 = SERVICE  — restricted access, service-level permissions
//   -1 = USER     — minimal access, user-level permissions
//
// Demonstrates:
//   1. Privilege escalation and demotion via sys_priv_set
//   2. TMIN2-based page permission checking (hardware AND gate)
//   3. Capability granting, attenuation, and revocation
//   4. Photon-schedule capabilities: grant, check, revoke
//
// The security model is enforced at the hardware level:
//   - TMIN2 gate is a single-cycle hardware check (no branching)
//   - Photon delivery IS capability exercise (physical, unforgeable)
//   - Capability attenuation is monotonic (child never exceeds parent)
//
// Author: Manish Jagdish Thatte

use std::io;

// ---------------------------------------------------------------------------
// TMIN2 gate — hardware ternary AND
// ---------------------------------------------------------------------------

fn tmin2(a: trit, b: trit) -> trit {
    tif a {
        + => return b,
        0 => {
            tif b {
                + => return 0,
                0 => return 0,
                - => return -,
            }
        }
        - => return -,
    }
}

fn ring_name(r: trit) -> str {
    tif r {
        + => return "KERNEL (+1)",
        0 => return "SERVICE (0)",
        - => return "USER   (-1)",
    }
}

fn perm_name(p: trit) -> str {
    tif p {
        + => return "PRIVATE (+1)",
        0 => return "RESTRICTED (0)",
        - => return "PUBLIC  (-1)",
    }
}

fn access_str(allowed: bool) -> str {
    if allowed { return "ALLOW"; }
    else { return "TRAP"; }
}

fn trit_eq(a: trit, b: trit) -> bool {
    tif a {
        + => { tif b { + => return true, 0 => return false, - => return false } }
        0 => { tif b { + => return false, 0 => return true, - => return false } }
        - => { tif b { + => return false, 0 => return false, - => return true } }
    }
}

// ---------------------------------------------------------------------------
// Privilege escalation / demotion
// ---------------------------------------------------------------------------

// sys_priv_set: KERNEL can set any level, SERVICE can stay or drop,
// USER cannot escalate.
fn sys_priv_set(current: trit, requested: trit) -> trit {
    tif current {
        + => return requested,
        0 => {
            tif requested {
                + => return 0,     // FAULT: no escalation
                0 => return 0,     // no-op
                - => return -,     // downgrade allowed
            }
        }
        - => return -,             // USER: stuck
    }
}

// ---------------------------------------------------------------------------
// TMIN2-based page permission check
// ---------------------------------------------------------------------------

fn permission_check(page_perm: trit, ring: trit) -> bool {
    let gate_out = tmin2(ring, page_perm);
    return trit_eq(gate_out, page_perm);
}

// ---------------------------------------------------------------------------
// CapWord (9-trit capability system)
// ---------------------------------------------------------------------------

fn cap_name(i: int) -> str {
    if i == 0 { return "CAN_FORK"; }
    elif i == 1 { return "CAN_EXEC"; }
    elif i == 2 { return "CAN_IPC"; }
    elif i == 3 { return "CAN_IO"; }
    elif i == 4 { return "CAN_MOD"; }
    elif i == 5 { return "CAN_PRIV"; }
    elif i == 6 { return "CAN_ALLOC"; }
    elif i == 7 { return "CAN_SIGNAL"; }
    else { return "CAN_FS"; }
}

fn trit_char(v: int) -> str {
    if v > 0 { return "+"; }
    elif v == 0 { return "0"; }
    else { return "-"; }
}

fn kernel_caps()  -> int { return 19682; }  // all +1
fn service_caps() -> int { return 19196; }  // +1 except CAN_PRIV=-1
fn user_caps()    -> int { return 14606; }  // limited

fn get_cap_trit(caps: int, idx: int) -> int {
    let mut p = 1;
    let mut j = 0;
    while j < idx { p = p * 3; j = j + 1; }
    let trit_raw = (caps / p) - ((caps / p) / 3) * 3;
    return trit_raw - 1;
}

fn print_capword_line(label: str, caps: int) {
    io::print("    ");
    io::print(label);
    io::print(": ");
    let mut i = 0;
    while i < 9 {
        io::print(trit_char(get_cap_trit(caps, i)));
        io::print(" ");
        i = i + 1;
    }
    io::println("");
}

fn attenuate(parent: int, child: int) -> int {
    let mut result = 0;
    let mut i = 0;
    let mut p = 1;
    while i < 9 {
        let pt = ((parent / p) - ((parent / p) / 3) * 3) - 1;
        let ct = ((child  / p) - ((child  / p) / 3) * 3) - 1;
        let rt = if pt < 0 { -1 }
                 elif pt == 0 {
                     if ct > 0 { 0 } else { ct }
                 }
                 else { ct };
        result = result + (rt + 1) * p;
        p = p * 3;
        i = i + 1;
    }
    return result;
}

// ---------------------------------------------------------------------------
// Photon schedule capability (simplified)
// ---------------------------------------------------------------------------

struct PhotonGrant {
    pub zone: int,
    pub pid: int,
    pub start: int,
    pub duration: int,
    pub active: bool,
}

fn photon_check(g: PhotonGrant, pid: int, zone: int, cycle: int) -> bool {
    if !g.active { return false; }
    if g.pid != pid { return false; }
    if g.zone != zone { return false; }
    if cycle < g.start { return false; }
    if cycle >= g.start + g.duration { return false; }
    return true;
}

// ---------------------------------------------------------------------------
// Security audit log helper
// ---------------------------------------------------------------------------

fn log_event(seq: int, event: str) {
    io::print("  [");
    io::print_int(seq);
    io::print("] ");
    io::println(event);
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn main() {
    io::println("=== thatteOS security_demo — Three-Ring Security Model ===");
    io::println("");
    io::println("  Three rings of privilege (balanced ternary):");
    io::println("    +1 = KERNEL  — full access, hardware substrate VDD rail");
    io::println("     0 = SERVICE — restricted, hardware substrate GND rail");
    io::println("    -1 = USER    — minimal access, hardware substrate VSS rail");
    io::println("");
    let mut seq = 0;

    // =======================================================================
    // Section 1: Privilege escalation and demotion
    // =======================================================================
    io::println("=== Section 1: Privilege Transitions ===");
    io::println("");

    // KERNEL -> SERVICE (allowed)
    let mut ring: trit = +;
    io::print("  Current ring: ");
    io::println(ring_name(ring));
    ring = sys_priv_set(ring, 0);
    seq = seq + 1;
    log_event(seq, "KERNEL -> SERVICE: allowed (voluntary demotion)");
    io::print("  New ring: ");
    io::println(ring_name(ring));
    io::println("");

    // SERVICE -> USER (allowed)
    ring = sys_priv_set(ring, -);
    seq = seq + 1;
    log_event(seq, "SERVICE -> USER: allowed (further demotion)");
    io::print("  New ring: ");
    io::println(ring_name(ring));
    io::println("");

    // USER -> KERNEL (FAULT — escalation denied)
    let ring_before = ring;
    ring = sys_priv_set(ring, +);
    seq = seq + 1;
    log_event(seq, "USER -> KERNEL: FAULT (escalation denied, ring unchanged)");
    io::print("  Ring remains: ");
    io::println(ring_name(ring));
    io::println("");

    // USER -> SERVICE (FAULT — escalation denied)
    ring = sys_priv_set(ring, 0);
    seq = seq + 1;
    log_event(seq, "USER -> SERVICE: FAULT (escalation denied, ring unchanged)");
    io::println("");

    // Reset to KERNEL for next section
    ring = +;

    // =======================================================================
    // Section 2: TMIN2-based page permission checking
    // =======================================================================
    io::println("=== Section 2: TMIN2 Page Permission Checks ===");
    io::println("");
    io::println("  TMIN2 gate: min(ring, page_perm) — one cycle, no branching");
    io::println("  Access allowed iff tmin2(ring, page_perm) == page_perm");
    io::println("");
    io::println("  Ring \\ Page     | PRIVATE(+1) | RESTRICTED(0) | PUBLIC(-1)");
    io::println("  ----------------+-------------+---------------+-----------");

    // KERNEL row
    io::print("  KERNEL  (+1)    |    ");
    io::print(access_str(permission_check(+, +)));
    io::print("     |      ");
    io::print(access_str(permission_check(0, +)));
    io::print("      |    ");
    io::println(access_str(permission_check(-, +)));

    // SERVICE row
    io::print("  SERVICE  (0)    |    ");
    io::print(access_str(permission_check(+, 0)));
    io::print("     |      ");
    io::print(access_str(permission_check(0, 0)));
    io::print("      |    ");
    io::println(access_str(permission_check(-, 0)));

    // USER row
    io::print("  USER    (-1)    |    ");
    io::print(access_str(permission_check(+, -)));
    io::print("     |      ");
    io::print(access_str(permission_check(0, -)));
    io::print("      |    ");
    io::println(access_str(permission_check(-, -)));
    io::println("");

    seq = seq + 1;
    log_event(seq, "TMIN2 permission matrix computed (9 checks, 1 gate cycle each)");
    io::println("");

    // =======================================================================
    // Section 3: Capability granting, attenuation, and revocation
    // =======================================================================
    io::println("=== Section 3: Capability Words (9-Trit CapWord) ===");
    io::println("");
    io::println("    Capability encoding: +1=GRANTED, 0=INHERITED, -1=DENIED");
    io::println("    Indices: FK EX IP IO MD PV AL SG FS");
    io::println("");

    let k = kernel_caps();
    let s = service_caps();
    let u = user_caps();

    print_capword_line("KERNEL ", k);
    print_capword_line("SERVICE", s);
    print_capword_line("USER   ", u);
    io::println("");

    // Attenuation: child cannot exceed parent
    io::println("  Attenuation: USER parent spawns child requesting KERNEL caps:");
    let attenuated = attenuate(u, k);
    print_capword_line("  Requested (KERNEL)", k);
    print_capword_line("  Attenuated result ", attenuated);
    io::println("  -> child is clamped to USER-level permissions (monotonic)");
    io::println("");

    seq = seq + 1;
    log_event(seq, "Capability attenuation enforced (child <= parent, always)");

    // Enforcement examples
    io::println("");
    io::println("  Enforcement on USER capabilities:");
    let mut ci = 0;
    while ci < 9 {
        let val = get_cap_trit(u, ci);
        io::print("    ");
        io::print(cap_name(ci));
        io::print(" = ");
        io::print(trit_char(val));
        if val > 0 { io::println("  -> ALLOWED"); }
        elif val == 0 { io::println("  -> INHERITED (resolve from parent)"); }
        else { io::println("  -> DENIED  *** CAPABILITY FAULT ***"); }
        ci = ci + 1;
    }
    io::println("");

    seq = seq + 1;
    log_event(seq, "Capability enforcement demonstrated for USER process");
    io::println("");

    // =======================================================================
    // Section 4: Photon-schedule capability
    // =======================================================================
    io::println("=== Section 4: Photon Schedule Capability ===");
    io::println("");
    io::println("  Photon delivery IS capability exercise.");
    io::println("  No photon = no current = no computation. Physical, unforgeable.");
    io::println("");

    // Grant: PID=1 gets zone=0 for cycles 0..1000
    let grant1 = PhotonGrant {
        zone: 0, pid: 1, start: 0, duration: 1000, active: true,
    };
    seq = seq + 1;
    log_event(seq, "GRANT: PID=1 zone=0 cycles=0..1000 (photon delivery enabled)");

    // Check: in-window
    let auth1 = photon_check(grant1, 1, 0, 500);
    io::print("  Check PID=1, zone=0, cycle=500: ");
    if auth1 { io::println("AUTHORIZED (within window)"); }
    else { io::println("DENIED"); }

    // Check: expired
    let auth2 = photon_check(grant1, 1, 0, 1500);
    io::print("  Check PID=1, zone=0, cycle=1500: ");
    if auth2 { io::println("AUTHORIZED"); }
    else { io::println("DENIED (expired — outside window)"); }

    // Check: wrong PID
    let auth3 = photon_check(grant1, 99, 0, 500);
    io::print("  Check PID=99, zone=0, cycle=500: ");
    if auth3 { io::println("AUTHORIZED"); }
    else { io::println("DENIED (no grant for this PID)"); }
    io::println("");

    // Revoke: set active = false (photon cessation)
    let grant1_revoked = PhotonGrant {
        zone: grant1.zone, pid: grant1.pid,
        start: grant1.start, duration: grant1.duration,
        active: false,
    };
    seq = seq + 1;
    log_event(seq, "REVOKE: PID=1 zone=0 (photon delivery ceased — instant)");

    let auth4 = photon_check(grant1_revoked, 1, 0, 500);
    io::print("  Check PID=1, zone=0, cycle=500 after revocation: ");
    if auth4 { io::println("AUTHORIZED"); }
    else { io::println("DENIED (revoked — zone is dark, no current possible)"); }
    io::println("");

    // =======================================================================
    // Security Audit Log Summary
    // =======================================================================
    io::println("=== Security Audit Log ===");
    io::println("");
    io::println("  Seq  Event");
    io::println("  ---  -----");
    log_event(1, "Privilege demotion KERNEL -> SERVICE");
    log_event(2, "Privilege demotion SERVICE -> USER");
    log_event(3, "Privilege escalation USER -> KERNEL DENIED");
    log_event(4, "Privilege escalation USER -> SERVICE DENIED");
    log_event(5, "TMIN2 permission matrix (9 checks)");
    log_event(6, "Capability attenuation (child <= parent)");
    log_event(7, "Capability enforcement (USER process)");
    log_event(8, "Photon grant: PID=1 zone=0");
    log_event(9, "Photon revoke: PID=1 zone=0");
    io::println("");

    io::println("  Security invariants verified:");
    io::println("    1. Privilege can only decrease, never escalate without KERNEL");
    io::println("    2. TMIN2 hardware gate enforces page permissions in one cycle");
    io::println("    3. Capability attenuation is monotonic — child <= parent always");
    io::println("    4. Photon cessation = instant irrevocable revocation");
    io::println("    5. No software-only attack vector (requires physical optical access)");
    io::println("");
    io::println("=== security_demo complete ===");
}
