// kernel/guard.mt — THATTE-OS input validation and safety guards
// Module 12: Boundary validation for all kernel subsystems
//
// Demonstrates P5 Claims:
//   Claim 4  — Defensive syscall validation
//   Claim 9  — Address enforcement via MST
//
// Design: Every validator returns a trit:
//   +1 = valid (proceed)
//    0 = warning (proceed with caution)
//   -1 = invalid (reject, fault)

use std::io;

// ---------------------------------------------------------------------------
// Constants (ternary-native sizes)
// ---------------------------------------------------------------------------

// Max PID = 8 (9 slots: 0..8)
// Max FD  = 8 (9 file descriptors per process)
// Max syscall magnitude = 13
// Page size = 19683 (3^9)
// Max queue depth = 9

// ---------------------------------------------------------------------------
// validate_pid: check process ID within bounds [0..8]
// ---------------------------------------------------------------------------

fn validate_pid(pid: int) -> trit {
    if pid < 0 {
        io::println("  [GUARD] pid < 0 — INVALID");
        return -;
    }
    elif pid > 8 {
        io::println("  [GUARD] pid > 8 — INVALID (exceeds 9-slot table)");
        return -;
    }
    elif pid == 0 {
        // PID 0 is the idle/kernel process — warn if used by userspace
        return 0;
    }
    else {
        return +;
    }
}

// ---------------------------------------------------------------------------
// validate_fd: file descriptor within bounds [0..8]
// ---------------------------------------------------------------------------

fn validate_fd(fd: int) -> trit {
    if fd < 0 {
        io::println("  [GUARD] fd < 0 — INVALID");
        return -;
    }
    elif fd > 8 {
        io::println("  [GUARD] fd > 8 — INVALID (exceeds 9-slot FD table)");
        return -;
    }
    else {
        return +;
    }
}

// ---------------------------------------------------------------------------
// validate_syscall: check syscall number is a known value
// ---------------------------------------------------------------------------

fn is_known_syscall(num: int) -> bool {
    // Positive syscalls: +1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11
    if num == 1 { return true; }   // SYS_FORK
    elif num == 2 { return true; } // SYS_EXEC
    elif num == 3 { return true; } // SYS_EXIT
    elif num == 4 { return true; } // SYS_KILL (new)
    elif num == 5 { return true; } // SYS_ALLOC
    elif num == 6 { return true; } // SYS_FREE
    elif num == 7 { return true; } // SYS_SLEEP (new)
    elif num == 8 { return true; } // SYS_STAT (new)
    elif num == 9 { return true; } // SYS_SIGNAL (new)
    elif num == 10 { return true; } // SYS_MOD_LOAD
    elif num == 11 { return true; } // SYS_MOD_UNLOAD
    // Null syscall
    elif num == 0 { return true; }  // SYS_NULL
    // Negative syscalls: -1,-2,-4,-5,-10,-11,-12,-13
    elif num == -1 { return true; }  // SYS_YIELD
    elif num == -2 { return true; }  // SYS_PRIV_SET
    elif num == -4 { return true; }  // SYS_RECV
    elif num == -5 { return true; }  // SYS_SEND
    elif num == -10 { return true; } // SYS_CLOSE
    elif num == -11 { return true; } // SYS_OPEN
    elif num == -12 { return true; } // SYS_READ
    elif num == -13 { return true; } // SYS_WRITE
    else { return false; }
}

fn validate_syscall(num: int) -> trit {
    if is_known_syscall(num) {
        return +;
    } else {
        io::print("  [GUARD] unknown syscall number: ");
        io::println_int(num);
        return -;
    }
}

// ---------------------------------------------------------------------------
// validate_address: MST-based privilege enforcement
// ---------------------------------------------------------------------------

fn validate_address(addr: int, priv_level: trit) -> trit {
    // MST = sign(addr): +1=kernel, 0=shared, -1=user
    let mst: trit = if addr > 0 { + }
                     elif addr < 0 { - }
                     else { 0 };

    tif mst {
        + => {
            // Kernel space — only KERNEL can access
            tif priv_level {
                + => return +,
                0 => {
                    io::println("  [GUARD] SERVICE cannot access kernel-space — DENIED");
                    return -;
                }
                - => {
                    io::println("  [GUARD] USER cannot access kernel-space — DENIED");
                    return -;
                }
            }
        }
        0 => {
            // Shared space — all can access, but warn on exact address 0
            if addr == 0 {
                io::println("  [GUARD] null address access — WARNING");
                return 0;
            }
            return +;
        }
        - => {
            // User space — all can access
            return +;
        }
    }
}

// ---------------------------------------------------------------------------
// validate_buffer: check buffer address and length
// ---------------------------------------------------------------------------

fn validate_buffer(addr: int, len: int) -> trit {
    if len < 0 {
        io::println("  [GUARD] negative buffer length — INVALID");
        return -;
    }
    elif len == 0 {
        io::println("  [GUARD] zero-length buffer — WARNING");
        return 0;
    }
    // The buffer [addr, addr+len) must stay within one MST zone: a buffer
    // that starts in user space (addr < 0) and ends at/after the MST
    // boundary would span into shared/kernel space.
    let end = addr + len - 1;
    if addr < 0 && end >= 0 {
        io::println("  [GUARD] buffer crosses MST boundary (user -> kernel) — INVALID");
        return -;
    }
    if addr == 0 && end > 0 {
        io::println("  [GUARD] buffer crosses MST boundary (shared -> kernel) — INVALID");
        return -;
    }
    if len > 19683 {
        io::println("  [GUARD] buffer exceeds page size (3^9) — WARNING");
        return 0;
    }
    return +;
}

// ---------------------------------------------------------------------------
// validate_privilege_transition: check if transition is legal
// ---------------------------------------------------------------------------

fn validate_privilege_transition(current: trit, requested: trit) -> trit {
    tif current {
        + => {
            // KERNEL can go anywhere
            return +;
        }
        0 => {
            // SERVICE can only drop to USER or stay
            tif requested {
                + => {
                    io::println("  [GUARD] SERVICE cannot escalate to KERNEL — DENIED");
                    return -;
                }
                0 => return +,
                - => return +,
            }
        }
        - => {
            // USER cannot escalate
            tif requested {
                + => {
                    io::println("  [GUARD] USER cannot escalate to KERNEL — DENIED");
                    return -;
                }
                0 => {
                    io::println("  [GUARD] USER cannot escalate to SERVICE — DENIED");
                    return -;
                }
                - => return +,
            }
        }
    }
}

// ---------------------------------------------------------------------------
// validate_signal: check signal number in range [-4..+4]
// ---------------------------------------------------------------------------

fn validate_signal(sig: int) -> trit {
    if sig < -4 {
        io::print("  [GUARD] signal ");
        io::print_int(sig);
        io::println(" out of range — INVALID");
        return -;
    }
    elif sig > 4 {
        io::print("  [GUARD] signal ");
        io::print_int(sig);
        io::println(" out of range — INVALID");
        return -;
    }
    return +;
}

// ---------------------------------------------------------------------------
// validate_checksum: verify IPC message integrity
// ---------------------------------------------------------------------------

fn validate_checksum(sender_pid: int, p0: int, p1: int, p2: int, checksum: int) -> trit {
    let expected = sender_pid + p0 + p1 + p2;
    if checksum == expected {
        return +;
    } else {
        io::println("  [GUARD] checksum mismatch — message corrupted");
        return -;
    }
}

// ---------------------------------------------------------------------------
// guard_result_name: human-readable guard result
// ---------------------------------------------------------------------------

fn guard_result_name(result: trit) -> str {
    tif result {
        + => return "VALID",
        0 => return "WARNING",
        - => return "INVALID",
    }
}

// ---------------------------------------------------------------------------
// main: demonstrate all guards
// ---------------------------------------------------------------------------
