// userspace/shell.mt — THATTE-OS interactive ternary shell
// Module 19: Command parser, built-in commands, trit display
//
// Demonstrates P5 Claims:
//   Claim 7  — Full OS in ManiT (user-facing shell)
//   Claim 3  — Privilege-aware prompt
//
// Commands:
//   help     — show available commands
//   ps       — list processes
//   mem      — show memory map
//   priv     — show current privilege
//   echo     — print arguments
//   trit N   — convert integer to balanced ternary
//   dmesg    — show kernel log
//   whoami   — show current user
//   uptime   — show system uptime
//   kill P S — send signal to process
//   stat F   — show file status
//   exit     — exit shell

use std::io;
// str_* helpers come from the ManiT C runtime (str is a type keyword)

// ---------------------------------------------------------------------------
// Shell state
// ---------------------------------------------------------------------------

struct ShellState {
    pub privilege: trit,
    pub username: str,
    pub pid: int,
    pub running: bool,
    pub cmd_count: int,    // commands executed
    pub tick: int,         // current system tick
}

fn shell_init(priv_level: trit, user: str, pid: int) -> ShellState {
    return ShellState {
        privilege: priv_level,
        username: user,
        pid: pid,
        running: true,
        cmd_count: 0,
        tick: 0,
    };
}

// `priv_name` REMOVED, 30 August 2026 — ENHANCEMENT_PLAN §4.
//
// kernel/privilege.mt already had one, and this file's copy answered "KERNEL"
// where that one answers "KERNEL(+1)". They were free to drift because nothing
// ever compiled them together: this module was in NEITHER manifest and was
// built by nothing at all. Adding it to both manifests is what forced the
// question, and the flat namespace is what asked it -- the seventh instance of
// the six `priv_name`s Phase 1.2 deduplicated.

// ---------------------------------------------------------------------------
// Prompt display
// ---------------------------------------------------------------------------

fn print_prompt(state: ShellState) {
    io::print(state.username);
    io::print("@thatteos");
    tif state.privilege {
        + => io::print("# "),    // KERNEL prompt
        0 => io::print("$ "),    // SERVICE prompt
        - => io::print("> "),    // USER prompt
    }
}

// ---------------------------------------------------------------------------
// Built-in commands
// ---------------------------------------------------------------------------

fn cmd_help() {
    io::println("THATTE-OS Shell — Available Commands");
    io::println("====================================");
    io::println("  help          Show this help message");
    io::println("  ps            List processes (9-slot table)");
    io::println("  mem           Show memory map (signed address space)");
    io::println("  priv          Show current privilege level");
    io::println("  echo [text]   Print text to console");
    io::println("  trit [N]      Convert integer N to balanced ternary");
    io::println("  dmesg         Show kernel log (last 9 entries)");
    io::println("  whoami        Show current user and privilege");
    io::println("  uptime        Show system uptime in ticks");
    io::println("  kill [P] [S]  Send signal S to process P");
    io::println("  stat [path]   Show file/inode status");
    io::println("  clear         Clear screen");
    io::println("  exit          Exit shell");
    io::println("");
    io::println("Trit values: + (positive), 0 (zero), - (negative)");
}

// Walks THE process table (§2.0). This printed a five-line fiction: pids 0-4
// with fixed states and names, and "Total: 5/9" whatever the kernel was doing.
fn cmd_ps(t: ProcTable) {
    io::println("  PID  STATE        PRI     RING");
    io::println("  ---  -----------  ------  ---------");
    let mut i = 0;
    while i < 9 {
        if !slot_is_free(slot_at(t, i)) {
            io::print("  ");
            io::print_int(slot_at(t, i).pid);
            io::print("    ");
            io::print(state_name(slot_at(t, i).state));
            io::print("  ");
            io::print(priority_name(slot_at(t, i).priority));
            io::print("  ");
            io::println(priv_name(slot_at(t, i).privilege));
        }
        i = i + 1;
    }
    io::print("  Total: ");
    io::print_int(t.count);
    io::print("/9 processes, ");
    io::print_int(table_live(t));
    io::println(" live");
}

fn cmd_mem() {
    io::println("  Memory Map (T3ISA 27-trit signed address space)");
    io::println("  ================================================");
    io::println("  Region          MST    Range                   Access");
    io::println("  KERNEL-SPACE    +1     +1 .. +3812798742493    KERNEL only");
    io::println("  SHARED-SPACE     0     0                       all levels");
    io::println("  USER-SPACE      -1     -1 .. -3812798742493    all levels");
    io::println("  ================================================");
    io::println("  Page size: 3^9 = 19683 words");
    io::println("  Permissions per page: R/W/X each {-1,0,+1}");
    io::println("    -1=deny  0=conditional(CoW/demand-zero/JIT)  +1=allow");
}

fn cmd_priv(state: ShellState) {
    io::print("  Current privilege: ");
    io::println(priv_name(state.privilege));
    io::print("  Rail: ");
    tif state.privilege {
        + => io::println("VDD (+1)"),
        0 => io::println("GND (0)"),
        - => io::println("VSS (-1)"),
    }
}

fn cmd_whoami(state: ShellState) {
    io::print("  User:      ");
    io::println(state.username);
    io::print("  Privilege: ");
    io::println(priv_name(state.privilege));
    io::print("  PID:       ");
    io::println_int(state.pid);
}

fn cmd_uptime(state: ShellState) {
    io::print("  System uptime: ");
    io::print_int(state.tick);
    io::println(" ticks");
    io::print("  Commands executed: ");
    io::println_int(state.cmd_count);
}

fn cmd_dmesg() {
    io::println("  --- kernel log (last 9 entries) ---");
    io::println("  T=0  [0] [BOOT]  kernel_main: starting boot sequence");
    io::println("  T=1  [0] [IRQ]   interrupt_init: 27 vectors registered");
    io::println("  T=2  [0] [PROC]  process_init: 9-slot table ready");
    io::println("  T=3  [0] [VMEM]  vmem_init: address space mapped");
    io::println("  T=4  [0] [SCALL] syscall_init: 20 handlers registered");
    io::println("  T=5  [0] [TTY]   tty_init: driver loaded at SERVICE");
    io::println("  T=6  [0] [TIMER] timer_init: quantum=3 ticks");
    io::println("  T=7  [0] [LOGIN] user 'user' authenticated");
    io::println("  T=8  [0] [SHELL] shell started, pid=2");
    io::println("  --- end of log ---");
}

fn cmd_trit(n: int) {
    // 9 trits can represent -9841 .. +9841 ((3^9 - 1) / 2); reject anything
    // larger instead of silently printing a truncated, wrong string.
    if n > 9841 || n < -9841 {
        io::print("  trit: ");
        io::print_int(n);
        io::println(" out of 9-trit range (-9841 .. +9841)");
        return;
    }

    io::print("  ");
    io::print_int(n);
    io::print(" in balanced ternary: 0t");

    // Convert to balanced ternary (up to 9 trits)
    let mut val = n;
    let mut digits: [int] = [0, 0, 0, 0, 0, 0, 0, 0, 0];
    let mut pos = 8;

    if val == 0 {
        io::println("0");
        return;
    }

    let negative = val < 0;
    if negative { val = 0 - val; }

    while val > 0 && pos >= 0 {
        let rem = val - (val / 3) * 3;  // val % 3
        if rem == 0 {
            digits[pos] = 0;
        } elif rem == 1 {
            digits[pos] = 1;
        } else {
            // rem == 2 -> trit = -1, carry 1
            digits[pos] = -1;
            val = val + 1;
        }
        val = val / 3;
        pos = pos - 1;
    }

    // If original was negative, negate all trits
    if negative {
        let mut i = 0;
        while i < 9 {
            digits[i] = 0 - digits[i];
            i = i + 1;
        }
    }

    // Print (skip leading zeros)
    let mut started = false;
    let mut i = 0;
    while i < 9 {
        let d = digits[i];
        if d != 0 { started = true; }
        if started {
            if d == 1 { io::print("+"); }
            elif d == -1 { io::print("-"); }
            else { io::print("0"); }
        }
        i = i + 1;
    }
    if !started { io::print("0"); }
    io::println("");
}

// Calls SYS_KILL, which delivers (§2.4). This printed "signal delivered via
// SYS_KILL" and called nothing; its own range checks duplicated the ones
// inside sys_kill, so they are gone too -- the syscall is the authority on
// what a valid pid and signal are.
fn cmd_kill(state: ShellState, t: ProcTable, sigt: SignalTable, bank: ContextBank,
            target_pid: int, signal: int) {
    io::print("  sending signal ");
    io::print_int(signal);
    io::print(" to PID=");
    io::println_int(target_pid);
    let r = sys_kill(state.pid, target_pid, signal, state.privilege, sigt, t, bank);
    tif r {
        + => io::println("  SYS_KILL: delivered"),
        0 => io::println("  SYS_KILL: no action"),
        - => io::println("  SYS_KILL: refused"),
    }
}

// Looks the path up in THE filesystem (§3). This matched four string literals
// and reported `size: 0` for all of them, which was true only because nothing
// could write a file at the time.
fn cmd_stat(fs: TritFS, path: str) {
    io::print("  stat: ");
    io::println(path);
    let mut i = 0;
    while i < 9 {
        if fs_inode_at(fs, i).valid && fs_inode_at(fs, i).name == path {
            sys_stat(fs_inode_at(fs, i));
            return;
        }
        i = i + 1;
    }
    io::println("  ERROR: path not found");
}

fn cmd_clear() {
    // Print 27 blank lines (ternary!)
    let mut i = 0;
    while i < 27 {
        io::println("");
        i = i + 1;
    }
}

// ---------------------------------------------------------------------------
// Tokenizer helpers
// ---------------------------------------------------------------------------

// Return the substring after the first 'n' characters.
// `args_after` REMOVED — it took the number of characters to skip as an
// argument, so every call site hardcoded the length of its own keyword.

// Parse the first space-separated integer from a string.
fn parse_first_int(s: str) -> int {
    let sp = str_find(s, " ");
    if sp < 0 { return str::parse_int(s); }
    return str::parse_int(str::substr(s, 0, sp));
}

// Parse the second space-separated integer from a string like "PID SIG".
fn parse_second_int(s: str) -> int {
    let sp = str_find(s, " ");
    if sp < 0 { return 0; }
    let rest = str::substr(s, sp + 1, str_len(s) - sp - 1);
    return str::parse_int(rest);
}

// ---------------------------------------------------------------------------
// Command dispatch
// ---------------------------------------------------------------------------

// dispatch_command — ONE tokeniser, taken from the hosted shell (§4).
//
// This compared the WHOLE command string against a literal for nine commands
// and then used `str::starts_with(cmd, "trit ")` with a hardcoded skip of five
// characters for the four that take arguments. Two parsing strategies in one
// function, and the second one counts the length of its own keyword by hand:
// `args_after(cmd, 5)` is correct for "trit " and "kill " and silently wrong
// for any command whose name is not four letters.
//
// `thatteos.mt` already had the right shape -- trim, find the first space,
// name before it and arguments after -- so this is that, and `args_after` is
// gone with the two helpers that only existed to serve it.
//
// It MUTATES the state rather than rebuilding it: the two `ShellState`
// literals this function used to end with were the same spelled-out-copy
// hazard as everywhere else, and one of them silently did not advance `tick`.
fn dispatch_command(cmd_raw: str, state: ShellState, t: ProcTable, fs: TritFS,
                    sigt: SignalTable, bank: ContextBank) -> ShellState {
    let cmd = str::trim(cmd_raw);
    io::print("[");
    io::print_int(state.cmd_count);
    io::print("] ");
    print_prompt(state);
    io::println(cmd);

    state.cmd_count = state.cmd_count + 1;
    state.tick = state.tick + 1;

    if cmd == "" {
        return state;
    }

    // Split the verb from its arguments at the first space -- once, for every
    // command, whatever the length of its name.
    let space = str::find(cmd, " ");
    let name = if space == -1 { cmd } else { str::substr(cmd, 0, space) };
    let args = if space == -1 { "" } else {
        str::trim(str::substr(cmd, space + 1, str::len(cmd) - space - 1))
    };

    if name == "help" { cmd_help(); }
    elif name == "ps" { cmd_ps(t); }
    elif name == "mem" { cmd_mem(); }
    elif name == "priv" { cmd_priv(state); }
    elif name == "whoami" { cmd_whoami(state); }
    elif name == "uptime" { cmd_uptime(state); }
    elif name == "dmesg" { cmd_dmesg(); }
    elif name == "clear" { cmd_clear(); }
    elif name == "trit" { cmd_trit(str::parse_int(args)); }
    elif name == "echo" { io::print("  "); io::println(args); }
    elif name == "kill" {
        cmd_kill(state, t, sigt, bank, parse_first_int(args), parse_second_int(args));
    }
    elif name == "stat" { cmd_stat(fs, args); }
    elif name == "exit" {
        io::println("  exit: shell terminating");
        io::println("  SYS_EXIT(0) — process.state = EXITED(-3)");
        state.running = false;
    }
    else {
        io::print("  command not found: ");
        io::println(name);
        io::println("  type 'help' for available commands");
    }

    return state;
}


// ---------------------------------------------------------------------------
// main: demonstrate shell
// ---------------------------------------------------------------------------

