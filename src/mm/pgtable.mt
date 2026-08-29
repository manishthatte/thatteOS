// mm/pgtable.mt — THATTE-OS page table with conditional permissions
// Module 7: Page table entry, map_page, handle_page_access
//
// Demonstrates P5 Claim 10:
//   Conditional page permissions: CoW(0) / demand-zero(0) / JIT-compile(0)
//   Three-way trit permission: -1=deny, 0=conditional, +1=allow

use std::io;

// ---------------------------------------------------------------------------
// Page table entry (4 fields, each a trit or int)
// ---------------------------------------------------------------------------

struct PageEntry {
    pub frame_addr: int,
    pub read_perm: trit,
    pub write_perm: trit,
    pub exec_perm: trit,
}

fn make_page(frame: int, r: trit, w: trit, x: trit) -> PageEntry {
    return PageEntry { frame_addr: frame, read_perm: r, write_perm: w, exec_perm: x };
}

fn print_page_entry(vaddr: int, e: PageEntry) {
    io::print("  PTE[vaddr=");
    io::print_int(vaddr);
    io::print("] frame=0x");
    io::print_int(e.frame_addr);
    io::print(" R=");
    io::print_trit(e.read_perm);
    io::print(" W=");
    io::print_trit(e.write_perm);
    io::print(" X=");
    io::println_trit(e.exec_perm);
}

// Renamed from `perm_name` in the 30 Aug merge: this one takes TWO
// arguments and answers what the fault handler should DO — "allow",
// "deny", or which of three zero-fill strategies. The signature alone
// says it was never the fs layer's `perm_name`.
fn pgfault_action(p: trit, kind: str) -> str {
    tif p {
        + => return "allow",
        0 => {
            if kind == "read"  { return "CoW(copy-on-write)"; }
            elif kind == "write" { return "demand-zero"; }
            else { return "JIT-compile"; }
        }
        - => return "deny",
    }
}

// ---------------------------------------------------------------------------
// map_page: create a page table entry
// ---------------------------------------------------------------------------

fn map_page(vaddr: int, perm_r: trit, perm_w: trit, perm_x: trit) -> PageEntry {
    let frame = vaddr + 4096;   // simulated frame allocation
    let entry = make_page(frame, perm_r, perm_w, perm_x);

    io::print("[PGTBL] map_page: vaddr=");
    io::print_int(vaddr);
    io::print(" read=");
    io::print(pgfault_action(perm_r, "read"));
    io::print(" write=");
    io::print(pgfault_action(perm_w, "write"));
    io::print(" exec=");
    io::println(pgfault_action(perm_x, "exec"));

    return entry;
}

// ---------------------------------------------------------------------------
// Conditional page permission handlers
// ---------------------------------------------------------------------------

fn handle_cow(vaddr: int) {
    io::print("    handle_cow(vaddr=");
    io::print_int(vaddr);
    io::println("): copy-on-write — allocate private copy, set read_perm=+1");
}

fn allow_read(vaddr: int) {
    io::print("    allow_read(vaddr=");
    io::print_int(vaddr);
    io::println("): read permitted — return page data");
}

fn fault_access(msg: str, vaddr: int) {
    io::print("    FAULT: ");
    io::print(msg);
    io::print(" at vaddr=");
    io::println_int(vaddr);
    io::println("    -> process.state = FAULTED (-5)");
}

fn handle_demand_zero(vaddr: int) {
    io::print("    handle_demand_zero(vaddr=");
    io::print_int(vaddr);
    io::println("): demand-zero — allocate zeroed page, set write_perm=+1");
}

fn allow_write(vaddr: int) {
    io::print("    allow_write(vaddr=");
    io::print_int(vaddr);
    io::println("): write permitted — store to page");
}

fn handle_jit(vaddr: int) {
    io::print("    handle_jit(vaddr=");
    io::print_int(vaddr);
    io::println("): JIT-compile — compile page to native, set exec_perm=+1");
}

fn allow_exec(vaddr: int) {
    io::print("    allow_exec(vaddr=");
    io::print_int(vaddr);
    io::println("): exec permitted — fetch instruction");
}

// ---------------------------------------------------------------------------
// handle_page_access: 3-way dispatch on access_type and permission trit
// access_type: +1=READ, 0=WRITE, -1=EXECUTE
// ---------------------------------------------------------------------------

fn handle_page_access(vaddr: int, access_type: trit, entry: PageEntry) {
    io::print("[PGTBL] page_access: vaddr=");
    io::print_int(vaddr);
    io::print(" access=");
    tif access_type {
        + => io::print("READ(+1)"),
        0 => io::print("WRITE(0)"),
        - => io::print("EXEC(-1)"),
    }
    io::println("");

    tif access_type {
        + => {
            // READ access — check read_perm
            io::print("  read_perm=");
            io::print_trit(entry.read_perm);
            io::print(" -> ");
            tif entry.read_perm {
                - => { io::println("DENY"); fault_access("read denied", vaddr); }
                0 => { io::println("CoW"); handle_cow(vaddr); }
                + => { io::println("ALLOW"); allow_read(vaddr); }
            }
        }
        0 => {
            // WRITE access — check write_perm
            io::print("  write_perm=");
            io::print_trit(entry.write_perm);
            io::print(" -> ");
            tif entry.write_perm {
                - => { io::println("DENY"); fault_access("write denied", vaddr); }
                0 => { io::println("demand-zero"); handle_demand_zero(vaddr); }
                + => { io::println("ALLOW"); allow_write(vaddr); }
            }
        }
        - => {
            // EXECUTE access — check exec_perm
            io::print("  exec_perm=");
            io::print_trit(entry.exec_perm);
            io::print(" -> ");
            tif entry.exec_perm {
                - => { io::println("DENY"); fault_access("exec denied", vaddr); }
                0 => { io::println("JIT"); handle_jit(vaddr); }
                + => { io::println("ALLOW"); allow_exec(vaddr); }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// main: demonstrate page table and conditional permissions
// ---------------------------------------------------------------------------
