// src/demos/shell.mt — the demonstration for src/userspace/shell.mt
// Author: Manish Jagdish Thatte
// © Manish Jagdish Thatte
//
// Separated from the module on 30 August 2026 (ENHANCEMENT_PLAN §4) for the
// reason every other demo here is separate: the `expect_*` helpers live in
// src/demos/tmin2.mt, which is in the DEMOS manifest only, while
// src/userspace/shell.mt is now in BOTH -- the kernel has to build for T3 and
// a kernel that carries its own test assertions is paying image size for them.

use std::io;

// shell_demo — the kernel-side shell, driven over REAL kernel state.
//
// ENHANCEMENT_PLAN §4. This was `fn main()` replaying a fixed script of
// hardcoded command strings against a shell whose `ps` printed five invented
// processes, whose `kill` printed "delivered" and called nothing, and whose
// `stat` matched four path literals. It was also in NEITHER manifest, so none
// of it was ever compiled by any build in this repository.
//
// It is now in both manifests and every command below reads or writes the same
// structures the rest of the kernel uses: the process table from §2.0, the
// signal layer and capability gate from §2.3/§2.4, and the filesystem from §3.
//
// WHY `thatteos.mt` IS STILL A SEPARATE PROGRAM, measured rather than assumed.
// §4 says "there are two [shells]" and asks for one. They are not two
// implementations of the same thing: `thatteos.mt` drives the HOST filesystem
// -- `fs_copy`, `fs_list_dir_open`, `process_spawn`, `path_join`,
// `env_timestamp` -- and compiling it `--target t3` fails at the assembler
// with `Undefined label: env::os_name`. It cannot run on the target this
// kernel is for. So the duplication that was real has been removed (one
// tokeniser, one `priv_name`, one process table, one filesystem) and the two
// front-ends remain because they address two different machines. Phase 6(a)
// is what would collapse them.
fn shell_demo(t: ProcTable, fs: TritFS, sigt: SignalTable, bank: ContextBank) {
    io::println("=== THATTE-OS Shell ===");
    io::println("Interactive balanced ternary shell, over live kernel state");
    io::println("");

    let mut state = shell_init(-, "user", 2);

    // `ps` over the real table: whatever the caller admitted is what prints.
    state = dispatch_command("ps", state, t, fs, sigt, bank);
    io::println("");
    expect_int("shell: two commands counted after one dispatch", state.cmd_count, 1);

    // The tokeniser, which used to be two strategies. A name of any length now
    // splits the same way -- `whoami` is six characters and the old
    // `args_after(cmd, 5)` would have eaten one of them.
    state = dispatch_command("whoami", state, t, fs, sigt, bank);
    state = dispatch_command("trit 42", state, t, fs, sigt, bank);
    io::println("");

    // `stat` against the REAL filesystem. /dev/tty exists; /nonexistent does
    // not, and the failure now comes from a lookup rather than from falling
    // off the end of four string comparisons.
    state = dispatch_command("stat /dev/tty", state, t, fs, sigt, bank);
    state = dispatch_command("stat /nonexistent", state, t, fs, sigt, bank);
    io::println("");

    // `kill` really delivers -- AND IS REALLY REFUSED. The shell runs as
    // pid 2 at USER(-1), and sys_kill lets a USER process signal only itself.
    // The first version of this block asserted that `kill 3 -2` terminated
    // PID 3 and it does not: the privilege check refuses it, correctly, which
    // is the more interesting row of the two and was found by the assertion
    // failing rather than by reading the code.
    expect_int("shell: PID 3 is EXECUTING before kill", slot_at(t, table_find(t, 3)).state, 4);
    state = dispatch_command("kill 3 -2", state, t, fs, sigt, bank);
    expect_int("shell: USER may not signal another process, PID 3 untouched",
               slot_at(t, table_find(t, 3)).state, 4);

    // ...and the same command aimed at itself goes through, so the refusal
    // above is about the TARGET and not about `kill` being inert.
    expect_int("shell: PID 2 (the shell) is EXECUTING before it signals itself",
               slot_at(t, table_find(t, 2)).state, 4);
    state = dispatch_command("kill 2 -2", state, t, fs, sigt, bank);
    expect_int("shell: a USER process may signal ITSELF — PID 2 is EXITED(-3)",
               slot_at(t, table_find(t, 2)).state, -3);
    io::println("");

    // An unknown verb, and `exit`.
    state = dispatch_command("frobnicate", state, t, fs, sigt, bank);
    expect_bool("shell: an unknown command does not stop the shell", state.running, true);
    state = dispatch_command("exit", state, t, fs, sigt, bank);
    expect_bool("shell: `exit` stops the shell", state.running, false);
    expect_int("shell: every dispatch advanced the tick", state.tick, state.cmd_count);
    io::println("");

    io::println("=== Shell claims checked above ===");
}
