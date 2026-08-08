// userspace/caps_demo.mt — THATTEOS CapWord enforcement demo
//
// Demonstrates the 9-trit capability word system:
//   GRANTED(+1)   INHERITED(0)   DENIED(-1)
//
// Shows capability attenuation: a child process cannot have
// more permissions than its parent.
//
// Author: Manish Jagdish Thatte

use std::io;

// Capability indices
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

fn trit_name(v: int) -> str {
    if v > 0  { return "GRANTED  (+1)"; }
    elif v == 0 { return "INHERITED ( 0)"; }
    else      { return "DENIED   (-1)"; }
}

fn trit_char(v: int) -> str {
    if v > 0  { return "+"; }
    elif v == 0 { return "0"; }
    else      { return "-"; }
}

// CapWord as 9 ints
fn print_capword(label: str, caps: int) {
    io::print("  ");
    io::print(label);
    io::println(":");
    let mut i = 0;
    while i < 9 {
        // extract trit i from packed int (simple encoding: bit i of caps)
        // We encode caps as: sum of (val_i + 1) * 3^i  where val_i in {-1,0,+1}
        // But for simplicity, pass 9 separate ints via array...
        // Instead: encode as ternary digits of the packed int
        // Actually for this demo, we use the bit pattern approach:
        // caps is a 9-digit balanced ternary number
        // Trit i = sign of ((caps / 3^i) % 3 adjusted)
        // For clarity we just print the packed int's trits.
        let div = caps;  // we'll decode below
        // Simpler: we pass a 9-digit decimal where digit i is (cap+1) giving 0,1,2
        // digit 0 = caps / 1 % 3, etc.
        let power = 1;
        let mut p = power;
        let mut j = 0;
        while j < i { p = p * 3; j = j + 1; }
        let trit_raw = (caps / p) - ((caps / p) / 3) * 3;
        let trit_val = trit_raw - 1;  // 0→-1, 1→0, 2→+1
        io::print("    [");
        io::print_int(i);
        io::print("] ");
        io::print(cap_name(i));
        io::print("  =  ");
        io::println(trit_name(trit_val));
        i = i + 1;
    }
}

fn cap_row(caps: int) -> str {
    let mut row = "";
    let mut i = 0;
    while i < 9 {
        let mut p = 1;
        let mut j = 0;
        while j < i { p = p * 3; j = j + 1; }
        let trit_raw = (caps / p) - ((caps / p) / 3) * 3;
        let trit_val = trit_raw - 1;
        row = str_concat(row, trit_char(trit_val));
        row = str_concat(row, " ");
        i = i + 1;
    }
    return row;
}

// Encode 9 cap values (each -1/0/+1) as single int
// caps = sum((v+1) * 3^i) for i=0..8
// Preset cap words:
//   KERNEL:  all +1  → each digit = 2  → 2*(1+3+9+27+81+243+729+2187+6561) = 2*9841 = 19682
//   SERVICE: like KERNEL but CAN_PRIV=-1 (index 5) → digit 5 = 0 → 19682 - 2*243 + 0 = 19682 - 486 = 19196
//   USER:    +1 on 0,1,2,6,8; -1 on 3,4,5,7
//            = 2*(1+3+9+729+6561) + 0*(27+81+243+2187) = 2*7303 = 14606
//   SANDBOX: 0 on 2,6,8; -1 on 0,1,3,4,5,7 → only inherited
//            = 0*(9+729+6561) + 0*(others) = 0s and 0s
//            Actually all denied(-1) except ipc/alloc/fs = inherited(0)
//            digit: 0→0, 1→0, 2→1(inh), 3→0, 4→0, 5→0, 6→1, 7→0, 8→1
//            = 1*9 + 1*729 + 1*6561 = 7299

fn kernel_caps()  -> int { return 19682; }
fn service_caps() -> int { return 19196; }
fn user_caps()    -> int { return 14606; }
fn sandbox_caps() -> int { return 7299;  }

fn attenuate(parent: int, child: int) -> int {
    // For each trit: child cannot exceed parent
    let mut result = 0;
    let mut i = 0;
    let mut p = 1;
    while i < 9 {
        let pt = ((parent / p) - ((parent / p) / 3) * 3) - 1;
        let ct = ((child  / p) - ((child  / p) / 3) * 3) - 1;
        let rt = if pt < 0 { -1 }
                 elif pt == 0 {
                     if ct > 0 { 0 } else { ct }
                 }
                 else { ct };
        result = result + (rt + 1) * p;
        p = p * 3;
        i = i + 1;
    }
    return result;
}

fn enforce(caps: int, cap_idx: int, syscall: str) {
    let mut p = 1;
    let mut j = 0;
    while j < cap_idx { p = p * 3; j = j + 1; }
    let trit_raw = (caps / p) - ((caps / p) / 3) * 3;
    let trit_val = trit_raw - 1;
    io::print("  SYS_");
    io::print(syscall);
    io::print("  → ");
    if trit_val > 0  { io::println("ALLOWED"); }
    elif trit_val == 0 { io::println("INHERITED (resolve needed)"); }
    else             { io::println("DENIED  *** CAPABILITY FAULT ***"); }
}

fn main() {
    io::println("=== THATTEOS caps_demo — 9-trit CapWord system ===");
    io::println("");

    let k = kernel_caps();
    let s = service_caps();
    let u = user_caps();
    let b = sandbox_caps();

    io::println("  CapWord encoding:");
    io::println("    FK EX IP IO MD PV AL SG FS");
    io::print  ("  KERNEL:  "); io::println(cap_row(k));
    io::print  ("  SERVICE: "); io::println(cap_row(s));
    io::print  ("  USER:    "); io::println(cap_row(u));
    io::print  ("  SANDBOX: "); io::println(cap_row(b));
    io::println("");

    io::println("  --- Enforcement: KERNEL PID=0 ---");
    enforce(k, 0, "FORK     ");
    enforce(k, 5, "PRIV_SET ");
    enforce(k, 3, "IO_READ  ");
    io::println("");

    io::println("  --- Enforcement: USER PID=2 ---");
    enforce(u, 0, "FORK     ");
    enforce(u, 3, "IO_READ  ");   // denied
    enforce(u, 4, "MOD_LOAD ");   // denied
    enforce(u, 5, "PRIV_SET ");   // denied
    enforce(u, 8, "FS_OPEN  ");
    io::println("");

    io::println("  --- Enforcement: SANDBOX PID=3 ---");
    enforce(b, 0, "FORK     ");   // denied
    enforce(b, 2, "IPC_SEND ");   // inherited
    enforce(b, 6, "ALLOC    ");   // inherited
    io::println("");

    io::println("  --- Attenuation: USER parent + KERNEL child request ---");
    let attenuated = attenuate(u, k);
    io::print  ("  Before: KERNEL  = "); io::println(cap_row(k));
    io::print  ("  After:  att(U,K)= "); io::println(cap_row(attenuated));
    io::println("  (child cannot exceed USER caps, even if it requests KERNEL)");
    io::println("");

    io::println("  --- Capability attenuation rule ---");
    io::println("  parent(-1) → child must be (-1)");
    io::println("  parent( 0) → child can be (0) or (-1), never (+1)");
    io::println("  parent(+1) → child can be anything");
    io::println("");
    io::println("=== caps_demo complete ===");
}
