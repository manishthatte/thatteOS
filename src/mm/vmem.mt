// mm/vmem.mt — THATTE-OS virtual memory manager
// Module 6: vmem_init, check_address_privilege, address_fault_handler
//
// Demonstrates P5 Claims:
//   Claim 2  — Virtual memory + conditional permissions
//   Claim 9  — Signed virtual address enforcement (MST of t27 addr)

use std::io;

// ---------------------------------------------------------------------------
// Address space layout (T3ISA 27-trit addresses)
//
//   addr > 0  (MST=+1): KERNEL space   — KERNEL privilege required
//   addr = 0  (MST= 0): SHARED space   — all privilege levels
//   addr < 0  (MST=-1): USER space     — all privilege levels
//
// Total addressable: (3^27 - 1)/2 = 3,812,798,742,493 words
// ---------------------------------------------------------------------------

fn region_name(mst: trit) -> str {
    tif mst {
        + => return "KERNEL-SPACE",
        0 => return "SHARED-SPACE",
        - => return "USER-SPACE",
    }
}

// `priv_name` moved to kernel/privilege.mt in the 30 Aug merge -- three
// kernel modules carried a byte-identical copy.

// ---------------------------------------------------------------------------
// vmem_init: map the three address regions
// ---------------------------------------------------------------------------

fn vmem_init() {
    io::println("[VMEM] vmem_init: mapping T3ISA virtual address space");
    io::println("");
    io::println("  Address space: 27-trit signed word (T3ISA)");
    io::println("  Range: -(3^27-1)/2 .. +(3^27-1)/2");
    io::println("       = -3812798742493 .. +3812798742493");
    io::println("");
    io::println("  Region map (MST = most-significant trit of address):");
    io::println("  +----------+------------------------+-----------------+");
    io::println("  | MST addr | Region                 | Required priv   |");
    io::println("  +----------+------------------------+-----------------+");
    io::println("  |   +1     | KERNEL space (high)    | KERNEL (+1)     |");
    io::println("  |    0     | SHARED space (zero)    | any             |");
    io::println("  |   -1     | USER space (low)       | any             |");
    io::println("  +----------+------------------------+-----------------+");
    io::println("");

    // Map kernel space: addr MST=+1
    io::println("  [MAP] KERNEL space: base=+1*3^26, size=3^26-1, perm=KERNEL");

    // Map shared space: addr MST=0
    io::println("  [MAP] SHARED space: base=0, size=3^26-1, perm=all");

    // Map user space: addr MST=-1
    io::println("  [MAP] USER space: base=-1*3^26, size=3^26-1, perm=all");

    io::println("");
    io::println("  Page size: 3^9 = 19683 words per page");
    io::println("[VMEM] vmem_init: done");
}

// ---------------------------------------------------------------------------
// check_address_privilege: enforce MST-based access control
// ---------------------------------------------------------------------------

fn addr_mst(addr: int) -> trit {
    if addr > 0 { return +; }
    elif addr < 0 { return -; }
    else { return 0; }
}

fn check_address_privilege(addr: int, required_priv: trit, current_priv: trit) -> bool {
    let mst = addr_mst(addr);

    io::print("[VMEM] check_address_privilege: addr=");
    io::print_int(addr);
    io::print(" MST=");
    io::print_trit(mst);
    io::print(" current=");
    io::print(priv_name(current_priv));
    io::print(" required=");
    io::println(region_name(mst));

    tif mst {
        + => {
            // Kernel space: only KERNEL (+1) allowed
            tif current_priv {
                + => { io::println("  -> ALLOW (KERNEL accessing KERNEL space)"); return true; }
                0 => { io::println("  -> DENY  (SERVICE cannot access KERNEL space)"); return false; }
                - => { io::println("  -> DENY  (USER cannot access KERNEL space)"); return false; }
            }
        }
        0 => {
            // Shared space: all levels allowed
            io::println("  -> ALLOW (shared space — all privilege levels)");
            return true;
        }
        - => {
            // User space: all levels allowed
            io::println("  -> ALLOW (user space — all privilege levels)");
            return true;
        }
    }
}

// ---------------------------------------------------------------------------
// address_fault_handler
// ---------------------------------------------------------------------------

fn address_fault_handler(addr: int) {
    io::print("[VMEM] ADDRESS FAULT: addr=");
    io::print_int(addr);
    io::println(" requires KERNEL privilege");
    io::println("  -> privilege_fault_handler() invoked");
    io::println("  -> process.state = FAULTED (-5)");
    io::println("  -> scheduler_run() dispatched");
}

// ---------------------------------------------------------------------------
// main: demonstrate virtual memory layout and address checks
// ---------------------------------------------------------------------------
