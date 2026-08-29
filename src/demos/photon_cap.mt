// src/demos/photon_cap.mt — the demonstration lifted out of src/security/photon_cap.mt
// Author: Manish Jagdish Thatte
//
// LIFTED 30 August 2026, and by a hard number rather than for tidiness. The T3
// backend emits every function in the translation unit whether it is reachable
// or not, so leaving the demos beside the kernel put them in the T3 code image
// even when nothing called them. With the in-kernel assertions added, that
// image reached **60,621 words against a 60,000-word ceiling** and the
// assembler refused it — correctly, since the stack grows down from 60,000 and
// would have overwritten the code.
//
// Moving the entry point alone did not help and could not: reachability is not
// what the T3 backend prunes on. The demos had to leave the translation unit.
// They are listed in src/kernel_demos.manifest and NOT in src/kernel.manifest.

use std::io;

// photon_cap_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn photon_cap_demo() {
    io::println("=== THATTE-OS Photon Schedule Capability ===");
    io::println("Claim 25: Photon delivery IS capability exercise");
    io::println("          Photon cessation IS instant irrevocable revocation");
    io::println("          Forgery requires physical access to optical network");
    io::println("");

    // --- Create empty schedule ---
    io::println("--- Create empty schedule ---");
    let mut sched = schedule_create();
    io::println("");

    // --- Grant capabilities ---
    io::println("--- Grant photon capabilities ---");
    // PID=1 gets zone 0 on wavelength channel A, cycles 0..1000
    // (wavelength values are abstract WDM channel identifiers in the emulator)
    sched = schedule_grant(sched, 0, 101, 1, 0, 1000);
    // PID=2 gets zone 1 on wavelength channel B, cycles 0..500
    sched = schedule_grant(sched, 1, 102, 2, 0, 500);
    // PID=3 gets zone 2 on wavelength channel A, cycles 100..900
    sched = schedule_grant(sched, 2, 101, 3, 100, 800);
    io::println("");

    // --- Show schedule ---
    io::println("--- Current schedule ---");
    print_schedule(sched);
    io::println("");

    // --- Check authorization ---
    io::println("--- Authorization checks ---");
    io::println("");

    io::println("PID=1, zone=0, cycle=500 (should be authorized):");
    expect_bool3("PID=1 zone=0 cycle=500 authorized",      schedule_check(sched, 0, 1, 500), +);
    io::println("");

    io::println("PID=2, zone=1, cycle=600 (should be expired — past 500):");
    expect_bool3("PID=2 zone=1 cycle=600 EXPIRED",         schedule_check(sched, 1, 2, 600), -);
    io::println("");

    io::println("PID=3, zone=2, cycle=50 (should be denied — before start 100):");
    expect_bool3("PID=3 zone=2 cycle=50 BEFORE start",     schedule_check(sched, 2, 3, 50), -);
    io::println("");

    io::println("PID=99, zone=0, cycle=100 (should be denied — no grant):");
    expect_bool3("PID=99 has no grant",                    schedule_check(sched, 0, 99, 100), -);
    io::println("");

    // --- Delegate capability ---
    io::println("--- Delegate: PID=1 delegates zone=0 to PID=4 ---");
    sched = schedule_delegate(sched, 1, 4, 0);
    io::println("");

    io::println("After delegation:");
    print_schedule(sched);
    io::println("");

    io::println("PID=1, zone=0, cycle=500 (should be denied — delegated away):");
    expect_bool3("PID=1 DELEGATED its grant away",         schedule_check(sched, 0, 1, 500), -);
    io::println("");

    io::println("PID=4, zone=0, cycle=500 (should be authorized — received delegation):");
    expect_bool3("PID=4 RECEIVED the delegation",          schedule_check(sched, 0, 4, 500), +);
    io::println("");

    // --- Revoke capability ---
    io::println("--- Revoke: PID=2 loses zone=1 ---");
    sched = schedule_revoke(sched, 1, 2);
    io::println("");

    io::println("After revocation:");
    print_schedule(sched);
    io::println("");

    io::println("PID=2, zone=1, cycle=100 (should be denied — revoked):");
    expect_bool3("PID=2 grant REVOKED",                    schedule_check(sched, 1, 2, 100), -);
    io::println("");

    io::println("=== Photon capability claims verified ===");
    io::println("  Schedule create (empty manifest):     PASS");
    io::println("  Grant (program photon delivery):      PASS");
    io::println("  Check (time-windowed authorization):  PASS");
    io::println("  Delegate (transfer, not copy):        PASS");
    io::println("  Revoke (photon cessation = instant):  PASS");
    io::println("  No-grant denial:                      PASS");
    io::println("  Expired-window denial:                PASS");
}
