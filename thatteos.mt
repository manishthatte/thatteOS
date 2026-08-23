// thatteos/thatteos.mt — thatteOS Interactive Shell (Target A: Hosted on Linux)
// ============================================================================
// THATTE-OS  v0.3.0  —  Balanced Ternary Microkernel
//
// A real interactive OS shell running on Linux/x86-64.
// Demonstrates the complete thatteOS architecture:
//
//   Privilege:  KERNEL(+1) / SERVICE(0) / USER(-1)
//   IDT:        27 vectors, priority HIGH(+)/MEDIUM(0)/LOW(-)
//   Process:    9-slot PCB table, signed-int process states
//   Memory:     Signed virtual address space (MST-based privilege zones)
//   FS:         TritFS — trit-typed inodes, ternary trie directories
//   Signals:    9 signals SIG_KILL(-4)..SIG_CHLD(+4)
//   CapWord:    9-trit capability word per process
//
// Build:
//   (see build.sh — requires the manitc sibling repo)
//   ./manitc/target/release/manitc compile --target llvm \
//       thatteos/thatteos.mt -o thatteos/thatteos.ll
//   sed 's/ret ptr 0$/ret ptr null/g' thatteos/thatteos.ll > thatteos/thatteos_fixed.ll
//   clang-19 thatteos/thatteos_fixed.ll /tmp/manit_runtime.o -o thatteos/thatteos -lm
//   (see thatteos/build.sh for one-liner)
//
// Note on string functions:
//   ManiT's 'str' is a type keyword, not a usable module prefix.
//   The C runtime exports them as str_len, str_find, str_trim, etc.
//   We call those directly — the codegen mangles str::fn → str_fn anyway.
//
// Author: Manish Jagdish Thatte

use std::io;
use std::fs;
use std::env;

// ============================================================================
// OS state — individual mutable integers (avoids mutable-struct GEP bug)
// Privilege is always USER(-1) for this hosted shell demo.
// ============================================================================

// ============================================================================
// Boot sequence
// ============================================================================

fn boot_banner() {
    io::println("");
    io::println("  +----------------------------------------------------------+");
    io::println("  |          T H A T T E - O S    v 0 . 3 . 0               |");
    io::println("  |          Balanced Ternary Microkernel                    |");
    io::println("  |                                                          |");
    io::println("  |  Privilege: KERNEL(+1) / SERVICE(0) / USER(-1)          |");
    io::println("  |  Authored by Manish Jagdish Thatte                      |");
    io::println("  +----------------------------------------------------------+");
    io::println("");
}

fn boot_sysinfo() {
    io::println("  [BOOT] system:");
    io::print("         host OS:    ");
    io::println(env::os_name());
    io::print("         arch:       ");
    io::println(env::arch());
    io::print("         CPU cores:  ");
    io::println_int(env::cpu_count());
    io::print("         host PID:   ");
    io::println_int(env::pid());
}

fn boot_idt_init() {
    io::println("  [BOOT] interrupt_init: registering 27 IDT vectors");
    io::println("         vector    0   -> priority MEDIUM ( 0) — timer");
    io::println("         vectors  1- 5 -> priority HIGH   (+1) — syscall, faults");
    io::println("         vectors  6-17 -> priority MEDIUM ( 0) — device, IPC, IRQ");
    io::println("         vectors 18-26 -> priority LOW    (-1) — deferred work");
    io::println("         nesting: HIGH preempts MEDIUM/LOW; MEDIUM preempts LOW");
    io::println("  [BOOT] STATUS[24] = +1  — interrupts ENABLED");
}

fn boot_pcb_init() {
    io::println("  [BOOT] process_init: 9-slot PCB table ready");
    io::println("         PID 0  idle       privilege=KERNEL  state=READY(+3)");
    io::println("         PID 1  init       privilege=SERVICE state=EXECUTING");
    io::println("         PID 2  shell      privilege=USER    state=EXECUTING");
    io::println("         PID 3-8 EMPTY");
    io::println("         states: sign>0=ACTIVE  sign=0=DORMANT  sign<0=TERMINAL");
}

fn boot_vmem_init() {
    io::println("  [BOOT] vmem_init: signed virtual address space mapped");
    io::println("         MST>0 (+addr) -> KERNEL zone   (KERNEL privilege required)");
    io::println("         MST=0  (addr=0) -> SHARED zone  (all privilege levels)");
    io::println("         MST<0 (-addr) -> USER zone     (all privilege levels)");
    io::println("         Page size: 3^9 = 19683 words");
    io::println("         Page perms: +1=allow  0=conditional(CoW/demand/JIT)  -1=deny");
}

fn boot_syscall_init() {
    io::println("  [BOOT] syscall_init: 20 handlers registered");
    io::println("         Positive IDs = resource ops (SYS_FORK, SYS_EXEC, SYS_ALLOC...)");
    io::println("         Zero ID      = null/heartbeat");
    io::println("         Negative IDs = I/O ops (SYS_OPEN, SYS_READ, SYS_WRITE...)");
    io::println("         TBRANCH on sign(syscall_id) -> +/0/- dispatch path");
}

fn boot_tty_init() {
    io::println("  [BOOT] tty_init: terminal driver loaded at SERVICE privilege");
    io::println("         /dev/tty  type=DEV(-1)  perm=rwx(+1)");
    io::println("         fd0=stdin  fd1=stdout  fd2=stderr  pre-opened");
}

fn boot_caps_init() {
    io::println("  [BOOT] capability_init: 9-trit CapWord assigned per process");
    io::println("         Trits: CAN_FORK CAN_EXEC CAN_IPC CAN_IO CAN_MOD");
    io::println("                CAN_PRIV CAN_ALLOC CAN_SIGNAL CAN_FS");
    io::println("         Values: GRANTED(+1)  INHERITED(0)  DENIED(-1)");
    io::println("         USER CapWord: +  +  +  -  -  -  +  -  +");
}

fn boot_tritfs_init() {
    io::println("  [BOOT] tritfs_init: TritFS mounted at /");
    io::println("         Inode type:    FILE(+1)  DIR(0)  DEV(-1)");
    io::println("         Directory:     ternary trie, O(key-length) lookup");
    io::println("         Permission:    rwx(+1)  r-x(0)  r--(−1)");
}

fn boot_privilege_descent() {
    io::println("  [BOOT] privilege_descent:");
    io::println("         KERNEL(+1) -> SERVICE(0) -> USER(-1)");
    io::println("         shell PID=2 now executing at USER(-1)");
}

fn boot_sequence() {
    boot_banner();
    boot_sysinfo();
    io::println("");
    boot_idt_init();
    io::println("");
    boot_pcb_init();
    io::println("");
    boot_vmem_init();
    io::println("");
    boot_syscall_init();
    io::println("");
    boot_tty_init();
    io::println("");
    boot_caps_init();
    io::println("");
    boot_tritfs_init();
    io::println("");
    boot_privilege_descent();
    io::println("");
    // Set SDL env vars so spawned GUI apps find the right video/audio driver
    env::set_env("SDL_VIDEODRIVER", "kmsdrm");
    env::set_env("SDL_AUDIODRIVER", "dummy");
    env::set_env("SDL_RENDER_DRIVER", "software");
    io::println("  [BOOT] boot complete.  type 'help' for commands.");
    io::println("");
}

// ============================================================================
// Privilege helpers
// ============================================================================

fn priv_name(p: trit) -> str {
    tif p {
        + => return "KERNEL",
        0 => return "SERVICE",
        - => return "USER",
    }
}

fn priv_prompt_char(p: trit) -> str {
    tif p {
        + => return "# ",
        0 => return "$ ",
        - => return "> ",
    }
}

// ============================================================================
// Balanced ternary conversion
//
// Builds the string left to right by prepending each trit (least significant
// is computed first, prepending produces MSB-first order automatically).
// Avoids static [int] arrays which trigger a codegen bug in the current
// ManiT LLVM backend.
// ============================================================================

fn negate_ternary(s: str) -> str {
    // Swap + and - in a balanced ternary string: "+0-" -> "-0+"
    // Done in two steps through a placeholder to avoid double replacement.
    let s1 = str_replace(s, "+", "T");
    let s2 = str_replace(s1, "-", "+");
    return str_replace(s2, "T", "-");
}

fn to_balanced_ternary(n: int) -> str {
    if n == 0 { return "0"; }

    let mut val = n;
    let negative = val < 0;
    if negative { val = 0 - val; }

    // Build trit string from least significant to most significant.
    // Prepending each trit gives the correct MSB-first order.
    let mut result = "";
    while val > 0 {
        let rem = val - (val / 3) * 3;    // val % 3
        if rem == 0 {
            result = str_concat("0", result);
            val = val / 3;
        } elif rem == 1 {
            result = str_concat("+", result);
            val = val / 3;
        } else {
            // rem == 2: represent as (-1) with carry of 1 to next position
            result = str_concat("-", result);
            val = val / 3 + 1;
        }
    }

    if negative {
        return negate_ternary(result);
    }
    return result;
}

// ============================================================================
// Shell prompt
// ============================================================================

fn print_prompt() {
    io::print("user@thatteos:");
    io::print(env::cwd());
    io::print("> ");
}

// ============================================================================
// Command: help
// ============================================================================

fn cmd_help() {
    io::println("  THATTE-OS Shell  —  Available Commands");
    io::println("  =======================================");
    io::println("");
    io::println("  Filesystem:");
    io::println("    pwd              Print current working directory");
    io::println("    ls   [path]      List directory contents");
    io::println("    cd   <path>      Change working directory");
    io::println("    cat  <file>      Print file contents");
    io::println("    head <f> [N]     Print first N lines of file (default 10)");
    io::println("    wc   <file>      Count lines, words, bytes");
    io::println("    stat <path>      Show file/directory metadata");
    io::println("    touch <file>     Create an empty file");
    io::println("    mkdir <dir>      Create directory (and parents)");
    io::println("    write <f> <txt>  Write text to file (overwrites)");
    io::println("    cp  <src> <dst>  Copy a file");
    io::println("    mv  <src> <dst>  Move/rename a file");
    io::println("    rm  <file>       Remove a file");
    io::println("    find <dir> <n>   Search directory for filename");
    io::println("");
    io::println("  OS / System:");
    io::println("    ps               Ternary process table (9 slots)");
    io::println("    mem              Signed virtual address space layout");
    io::println("    priv             Show current privilege level");
    io::println("    dmesg            Show kernel boot log");
    io::println("    date             Show current date and time");
    io::println("    uptime           Show tick counter and command count");
    io::println("    whoami           Show current user and privilege");
    io::println("    kill <p> <s>     Send signal (PID 0-8, signal -4..+4)");
    io::println("    run  <binary>    Fork and exec a compiled binary");
    io::println("");
    io::println("  Ternary:");
    io::println("    trit <N>         Convert integer N to balanced ternary");
    io::println("    caps             Show per-process 9-trit CapWords");
    io::println("    echo [text]      Print text to stdout");
    io::println("");
    io::println("  Shell:");
    io::println("    clear            Clear screen (27 blank lines)");
    io::println("    help             Show this message");
    io::println("    exit / quit      Exit the shell");
}

// ============================================================================
// Command: pwd
// ============================================================================

fn cmd_pwd() {
    io::println(env::cwd());
}

// ============================================================================
// Command: ls [path]
// ============================================================================

fn cmd_ls(path: str) {
    let target = if path == "" { env::cwd() } else { path };

    if !fs::exists(target) {
        io::print("  ls: no such path: ");
        io::println(target);
        return;
    }
    if fs::is_file(target) {
        io::print("  FILE  ");
        io::print(target);
        io::print("   ");
        io::print_int(fs::file_size(target));
        io::println(" B");
        return;
    }
    if !fs::is_dir(target) {
        io::print("  DEV   ");
        io::println(target);
        return;
    }

    let count = fs_list_dir_open(target);
    io::print("  ");
    io::print(target);
    io::print("/   (");
    io::print_int(count);
    io::println(" entries)");
    io::println("");

    let mut i = 0;
    while i < count {
        let name = fs_list_dir_entry(i);
        let full = path_join(target, name);
        if fs::is_dir(full) {
            io::print("  DIR   ");
            io::println(name);
        } elif fs::is_file(full) {
            io::print("  FILE  ");
            io::print(name);
            io::print("   ");
            io::print_int(fs::file_size(full));
            io::println(" B");
        } else {
            io::print("  DEV   ");
            io::println(name);
        }
        i = i + 1;
    }
}

// ============================================================================
// Command: cd <path>
// ============================================================================

fn cmd_cd(path: str) {
    let target = if path == "" { env::home_dir() } else { path };
    if !fs::exists(target) {
        io::print("  cd: no such directory: ");
        io::println(target);
        return;
    }
    if !fs::is_dir(target) {
        io::print("  cd: not a directory: ");
        io::println(target);
        return;
    }
    env::set_cwd(target);
}

// ============================================================================
// Command: cat <file>
// ============================================================================

fn cmd_cat(path: str) {
    if path == "" {
        io::println("  usage: cat <file>");
        return;
    }
    if !fs::exists(path) {
        io::print("  cat: no such file: ");
        io::println(path);
        return;
    }
    if fs::is_dir(path) {
        io::print("  cat: is a directory: ");
        io::println(path);
        return;
    }
    let content = fs::read_file(path);
    io::print(content);
    if !str::ends_with(content, "\n") { io::println(""); }
}

// ============================================================================
// Command: mkdir <dir>
// ============================================================================

fn cmd_mkdir(path: str) {
    if path == "" {
        io::println("  usage: mkdir <directory>");
        return;
    }
    if fs::exists(path) {
        io::print("  mkdir: already exists: ");
        io::println(path);
        return;
    }
    fs::create_dir_all(path);
    io::print("  mkdir: created: ");
    io::println(path);
}

// ============================================================================
// Command: rm <file>
// ============================================================================

fn cmd_rm(path: str) {
    if path == "" {
        io::println("  usage: rm <file>");
        return;
    }
    if !fs::exists(path) {
        io::print("  rm: no such file: ");
        io::println(path);
        return;
    }
    if fs::is_dir(path) {
        io::print("  rm: is a directory: ");
        io::println(path);
        return;
    }
    fs::remove_file(path);
    io::print("  rm: removed: ");
    io::println(path);
}

// ============================================================================
// Command: touch <file>
// ============================================================================

fn cmd_touch(path: str) {
    if path == "" {
        io::println("  usage: touch <file>");
        return;
    }
    if !fs::exists(path) {
        fs::write_file(path, "");
        io::print("  touch: created: ");
    } else {
        io::print("  touch: exists: ");
    }
    io::println(path);
}

// ============================================================================
// Command: write <file> <content>
// ============================================================================

fn cmd_write(args: str) {
    if args == "" {
        io::println("  usage: write <file> <content>");
        return;
    }
    let space = str_find(args, " ");
    if space == -1 {
        fs::write_file(args, "");
        io::print("  write: created empty: ");
        io::println(args);
        return;
    }
    let filename = str_slice(args, 0, space);
    let content  = str_slice(args, space + 1, str_len(args));
    let with_nl  = str_concat(content, "\n");
    fs::write_file(filename, with_nl);
    io::print("  write: ");
    io::print_int(str_len(with_nl));
    io::print(" bytes -> ");
    io::println(filename);
}

// ============================================================================
// Command: stat <path>
// ============================================================================

fn cmd_stat(path: str) {
    if path == "" {
        io::println("  usage: stat <path>");
        return;
    }
    if !fs::exists(path) {
        io::print("  stat: no such path: ");
        io::println(path);
        return;
    }
    io::print("  Path:   ");
    io::println(path);
    if fs::is_dir(path) {
        io::println("  Type:   DIR   (TritFS inode-type = 0)");
        io::println("  Size:   —");
    } elif fs::is_file(path) {
        io::println("  Type:   FILE  (TritFS inode-type = +1)");
        io::print("  Size:   ");
        io::print_int(fs::file_size(path));
        io::println(" bytes");
    } else {
        io::println("  Type:   DEV   (TritFS inode-type = -1)");
        io::println("  Size:   —");
    }
}

// ============================================================================
// Command: ps
// ============================================================================

fn cmd_ps() {
    io::println("  PID  PRIVILEGE    STATE          PRI   CAPWORD      NAME");
    io::println("  ---  -----------  -------------  ----  -----------  --------");
    io::println("   0   KERNEL (+1)  READY   (+3)   HIGH  +++++++++    idle");
    io::println("   1   SERVICE (0)  EXECUTING      NORM  +++++-+++    init");
    io::println("   2   USER    (-1) EXECUTING      NORM  +++-  -+-+   shell");
    io::println("   3   USER    (-1) IO_WAIT  (0)   LOW   ++0-  --00   worker");
    io::println("   4   USER    (-1) SLEEP   (-2)   NORM  ---0  0000   daemon");
    io::println("   5   ---          EMPTY");
    io::println("   6   ---          EMPTY");
    io::println("   7   ---          EMPTY");
    io::println("   8   ---          EMPTY");
    io::println("");
    io::println("  Process state sign semantics:");
    io::println("    sign > 0  ACTIVE   EXECUTING=+4  READY=+3  YIELDED=+2");
    io::println("    sign = 0  DORMANT  IO_WAIT=0  MSG_WAIT=-1  SLEEP=-2");
    io::println("    sign < 0  TERMINAL EXITED=-3  KILLED=-4  FAULTED=-5");
    io::println("");
    io::println("  CapWord trits: CAN_FORK CAN_EXEC CAN_IPC CAN_IO CAN_MOD");
    io::println("                 CAN_PRIV CAN_ALLOC CAN_SIGNAL CAN_FS");
}

// ============================================================================
// Command: mem
// ============================================================================

fn cmd_mem() {
    io::println("  THATTE-OS Virtual Address Space (27-trit signed)");
    io::println("  ================================================");
    io::println("");
    io::println("  Zone           MST    Address range                Privilege");
    io::println("  ----------     -----  ---------------------------  ---------");
    io::println("  KERNEL-SPACE   +1     +1 .. +3,812,798,742,493    KERNEL(+1) only");
    io::println("  SHARED-SPACE    0     addr = 0                     all levels");
    io::println("  USER-SPACE     -1     -1 .. -3,812,798,742,493    all levels");
    io::println("");
    io::println("  Page size:  3^9 = 19,683 words per page");
    io::println("  Permissions per page (three independent trit fields):");
    io::println("    READ:  +1=allow   0=copy-on-write       -1=deny");
    io::println("    WRITE: +1=allow   0=demand-zero         -1=deny");
    io::println("    EXEC:  +1=allow   0=JIT on first exec   -1=deny");
    io::println("");
    io::println("  Privilege check: sign(addr) vs current_priv trit");
    io::println("    positive_addr && privilege != KERNEL  ->  page fault (IDT vec 2)");
}

// ============================================================================
// Command: priv
// ============================================================================

fn cmd_priv() {
    io::println("  Current privilege:  USER (-1)");
    io::println("  Prompt character:   '> '");
    io::println("");
    io::println("  Three-level ternary privilege:");
    io::println("    KERNEL  (+1)  full hardware access, all caps granted");
    io::println("    SERVICE ( 0)  driver/IPC layer, CAN_PRIV denied");
    io::println("    USER    (-1)  user programs, CAN_IO/MOD/SIGNAL denied");
    io::println("");
    io::println("  Stored as a single trit in the CPU status register.");
    io::println("  Sign determines accessible memory zones and syscall dispatch paths.");
}

// ============================================================================
// Command: trit <N>
// ============================================================================

fn cmd_trit(arg: str) {
    let a = str_trim(arg);
    if a == "" {
        io::println("  usage: trit <integer>");
        io::println("  examples:  trit 42   trit -13   trit 729   trit 0");
        return;
    }
    let n = str::parse_int(a);
    let ternary = to_balanced_ternary(n);
    io::print("  ");
    io::print(a);
    io::print("  =  0t");
    io::print(ternary);
    io::print("   (");
    io::print_int(str_len(ternary));
    io::println(" trits)");
}

// ============================================================================
// Command: whoami
// ============================================================================

fn cmd_whoami() {
    io::println("  User:       user");
    io::println("  Privilege:  USER (-1)");
    io::println("  PID:        2  (shell, USER privilege)");
    io::print("  Host PID:   ");
    io::println_int(env::pid());
    io::print("  CWD:        ");
    io::println(env::cwd());
    io::println("  CapWord:    +  +  +  -  -  -  +  -  +");
    io::println("             FK EX IP IO MD PV AL SG FS");
}

// ============================================================================
// Command: uptime
// ============================================================================

fn cmd_uptime(tick: int, cmd_count: int) {
    io::print("  Ticks elapsed:    ");
    io::println_int(tick);
    io::print("  Commands run:     ");
    io::println_int(cmd_count);
    io::print("  Ternary (ticks):  0t");
    io::println(to_balanced_ternary(tick));
    io::print("  Ternary (cmds):   0t");
    io::println(to_balanced_ternary(cmd_count));
}

// ============================================================================
// Command: dmesg
// ============================================================================

fn cmd_dmesg() {
    io::println("  --- THATTE-OS kernel log ---");
    io::println("  T=0   [KERNEL]  boot_main: starting boot sequence");
    io::println("  T=1   [KERNEL]  interrupt_init: 27 vectors registered");
    io::println("  T=2   [KERNEL]  process_init: 9-slot PCB table ready");
    io::println("  T=3   [KERNEL]  vmem_init: signed address space mapped");
    io::println("  T=4   [KERNEL]  syscall_init: 20 handlers registered");
    io::println("  T=5   [SERVICE] tty_init: /dev/tty driver loaded");
    io::println("  T=6   [SERVICE] tritfs_init: TritFS mounted at /");
    io::println("  T=7   [SERVICE] cap_init: CapWords assigned to all PIDs");
    io::println("  T=8   [SERVICE] ipc_init: message queues (9-slot) ready");
    io::println("  T=9   [USER]    login: user 'user' authenticated");
    io::println("  T=10  [USER]    shell: PID=2 started");
    io::println("  --- end of log ---");
}

// ============================================================================
// Command: echo
// ============================================================================

fn cmd_echo(args: str) {
    io::println(args);
}

// ============================================================================
// Command: kill <pid> <signal>
// ============================================================================

fn signal_name(sig: int) -> str {
    if sig == -4 { return "SIG_KILL (-4): force terminate (uncatchable)"; }
    elif sig == -3 { return "SIG_STOP (-3): suspend process (uncatchable)"; }
    elif sig == -2 { return "SIG_TERM (-2): request graceful exit"; }
    elif sig == -1 { return "SIG_INT  (-1): keyboard interrupt"; }
    elif sig == 0  { return "SIG_NULL  (0): existence probe (no action)"; }
    elif sig == 1  { return "SIG_CONT (+1): resume suspended process"; }
    elif sig == 2  { return "SIG_USR1 (+2): user-defined"; }
    elif sig == 3  { return "SIG_USR2 (+3): user-defined"; }
    elif sig == 4  { return "SIG_CHLD (+4): child state changed"; }
    else           { return "UNKNOWN: outside ternary range -4..+4"; }
}

fn cmd_kill(args: str) {
    if args == "" {
        io::println("  usage: kill <pid> <signal>");
        io::println("  PIDs:    0-8");
        io::println("  Signals: -4 (SIG_KILL) .. +4 (SIG_CHLD)");
        return;
    }
    let space = str_find(args, " ");
    if space == -1 {
        io::println("  kill: missing signal argument");
        io::println("  usage: kill <pid> <signal>");
        return;
    }
    let pid_str = str_slice(args, 0, space);
    let sig_str = str_trim(str_slice(args, space + 1, str_len(args)));
    let pid = str::parse_int(pid_str);
    let sig = str::parse_int(sig_str);

    if pid < 0 || pid > 8 {
        io::println("  kill: PID out of range (valid: 0-8)");
        return;
    }
    if sig < -4 || sig > 4 {
        io::println("  kill: signal out of ternary range (valid: -4..+4)");
        return;
    }

    io::print("  SYS_KILL(pid=");
    io::print_int(pid);
    io::print(", sig=");
    io::print_int(sig);
    io::println(")");
    io::print("  -> ");
    io::println(signal_name(sig));
    io::println("  signal delivered via IDT vector 7");
}

// ============================================================================
// Command: cp <src> <dst>
// ============================================================================

fn cmd_cp(args: str) {
    let space = str_find(args, " ");
    if args == "" || space == -1 {
        io::println("  usage: cp <src> <dst>");
        return;
    }
    let src = str_slice(args, 0, space);
    let dst = str_trim(str_slice(args, space + 1, str_len(args)));
    if !fs::exists(src) {
        io::print("  cp: no such file: ");
        io::println(src);
        return;
    }
    if fs::is_dir(src) {
        io::println("  cp: directory copy not supported (files only)");
        return;
    }
    let ok = fs_copy(src, dst);
    if ok == 1 {
        io::print("  cp: ");
        io::print(src);
        io::print(" -> ");
        io::println(dst);
    } else {
        io::println("  cp: failed");
    }
}

// ============================================================================
// Command: mv <src> <dst>
// ============================================================================

fn cmd_mv(args: str) {
    let space = str_find(args, " ");
    if args == "" || space == -1 {
        io::println("  usage: mv <src> <dst>");
        return;
    }
    let src = str_slice(args, 0, space);
    let dst = str_trim(str_slice(args, space + 1, str_len(args)));
    if !fs::exists(src) {
        io::print("  mv: no such file: ");
        io::println(src);
        return;
    }
    let ok = fs_move(src, dst);
    if ok == 1 {
        io::print("  mv: ");
        io::print(src);
        io::print(" -> ");
        io::println(dst);
    } else {
        io::println("  mv: failed");
    }
}

// ============================================================================
// Command: head <file> [N]   (default 10 lines)
// ============================================================================

fn cmd_head(args: str) {
    if args == "" {
        io::println("  usage: head <file> [lines]");
        return;
    }
    let space = str_find(args, " ");
    let path  = if space == -1 { args } else { str_slice(args, 0, space) };
    let narg  = if space == -1 { "10" } else { str_trim(str_slice(args, space + 1, str_len(args))) };
    let max_lines = str::parse_int(narg);
    if max_lines <= 0 {
        io::print("  head: invalid line count: ");
        io::println(narg);
        return;
    }

    if !fs::exists(path) {
        io::print("  head: no such file: ");
        io::println(path);
        return;
    }
    let content = fs::read_file(path);
    let total   = str_len(content);
    let mut pos    = 0;
    let mut lines  = 0;
    while pos < total && lines < max_lines {
        let nl = str_find(str_slice(content, pos, total), "\n");
        if nl == -1 {
            io::println(str_slice(content, pos, total));
            pos = total;
        } else {
            io::println(str_slice(content, pos, pos + nl));
            pos = pos + nl + 1;
        }
        lines = lines + 1;
    }
}

// ============================================================================
// Command: wc <file>
// ============================================================================

fn cmd_wc(path: str) {
    if path == "" {
        io::println("  usage: wc <file>");
        return;
    }
    if !fs::exists(path) {
        io::print("  wc: no such file: ");
        io::println(path);
        return;
    }
    let content = fs::read_file(path);
    let bytes   = str_len(content);
    let total   = bytes;
    let mut pos   = 0;
    let mut lines = 0;
    let mut words = 0;
    let mut in_word = 0;
    while pos < total {
        let c = str_slice(content, pos, pos + 1);
        if c == "\n" {
            lines = lines + 1;
            in_word = 0;
        } elif c == " " || c == "\t" {
            in_word = 0;
        } else {
            if in_word == 0 {
                words = words + 1;
                in_word = 1;
            }
        }
        pos = pos + 1;
    }
    // A final line without a trailing newline still counts as a line
    if total > 0 && str_slice(content, total - 1, total) != "\n" {
        lines = lines + 1;
    }
    io::print("  lines=");
    io::print_int(lines);
    io::print("  words=");
    io::print_int(words);
    io::print("  bytes=");
    io::print_int(bytes);
    io::print("  ");
    io::println(path);
}

// ============================================================================
// Command: date
// ============================================================================

fn cmd_date() {
    io::print("  ");
    io::println(env_timestamp());
}

// ============================================================================
// Command: find <dir> <name>
// ============================================================================

fn cmd_find(args: str) {
    if args == "" {
        io::println("  usage: find <dir> <name>");
        return;
    }
    let space = str_find(args, " ");
    if space == -1 {
        io::println("  usage: find <dir> <name>");
        return;
    }
    let dir  = str_slice(args, 0, space);
    let name = str_trim(str_slice(args, space + 1, str_len(args)));
    if !fs::exists(dir) {
        io::print("  find: no such directory: ");
        io::println(dir);
        return;
    }
    let count = fs_list_dir_open(dir);
    let mut found = 0;
    let mut i = 0;
    while i < count {
        let entry = fs_list_dir_entry(i);
        if entry == name {
            io::println(path_join(dir, entry));
            found = found + 1;
        }
        i = i + 1;
    }
    if found == 0 {
        io::print("  find: '");
        io::print(name);
        io::println("' not found");
    }
}

// ============================================================================
// Command: run <program>   (fork + exec a compiled binary)
// ============================================================================

fn cmd_run(path: str) {
    if path == "" {
        io::println("  usage: run <path-to-binary>");
        return;
    }
    if !fs::exists(path) {
        io::print("  run: no such file: ");
        io::println(path);
        return;
    }
    io::print("  [RUN] spawning: ");
    io::println(path);
    let exit_code = process_spawn(path);
    io::print("  [RUN] exited: ");
    io::print_int(exit_code);
    if exit_code == 0 {
        io::println("  (success)");
    } else {
        io::println("  (non-zero)");
    }
}

// ============================================================================
// Command: caps
// ============================================================================

fn cmd_caps() {
    io::println("  CapWord (9-trit capability word) per process");
    io::println("  ============================================");
    io::println("  Trits:  CAN_FORK CAN_EXEC CAN_IPC CAN_IO CAN_MOD");
    io::println("          CAN_PRIV CAN_ALLOC CAN_SIGNAL CAN_FS");
    io::println("  Values: GRANTED(+1)  INHERITED(0)  DENIED(-1)");
    io::println("");
    io::println("  PID  NAME    CAPWORD");
    io::println("  ---  ------  ----------------------------");
    io::println("   0   idle    +  +  +  +  +  +  +  +  +   (KERNEL: all granted)");
    io::println("   1   init    +  +  +  +  +  -  +  +  +   (SERVICE: CAN_PRIV denied)");
    io::println("   2   shell   +  +  +  -  -  -  +  -  +   (USER)");
    io::println("");
    io::println("  Attenuation rule: a child CapWord is tmin2(parent, requested) —");
    io::println("  a child can never hold a capability its parent lacks.");
}

// ============================================================================
// Command: clear
// ============================================================================

fn cmd_clear() {
    // 27 blank lines — 3^3, ternary aesthetics
    let mut i = 0;
    while i < 27 {
        io::println("");
        i = i + 1;
    }
}

// ============================================================================
// Command dispatcher
// Returns: 0 = exit  1 = normal command  2 = empty input (tick only)
// ============================================================================

fn dispatch(raw_cmd: str, tick: int, cmd_count: int) -> int {
    let cmd = str_trim(raw_cmd);

    // empty input — just tick
    if cmd == "" { return 2; }

    // split into command name and arguments at the first space
    let space = str_find(cmd, " ");
    let name = if space == -1 { cmd } else { str_slice(cmd, 0, space) };
    let args = if space == -1 { "" } else {
        str_trim(str_slice(cmd, space + 1, str_len(cmd)))
    };

    // dispatch
    if name == "help"    { cmd_help(); }
    elif name == "pwd"   { cmd_pwd(); }
    elif name == "ls"    { cmd_ls(args); }
    elif name == "cd"    { cmd_cd(args); }
    elif name == "cat"   { cmd_cat(args); }
    elif name == "head"  { cmd_head(args); }
    elif name == "wc"    { cmd_wc(args); }
    elif name == "stat"  { cmd_stat(args); }
    elif name == "touch" { cmd_touch(args); }
    elif name == "mkdir" { cmd_mkdir(args); }
    elif name == "write" { cmd_write(args); }
    elif name == "cp"    { cmd_cp(args); }
    elif name == "mv"    { cmd_mv(args); }
    elif name == "rm"    { cmd_rm(args); }
    elif name == "find"  { cmd_find(args); }
    elif name == "ps"    { cmd_ps(); }
    elif name == "mem"   { cmd_mem(); }
    elif name == "priv"  { cmd_priv(); }
    elif name == "trit"  { cmd_trit(args); }
    elif name == "whoami"  { cmd_whoami(); }
    elif name == "uptime"  { cmd_uptime(tick, cmd_count); }
    elif name == "dmesg"   { cmd_dmesg(); }
    elif name == "date"    { cmd_date(); }
    elif name == "echo"    { cmd_echo(args); }
    elif name == "kill"    { cmd_kill(args); }
    elif name == "run"     { cmd_run(args); }
    elif name == "caps"    { cmd_caps(); }
    elif name == "clear"   { cmd_clear(); }
    elif name == "exit" || name == "quit" {
        io::println("  SYS_EXIT(0) — process.state = EXITED(-3)");
        io::println("  Goodbye.");
        return 0;
    } else {
        let ubin = "/usr/local/bin/" + name;
        let bin  = "/bin/" + name;
        if fs::exists(ubin) {
            process_spawn(ubin);
        } elif fs::exists(bin) {
            process_spawn(bin);
        } else {
            io::print("  thatteos: command not found: ");
            io::println(name);
            io::println("  type 'help' for available commands");
        }
    }

    return 1;
}

// ============================================================================
// Main — interactive loop
// ============================================================================

fn main() {
    boot_sequence();

    let mut running   = 1;
    let mut cmd_count = 0;
    let mut tick      = 0;

    while running == 1 {
        print_prompt();
        let raw    = io::read_line();
        let result = dispatch(raw, tick, cmd_count);
        tick = tick + 1;
        if result == 0 {
            running = 0;
        } elif result == 1 {
            cmd_count = cmd_count + 1;
        }
        // result == 2: empty input, tick only (already incremented above)
    }

    io::println("");
    io::println("  THATTE-OS: kernel halt.  All processes exited.");
    io::print("  Final tick:   0t");
    io::println(to_balanced_ternary(tick));
    io::println("  Final state:  EXITED(-3)");
}
