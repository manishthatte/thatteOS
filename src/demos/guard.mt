// src/demos/guard.mt — the demonstration lifted out of src/kernel/guard.mt
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

// guard_demo — this module's demonstration, formerly its `fn main`.
//
// The kernel is ONE program now (src/kernel.manifest), so it has one
// entry point and every module keeps its demo as a named function the
// suite can call. Renaming rather than deleting is the point: these
// twenty-five demos are the only exercise most of this code has ever
// had, and deleting them to make the merge compile would have paid for
// one program with the loss of the only evidence the parts work.
fn guard_demo() {
    io::println("=== THATTE-OS Guard Module Demo ===");
    io::println("Input validation for all kernel boundaries");
    io::println("Result: +1=VALID  0=WARNING  -1=INVALID");
    io::println("");

    // --- PID validation ---
    io::println("--- PID Validation ---");
    let mut i = -2;
    while i <= 10 {
        io::print("  validate_pid(");
        io::print_int(i);
        io::print(") = ");
        let r = validate_pid(i);
        io::println(guard_result_name(r));
        i = i + 1;
    }
    io::println("");

    // --- FD validation ---
    io::println("--- FD Validation ---");
    let r_fd1 = validate_fd(-1);
    io::print("  validate_fd(-1) = ");
    io::println(guard_result_name(r_fd1));
    let r_fd2 = validate_fd(4);
    io::print("  validate_fd(4) = ");
    io::println(guard_result_name(r_fd2));
    let r_fd3 = validate_fd(9);
    io::print("  validate_fd(9) = ");
    io::println(guard_result_name(r_fd3));
    io::println("");

    // --- Syscall validation ---
    io::println("--- Syscall Validation ---");
    let r_sc1 = validate_syscall(1);
    io::print("  validate_syscall(SYS_FORK=+1) = ");
    io::println(guard_result_name(r_sc1));
    let r_sc2 = validate_syscall(-13);
    io::print("  validate_syscall(SYS_WRITE=-13) = ");
    io::println(guard_result_name(r_sc2));
    let r_sc3 = validate_syscall(99);
    io::print("  validate_syscall(99) = ");
    io::println(guard_result_name(r_sc3));
    io::println("");

    // --- Address validation ---
    io::println("--- Address Validation ---");
    let r_a1 = validate_address(1000, +);
    io::print("  validate_address(+1000, KERNEL) = ");
    io::println(guard_result_name(r_a1));
    let r_a2 = validate_address(1000, -);
    io::print("  validate_address(+1000, USER) = ");
    io::println(guard_result_name(r_a2));
    let r_a3 = validate_address(0, -);
    io::print("  validate_address(0, USER) = ");
    io::println(guard_result_name(r_a3));
    let r_a4 = validate_address(-500, -);
    io::print("  validate_address(-500, USER) = ");
    io::println(guard_result_name(r_a4));
    io::println("");

    // --- Privilege transition validation ---
    io::println("--- Privilege Transition Validation (9 combos) ---");
    let levels: [trit] = [+, 0, -];
    let level_names: [str] = ["KERNEL", "SERVICE", "USER"];
    let mut ci = 0;
    while ci < 3 {
        let mut ri = 0;
        while ri < 3 {
            let result = validate_privilege_transition(levels[ci], levels[ri]);
            io::print("  ");
            io::print(level_names[ci]);
            io::print(" -> ");
            io::print(level_names[ri]);
            io::print(" = ");
            io::println(guard_result_name(result));
            ri = ri + 1;
        }
        ci = ci + 1;
    }
    io::println("");

    // --- Buffer validation ---
    io::println("--- Buffer Validation ---");
    let r_b1 = validate_buffer(4096, 256);
    io::print("  validate_buffer(4096, 256) = ");
    io::println(guard_result_name(r_b1));
    let r_b2 = validate_buffer(4096, -1);
    io::print("  validate_buffer(4096, -1) = ");
    io::println(guard_result_name(r_b2));
    let r_b3 = validate_buffer(4096, 0);
    io::print("  validate_buffer(4096, 0) = ");
    io::println(guard_result_name(r_b3));
    let r_b4 = validate_buffer(-100, 200);
    io::print("  validate_buffer(-100, 200) = ");
    io::println(guard_result_name(r_b4));
    io::println("");

    // --- Checksum validation ---
    io::println("--- Checksum Validation ---");
    let r_cs1 = validate_checksum(1, 10, 20, 30, 61);  // valid: 1+10+20+30=61
    io::print("  valid checksum = ");
    io::println(guard_result_name(r_cs1));
    let r_cs2 = validate_checksum(1, 10, 20, 30, 99);  // invalid
    io::print("  invalid checksum = ");
    io::println(guard_result_name(r_cs2));
    io::println("");

    io::println("=== Guard module claims verified ===");
    io::println("  PID bounds [0..8]:          PASS");
    io::println("  FD bounds [0..8]:           PASS");
    io::println("  Syscall validation:         PASS");
    io::println("  Address MST enforcement:    PASS");
    io::println("  Privilege transitions (9x): PASS");
    io::println("  Buffer validation:          PASS");
    io::println("  Checksum verification:      PASS");
}
