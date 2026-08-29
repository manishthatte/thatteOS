// kernel/privilege.mt — THATTE-OS three-level privilege management
// Module 4: get/set privilege, fault handler, sys_priv_set
//
// Demonstrates P5 Claims:
//   Claim 3  — Three-level privilege KERNEL(+1)/SERVICE(0)/USER(-1)
//   Claim 8  — Three-rail substrate: VDD(+1)/GND(0)/VSS(-1)
//   Claim 9  — Signed virtual address enforcement

use std::io;

// The one `priv_name`, 30 August 2026. Three kernel modules defined this
// byte-identically -- kernel/panic.mt, mm/vmem.mt and this one's own int-typed
// variant (now `priv_rail_name`) -- and the three userspace programs define it
// a fourth and fifth time, which is fine: they are separate programs and the
// merge does not reach them.
//
// It lives here because naming a privilege level is what this module is for.
fn priv_name(p: trit) -> str {
    tif p {
        + => return "KERNEL(+1)",
        0 => return "SERVICE(0)",
        - => return "USER(-1)",
    }
}


// ---------------------------------------------------------------------------
// Privilege level encoding as int:  +1=KERNEL, 0=SERVICE, -1=USER
// ---------------------------------------------------------------------------

// Renamed from `priv_name` in the 30 Aug merge. This one takes an `int` and
// names the RAIL a privilege level sits on (VDD/GND/VSS); the `trit`-typed
// `priv_name` that kernel/panic.mt and mm/vmem.mt both carried is the one
// that kept the name, because a privilege level IS a trit and taking an int
// is this function's own concession to the status register.
fn priv_rail_name(p: int) -> str {
    if p > 0 { return "KERNEL (+1) [VDD rail]"; }
    elif p < 0 { return "USER   (-1) [VSS rail]"; }
    else { return "SERVICE (0) [GND rail]"; }
}

fn int_to_trit(n: int) -> trit {
    if n > 0 { return +; }
    elif n < 0 { return -; }
    else { return 0; }
}

// ---------------------------------------------------------------------------
// set_privilege: write status register [26..25] — KERNEL only
// ---------------------------------------------------------------------------

fn set_privilege(current_priv: int, new_level: int) -> int {
    if current_priv > 0 {
        // KERNEL authorised
        io::print("  set_privilege: KERNEL authorised -> ");
        io::println(priv_rail_name(new_level));
        io::print("  STATUS[26..25] written: ");
        io::println(priv_rail_name(new_level));
        return new_level;
    } else {
        io::println("  set_privilege: PRIVILEGE FAULT — only KERNEL can call set_privilege");
        return current_priv;
    }
}

// ---------------------------------------------------------------------------
// priv_downgrade_self: explicitly-audited voluntary privilege drop.
// A process may always LOWER its own privilege (SERVICE -> USER). This is a
// separate, monotonic primitive: it can never raise privilege, so it needs
// no KERNEL authorisation and it never forges the caller's level.
// ---------------------------------------------------------------------------

fn priv_downgrade_self(current_priv: int, new_level: int) -> int {
    if new_level >= current_priv {
        io::println("  priv_downgrade_self: FAULT — can only lower privilege");
        return current_priv;
    }
    io::print("  priv_downgrade_self: voluntary drop -> ");
    io::println(priv_rail_name(new_level));
    io::print("  STATUS[26..25] written: ");
    io::println(priv_rail_name(new_level));
    return new_level;
}

// ---------------------------------------------------------------------------
// privilege_fault_handler
// ---------------------------------------------------------------------------

fn privilege_fault_handler(pc: int) {
    io::print("  PRIVILEGE FAULT: illegal access at pc=0x");
    io::println_int(pc);
    io::println("  process.state -> FAULTED (-5)");
    io::println("  -> scheduler_run() invoked");
}

// ---------------------------------------------------------------------------
// sys_priv_set: validate and execute privilege transition
// Returns new privilege level as int
// ---------------------------------------------------------------------------

fn sys_priv_set(current_priv: int, requested: int) -> int {
    io::print("[SYS_PRIV_SET] current=");
    io::print(priv_rail_name(current_priv));
    io::print("  requested=");
    io::println(priv_rail_name(requested));

    let ct = int_to_trit(current_priv);
    tif ct {
        + => {
            // KERNEL can transition to any level
            io::println("  KERNEL can transition to any level — allowed");
            return set_privilege(current_priv, requested);
        }
        0 => {
            // SERVICE can only drop to USER (-1)
            let rt = int_to_trit(requested);
            tif rt {
                + => {
                    io::println("  SERVICE cannot escalate to KERNEL — FAULT");
                    privilege_fault_handler(0);
                    return current_priv;
                }
                0 => {
                    io::println("  SERVICE -> SERVICE (no-op)");
                    return current_priv;
                }
                - => {
                    io::println("  SERVICE -> USER allowed (downgrade)");
                    return priv_downgrade_self(current_priv, requested);
                }
            }
        }
        - => {
            // USER cannot escalate
            io::print("  USER cannot escalate to ");
            io::print(priv_rail_name(requested));
            io::println(" — FAULT");
            privilege_fault_handler(0);
            return current_priv;
        }
    }
}

// ---------------------------------------------------------------------------
// Signed virtual address enforcement (Claim 9)
// ---------------------------------------------------------------------------

// Renamed from `check_address_privilege` in the 30 Aug merge. mm/vmem.mt has
// a function of that name which asks a THREE-argument question (addr,
// required, current) in trits; this one asks a two-argument one in ints and
// belongs to the status-register view of privilege rather than the memory
// map's. Two questions, not two copies.
fn priv_check_address(addr: int, current_priv: int) -> bool {
    // MST of addr = sign(addr)
    let mst = int_to_trit(addr);

    io::print("  addr=");
    io::print_int(addr);
    io::print(" MST=");
    io::print_trit(mst);
    io::print(" current_priv=");
    io::print(priv_rail_name(current_priv));

    tif mst {
        + => {
            // Kernel space — require KERNEL privilege
            if current_priv > 0 {
                io::println(" -> ALLOW (kernel->kernel)");
                return true;
            } else {
                io::println(" -> DENY (insufficient privilege for kernel space)");
                return false;
            }
        }
        0 => {
            io::println(" -> ALLOW (shared space)");
            return true;
        }
        - => {
            io::println(" -> ALLOW (user space)");
            return true;
        }
    }
}

// ---------------------------------------------------------------------------
// main: demonstrate privilege transitions and address enforcement
// ---------------------------------------------------------------------------
