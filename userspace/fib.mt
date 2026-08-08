// userspace/fib.mt — Fibonacci sequence in balanced ternary
//
// Computes and displays the first N Fibonacci numbers,
// showing each in decimal and balanced ternary side by side.
// Demonstrates: ternary growth, trit-count complexity, signed representation.
//
// Author: Manish Jagdish Thatte

use std::io;

fn to_balanced_ternary(n: int) -> str {
    if n == 0 { return "0"; }
    let mut val = n;
    let neg = val < 0;
    if neg { val = 0 - val; }
    let mut result = "";
    while val > 0 {
        let rem = val - (val / 3) * 3;
        if rem == 0 {
            result = str_concat("0", result);
            val = val / 3;
        } elif rem == 1 {
            result = str_concat("+", result);
            val = val / 3;
        } else {
            result = str_concat("-", result);
            val = val / 3 + 1;
        }
    }
    if neg {
        let s1 = str_replace(result, "+", "T");
        let s2 = str_replace(s1, "-", "+");
        return str_replace(s2, "T", "-");
    }
    return result;
}

fn pad_left_int(n: int, width: int) -> str {
    let s = str_from_int(n);
    let mut r = s;
    while str_len(r) < width {
        r = str_concat(" ", r);
    }
    return r;
}

fn main() {
    io::println("=== THATTEOS fib — Fibonacci in balanced ternary ===");
    io::println("");
    io::print("  how many terms? (max 40)> ");
    let raw = io::read_line();
    let n_str = str_trim(raw);
    let mut n = str_parse_int(n_str);
    if n <= 0  { n = 20; }
    if n > 40  { n = 40; }

    io::println("");
    io::println("   n   decimal          balanced ternary         trits");
    io::println("  ---  ---------------  -----------------------  -----");

    let mut a = 0;
    let mut b = 1;
    let mut i = 0;
    while i < n {
        let trits = str_len(to_balanced_ternary(a));
        let mut btp = to_balanced_ternary(a);

        io::print("  ");
        io::print(pad_left_int(i, 3));
        io::print("  ");
        io::print(pad_left_int(a, 15));
        io::print("  ");
        // pad ternary to 23 chars
        while str_len(btp) < 23 {
            btp = str_concat(" ", btp);
        }
        io::print(btp);
        io::print("  ");
        io::println_int(trits);

        let next = a + b;
        a = b;
        b = next;
        i = i + 1;
    }

    io::println("");
    io::println("  Key insight: trit count grows as log_3(F_n).");
    io::println("  F_n ~ phi^n / sqrt(5)  =>  trits(F_n) ~ n * log_3(phi) ~ 0.438 * n");
}
