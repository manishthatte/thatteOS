// security/capability.mt — THATTE-OS capability-based security
// Module 20: 9-trit capability words, attenuation, enforcement
//
// Demonstrates P5 Claims:
//   Claim 3  — Privilege enforcement at capability granularity
//   Claim 8  — Trit-based permission model
//
// Each process has a 9-trit capability word:
//   Trit 0: CAN_FORK    — create child processes
//   Trit 1: CAN_EXEC    — load program images
//   Trit 2: CAN_IPC     — send/receive messages
//   Trit 3: CAN_IO      — access I/O devices
//   Trit 4: CAN_MOD     — load/unload modules
//   Trit 5: CAN_PRIV    — change privilege level
//   Trit 6: CAN_ALLOC   — allocate/free memory
//   Trit 7: CAN_SIGNAL  — send signals to processes
//   Trit 8: CAN_FS      — filesystem operations
//
// Per-trit values:
//   +1 = GRANTED  (explicitly allowed)
//    0 = INHERITED (use parent's value; if no parent, treat as DENIED)
//   -1 = DENIED   (explicitly forbidden)

use std::io;

// ---------------------------------------------------------------------------
// Capability word (9 trits)
// ---------------------------------------------------------------------------

struct CapWord {
    pub pid: int,
    pub c0: trit,   // CAN_FORK
    pub c1: trit,   // CAN_EXEC
    pub c2: trit,   // CAN_IPC
    pub c3: trit,   // CAN_IO
    pub c4: trit,   // CAN_MOD
    pub c5: trit,   // CAN_PRIV
    pub c6: trit,   // CAN_ALLOC
    pub c7: trit,   // CAN_SIGNAL
    pub c8: trit,   // CAN_FS
}

fn cap_name(idx: int) -> str {
    if idx == 0 { return "CAN_FORK"; }
    elif idx == 1 { return "CAN_EXEC"; }
    elif idx == 2 { return "CAN_IPC"; }
    elif idx == 3 { return "CAN_IO"; }
    elif idx == 4 { return "CAN_MOD"; }
    elif idx == 5 { return "CAN_PRIV"; }
    elif idx == 6 { return "CAN_ALLOC"; }
    elif idx == 7 { return "CAN_SIGNAL"; }
    elif idx == 8 { return "CAN_FS"; }
    else { return "UNKNOWN"; }
}

fn cap_value_name(v: trit) -> str {
    tif v {
        + => return "GRANTED",
        0 => return "INHERITED",
        - => return "DENIED",
    }
}

fn get_cap(cap: CapWord, idx: int) -> trit {
    if idx < 0 || idx > 8 { return -; }  // out-of-range → DENIED
    if idx == 0 { return cap.c0; }
    elif idx == 1 { return cap.c1; }
    elif idx == 2 { return cap.c2; }
    elif idx == 3 { return cap.c3; }
    elif idx == 4 { return cap.c4; }
    elif idx == 5 { return cap.c5; }
    elif idx == 6 { return cap.c6; }
    elif idx == 7 { return cap.c7; }
    else { return cap.c8; }
}

// ---------------------------------------------------------------------------
// Pre-defined capability sets
// ---------------------------------------------------------------------------

fn kernel_caps(pid: int) -> CapWord {
    // KERNEL: everything granted
    return CapWord { pid: pid,
        c0: +, c1: +, c2: +, c3: +, c4: +, c5: +, c6: +, c7: +, c8: + };
}

fn service_caps(pid: int) -> CapWord {
    // SERVICE: most granted, no PRIV change
    return CapWord { pid: pid,
        c0: +, c1: +, c2: +, c3: +, c4: +, c5: -, c6: +, c7: +, c8: + };
}

fn user_caps(pid: int) -> CapWord {
    // USER: limited — fork, exec, IPC, alloc, FS only
    return CapWord { pid: pid,
        c0: +, c1: +, c2: +, c3: -, c4: -, c5: -, c6: +, c7: -, c8: + };
}

fn sandboxed_caps(pid: int) -> CapWord {
    // Sandbox: minimal — only inherited capabilities
    return CapWord { pid: pid,
        c0: -, c1: -, c2: 0, c3: -, c4: -, c5: -, c6: 0, c7: -, c8: 0 };
}

// ---------------------------------------------------------------------------
// print_caps: display capability word
// ---------------------------------------------------------------------------

fn print_caps(cap: CapWord) {
    io::print("  CapWord[PID=");
    io::print_int(cap.pid);
    io::println("]:");
    let mut i = 0;
    while i < 9 {
        let v = get_cap(cap, i);
        io::print("    [");
        io::print_int(i);
        io::print("] ");
        io::print(cap_name(i));
        io::print(" = ");
        io::print_trit(v);
        io::print(" (");
        io::print(cap_value_name(v));
        io::println(")");
        i = i + 1;
    }
}

// ---------------------------------------------------------------------------
// check_cap: verify a specific capability
// Returns: +1=allowed, 0=inherited (resolve needed), -1=denied
// ---------------------------------------------------------------------------

// A pure predicate: the caller decides whether and how to report. `enforce`
// below does the logging, so check_cap must not (it used to print its own
// DENIED line, which meant every denial was reported twice).
fn check_cap(cap: CapWord, idx: int) -> trit {
    return get_cap(cap, idx);
}

// ===========================================================================
// COMPOSITION RULE (normative)
// ===========================================================================
//
// `resolve` and `attenuate` do NOT commute, so the order they are applied in
// is part of the model, not an implementation detail. With a parent trit of
// 0 (INHERITED) and a child requesting + (GRANTED):
//
//   attenuate first: attenuate_trit(0, +) = 0, then resolve_cap(0, 0) = -
//                    => DENIED
//   resolve first:   parent resolves to + against a granting grandparent,
//                    then attenuate_trit(+, +) = +
//                    => GRANTED
//
// Same three processes, opposite outcome. The rule that removes the ambiguity:
//
//   INVARIANT: a CapWord used as a PARENT must already be resolved — it must
//   contain no INHERITED (0) trit. Resolution walks the process tree from the
//   root downward, so by the time a process spawns a child its own word is
//   always concrete.
//
// `is_resolved` tests the invariant and `resolve_root` establishes it for a
// process with no parent (INHERITED becomes DENIED — fail closed). With a
// resolved parent, attenuate_trit's 0-parent case cannot arise and the two
// operations compose in either order.
//
// ---------------------------------------------------------------------------
// resolve_inherited: resolve INHERITED(0) using parent capabilities
// ---------------------------------------------------------------------------

// True when `cap` contains no INHERITED trit, i.e. it is safe to use as a
// parent word (see COMPOSITION RULE above).
fn is_resolved(cap: CapWord) -> bool {
    let mut i = 0;
    while i < 9 {
        if get_cap(cap, i) == 0 { return false; }
        i = i + 1;
    }
    return true;
}

// Resolve a root process's word: with no parent, INHERITED means DENIED.
// Idempotent, and always yields a word satisfying `is_resolved`.
fn resolve_root(cap: CapWord) -> CapWord {
    let deny = CapWord { pid: cap.pid,
        c0: -, c1: -, c2: -, c3: -, c4: -, c5: -, c6: -, c7: -, c8: - };
    return resolve_all(cap, deny);
}

fn resolve_cap(child_cap: trit, parent_cap: trit) -> trit {
    tif child_cap {
        + => return +,       // Explicitly granted
        - => return -,       // Explicitly denied
        0 => {
            // Inherited: use parent's effective value
            tif parent_cap {
                + => return +,
                0 => return -,   // If parent also inherited and no grandparent, deny
                - => return -,
            }
        }
    }
}

fn resolve_all(child: CapWord, parent: CapWord) -> CapWord {
    return CapWord {
        pid: child.pid,
        c0: resolve_cap(child.c0, parent.c0),
        c1: resolve_cap(child.c1, parent.c1),
        c2: resolve_cap(child.c2, parent.c2),
        c3: resolve_cap(child.c3, parent.c3),
        c4: resolve_cap(child.c4, parent.c4),
        c5: resolve_cap(child.c5, parent.c5),
        c6: resolve_cap(child.c6, parent.c6),
        c7: resolve_cap(child.c7, parent.c7),
        c8: resolve_cap(child.c8, parent.c8),
    };
}

// ---------------------------------------------------------------------------
// attenuate: parent restricts child capabilities
// Rule: child can never have MORE than parent
// ---------------------------------------------------------------------------

// Precondition: `parent_cap` comes from a resolved word (see COMPOSITION
// RULE). The 0-parent arm below therefore cannot arise in a well-formed call;
// it stays as a fail-closed fallback rather than silently granting.
fn attenuate_trit(parent_cap: trit, child_request: trit) -> trit {
    tif parent_cap {
        + => {
            // Parent has it: child can have anything
            return child_request;
        }
        0 => {
            // Unresolved parent — the invariant was violated. Deny rather
            // than propagate an INHERITED that would resolve differently
            // depending on when it is resolved.
            return -;
        }
        - => {
            // Parent denied: child must be denied
            return -;
        }
    }
}

// Restrict a child's requested capabilities by its parent's.
//
// `parent` must be resolved (COMPOSITION RULE). Rather than trust the caller,
// normalise here: resolve_root leaves an already-resolved word untouched (it
// only rewrites INHERITED trits), so this is a no-op in the well-formed case
// and makes the operation total in the ill-formed one.
fn attenuate(parent_in: CapWord, child_request: CapWord) -> CapWord {
    let parent = resolve_root(parent_in);
    return CapWord {
        pid: child_request.pid,
        c0: attenuate_trit(parent.c0, child_request.c0),
        c1: attenuate_trit(parent.c1, child_request.c1),
        c2: attenuate_trit(parent.c2, child_request.c2),
        c3: attenuate_trit(parent.c3, child_request.c3),
        c4: attenuate_trit(parent.c4, child_request.c4),
        c5: attenuate_trit(parent.c5, child_request.c5),
        c6: attenuate_trit(parent.c6, child_request.c6),
        c7: attenuate_trit(parent.c7, child_request.c7),
        c8: attenuate_trit(parent.c8, child_request.c8),
    };
}

// ---------------------------------------------------------------------------
// enforce: check capability before syscall
// ---------------------------------------------------------------------------

fn enforce(cap: CapWord, required_cap: int, syscall_name: str) -> bool {
    let result = check_cap(cap, required_cap);

    tif result {
        + => {
            io::print("  [CAP] ");
            io::print(syscall_name);
            io::print(": ");
            io::print(cap_name(required_cap));
            io::println(" — ALLOWED");
            return true;
        }
        0 => {
            io::print("  [CAP] ");
            io::print(syscall_name);
            io::print(": ");
            io::print(cap_name(required_cap));
            io::println(" — INHERITED (resolve needed)");
            return false;
        }
        - => {
            io::print("  [CAP] ");
            io::print(syscall_name);
            io::print(": ");
            io::print(cap_name(required_cap));
            io::println(" — DENIED (capability fault)");
            return false;
        }
    }
}

// ---------------------------------------------------------------------------
// main: demonstrate capability system
// ---------------------------------------------------------------------------
