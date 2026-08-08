// userspace/sysinfo.mt — THATTEOS system information utility
//
// Displays comprehensive system information:
//   - THATTEOS version and build info
//   - Memory layout (27-trit address space)
//   - Process table status
//   - TritFS statistics
//   - Security status (ring, capabilities)
//   - System uptime (tick count)
//
// Usage: sysinfo
//
// Author: Manish Jagdish Thatte

use std::io;

// ---------------------------------------------------------------------------
// Version and build info
// ---------------------------------------------------------------------------

fn os_name()    -> str { return "THATTEOS"; }
fn os_version() -> str { return "0.1.0"; }
fn os_build()   -> str { return "2026.08.08-t3isa"; }
fn os_arch()    -> str { return "T3ISA (27-trit balanced ternary)"; }
fn os_author()  -> str { return "Manish Jagdish Thatte"; }
fn os_kernel()  -> str { return "THATTEOS microkernel (ManiT)"; }

// ---------------------------------------------------------------------------
// Memory layout constants (27-trit address space)
// ---------------------------------------------------------------------------
//
// A 27-trit address can represent 3^27 = 7,625,597,484,987 locations.
// The sign of the most significant trit (MST) determines the memory region:
//   MST = +1 -> kernel space (positive addresses)
//   MST =  0 -> shared space (zero-prefix addresses)
//   MST = -1 -> user space   (negative addresses)
//
// Each region is 3^26 = 2,541,865,828,329 trits.

fn mem_total_trits() -> str { return "3^27 = 7,625,597,484,987 trit-addressable locations"; }
fn mem_kernel()      -> str { return "MST(+1): positive addresses — kernel only"; }
fn mem_shared()      -> str { return "MST( 0): zero-prefix — shared (all rings)"; }
fn mem_user()        -> str { return "MST(-1): negative addresses — user space"; }

fn page_size_trits() -> int { return 729; }   // 3^6 = 729 trits per page
fn page_size_name()  -> str { return "3^6 = 729 trits (one ternary page)"; }

fn page_perm_name(p: trit) -> str {
    tif p {
        + => return "PRIVATE    (kernel-only)",
        0 => return "RESTRICTED (kernel + service)",
        - => return "PUBLIC     (all rings)",
    }
}

// ---------------------------------------------------------------------------
// Simulated system state
// ---------------------------------------------------------------------------
//
// In a real system these would be syscalls to the kernel.
// Here we simulate typical state for demonstration.

fn sys_uptime_ticks() -> int { return 314159; }
fn sys_tick_rate_ghz() -> int { return 100; }  // illustrative emulator value

// Process table: 9 slots (balanced ternary: PIDs 0..8)
fn proc_count()  -> int { return 4; }
fn proc_max()    -> int { return 9; }

fn proc_state_name(state: int) -> str {
    if state == 4  { return "RUNNING (+4)"; }
    elif state == 3  { return "READY   (+3)"; }
    elif state == 2  { return "BLOCKED (+2)"; }
    elif state == 1  { return "WAITING (+1)"; }
    elif state == 0  { return "IDLE     (0)"; }
    elif state == -1 { return "PAUSED  (-1)"; }
    elif state == -2 { return "SLEEP   (-2)"; }
    elif state == -3 { return "EXITED  (-3)"; }
    elif state == -4 { return "KILLED  (-4)"; }
    else { return "UNKNOWN"; }
}

fn print_proc(pid: int, name: str, state: int, ring: str) {
    io::print("    PID=");
    io::print_int(pid);
    io::print("  ");
    io::print(name);
    io::print("  ");
    io::print(proc_state_name(state));
    io::print("  ring=");
    io::println(ring);
}

// TritFS state
fn fs_mounted()     -> bool { return true; }
fn fs_total_inodes() -> int { return 729; }   // 3^6
fn fs_used_inodes()  -> int { return 23; }
fn fs_block_size()   -> str { return "3^9 = 19683 trits"; }

// Security state (current shell process)
fn current_ring()   -> str { return "USER (-1)"; }
fn current_pid()    -> int { return 3; }

fn cap_name(i: int) -> str {
    if i == 0 { return "CAN_FORK  "; }
    elif i == 1 { return "CAN_EXEC  "; }
    elif i == 2 { return "CAN_IPC   "; }
    elif i == 3 { return "CAN_IO    "; }
    elif i == 4 { return "CAN_MOD   "; }
    elif i == 5 { return "CAN_PRIV  "; }
    elif i == 6 { return "CAN_ALLOC "; }
    elif i == 7 { return "CAN_SIGNAL"; }
    else        { return "CAN_FS    "; }
}

fn trit_char(v: int) -> str {
    if v > 0  { return "+1 (GRANTED)"; }
    elif v == 0 { return " 0 (INHERITED)"; }
    else      { return "-1 (DENIED)"; }
}

// User capabilities: +1 on fork/exec/ipc/alloc/fs, -1 on io/mod/priv/signal
fn user_cap_val(i: int) -> int {
    if i == 0 { return 1; }      // CAN_FORK: granted
    elif i == 1 { return 1; }    // CAN_EXEC: granted
    elif i == 2 { return 1; }    // CAN_IPC: granted
    elif i == 3 { return -1; }   // CAN_IO: denied
    elif i == 4 { return -1; }   // CAN_MOD: denied
    elif i == 5 { return -1; }   // CAN_PRIV: denied
    elif i == 6 { return 1; }    // CAN_ALLOC: granted
    elif i == 7 { return -1; }   // CAN_SIGNAL: denied
    else { return 1; }           // CAN_FS: granted
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

fn main() {
    io::println("=== sysinfo — THATTEOS System Information ===");
    io::println("");

    // =======================================================================
    // System identity
    // =======================================================================
    io::println("  SYSTEM");
    io::println("  ------");
    io::print("    OS:       ");
    io::print(os_name());
    io::print(" ");
    io::println(os_version());
    io::print("    Build:    ");
    io::println(os_build());
    io::print("    Arch:     ");
    io::println(os_arch());
    io::print("    Kernel:   ");
    io::println(os_kernel());
    io::print("    Author:   ");
    io::println(os_author());
    io::println("");

    // =======================================================================
    // Memory layout
    // =======================================================================
    io::println("  MEMORY");
    io::println("  ------");
    io::print("    Address space: ");
    io::println(mem_total_trits());
    io::println("    Word size:     27 trits (one balanced ternary word)");
    io::print("    Page size:     ");
    io::println(page_size_name());
    io::println("");
    io::println("    Region layout (by MST — most significant trit):");
    io::print("      ");
    io::println(mem_kernel());
    io::print("      ");
    io::println(mem_shared());
    io::print("      ");
    io::println(mem_user());
    io::println("");
    io::println("    Page permissions:");
    io::print("      ");
    io::println(page_perm_name(+));
    io::print("      ");
    io::println(page_perm_name(0));
    io::print("      ");
    io::println(page_perm_name(-));
    io::println("");

    // =======================================================================
    // Process table
    // =======================================================================
    io::println("  PROCESSES");
    io::println("  ---------");
    io::print("    Active: ");
    io::print_int(proc_count());
    io::print("/");
    io::print_int(proc_max());
    io::println(" slots");
    io::println("    PID range: 0..8 (9 slots, balanced ternary addressable)");
    io::println("");
    io::println("    PID   Name          State          Ring");
    io::println("    ---   ----          -----          ----");
    print_proc(0, "kernel       ", 4, "KERNEL (+1)");
    print_proc(1, "init         ", 3, "SERVICE (0)");
    print_proc(2, "photon_sched ", 3, "KERNEL (+1)");
    print_proc(3, "shell        ", 4, "USER   (-1)");
    io::println("    PID=4..8: (empty)");
    io::println("");

    // =======================================================================
    // TritFS statistics
    // =======================================================================
    io::println("  FILESYSTEM (TritFS)");
    io::println("  -------------------");
    io::print("    Mounted:      ");
    if fs_mounted() { io::println("yes"); }
    else { io::println("no"); }
    io::print("    Total inodes: ");
    io::println_int(fs_total_inodes());
    io::print("    Used inodes:  ");
    io::println_int(fs_used_inodes());
    io::print("    Free inodes:  ");
    io::println_int(fs_total_inodes() - fs_used_inodes());
    io::print("    Block size:   ");
    io::println(fs_block_size());
    io::println("    Inode format: balanced ternary trit-trie (Claim 21)");
    io::println("");

    // =======================================================================
    // Security status
    // =======================================================================
    io::println("  SECURITY");
    io::println("  --------");
    io::print("    Current PID:  ");
    io::println_int(current_pid());
    io::print("    Current ring: ");
    io::println(current_ring());
    io::println("");
    io::println("    Capability word (9 trits):");
    let mut i = 0;
    while i < 9 {
        io::print("      [");
        io::print_int(i);
        io::print("] ");
        io::print(cap_name(i));
        io::print("  ");
        io::println(trit_char(user_cap_val(i)));
        i = i + 1;
    }
    io::println("");
    io::println("    Photon schedule: active (zone=0, wavelength channel A)");
    io::println("    TMIN2 gate:      hardware-enforced page permissions");
    io::println("");

    // =======================================================================
    // System uptime
    // =======================================================================
    io::println("  UPTIME");
    io::println("  ------");
    io::print("    Tick count:    ");
    io::println_int(sys_uptime_ticks());
    io::print("    Tick rate:     ");
    io::print_int(sys_tick_rate_ghz());
    io::println(" GHz");
    // uptime = ticks / rate = 314159 / 100e9 = ~3.14 us
    io::println("    Uptime:        ~3.14 us (314159 ticks at illustrative 100 GHz)");
    io::println("    (photon clock: each tick = one AC cycle on SWCNT)");
    io::println("");

    io::println("=== sysinfo complete ===");
}
