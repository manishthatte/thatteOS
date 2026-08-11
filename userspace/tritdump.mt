// userspace/tritdump.mt — thatteOS balanced ternary file dump
//
// Reads a file and prints each byte as:
//   offset(decimal)  hex  balanced-ternary  ASCII
//
// Each byte (0-255) maps to a balanced ternary number (-121 to +134 via
// signed byte interpretation, or 0 to +255 unsigned).
//
// Author: Manish Jagdish Thatte

use std::io;
use std::fs;

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

fn pad_right(s: str, width: int) -> str {
    let mut r = s;
    while str_len(r) < width {
        r = str_concat(r, " ");
    }
    return r;
}

fn pad_left_int(n: int, width: int) -> str {
    let s = str_from_int(n);
    let mut r = s;
    while str_len(r) < width {
        r = str_concat(" ", r);
    }
    return r;
}

fn to_hex(n: int) -> str {
    if n == 0 { return "00"; }
    let hex_digits = "0123456789abcdef";
    let hi = (n / 16) - (n / 256) * 16;
    let lo = n - (n / 16) * 16;
    let h = str_slice(hex_digits, hi, hi + 1);
    let l = str_slice(hex_digits, lo, lo + 1);
    return str_concat(h, l);
}

fn is_printable(n: int) -> int {
    if n >= 32 && n <= 126 { return 1; }
    return 0;
}

fn main() {
    io::println("=== thatteOS tritdump ===");
    io::print("file> ");
    let raw = io::read_line();
    let path = str_trim(raw);

    if path == "" || path == "quit" {
        io::println("  no file given.");
        return;
    }
    if !fs::exists(path) {
        io::print("  tritdump: no such file: ");
        io::println(path);
        return;
    }

    let content = fs::read_file(path);
    let size    = str_len(content);

    io::print("  file:  ");
    io::println(path);
    io::print("  size:  ");
    io::print_int(size);
    io::println(" bytes");
    io::println("");
    io::println("  offset  hex  balanced-ternary  ascii");
    io::println("  ------  ---  ----------------  -----");

    let mut i = 0;
    while i < size {
        let ch  = str_slice(content, i, i + 1);
        // Real char code of the byte (str_char_at returns a signed byte;
        // normalise to unsigned 0-255)
        let mut byt = str_char_at(content, i);
        if byt < 0 { byt = byt + 256; }
        let bt = to_balanced_ternary(byt);
        let hex = to_hex(byt);
        let asc = if is_printable(byt) == 1 { ch } else { "." };

        io::print("  ");
        io::print(pad_left_int(i, 6));
        io::print("  ");
        io::print(hex);
        io::print("   ");
        io::print(pad_right(bt, 16));
        io::print("  ");
        io::println(asc);

        i = i + 1;
        if i >= 256 && size > 256 {
            io::print("  ... (");
            io::print_int(size - 256);
            io::println(" more bytes — showing first 256)");
            i = size;  // stop
        }
    }
    io::println("");
    io::print("  total: ");
    io::print_int(size);
    io::print(" bytes  [0t");
    io::print(to_balanced_ternary(size));
    io::println("]");
}
