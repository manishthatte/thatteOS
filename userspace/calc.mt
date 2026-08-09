// userspace/calc.mt — THATTEOS ternary calculator
//
// Standalone userspace program.  Interactive: enter "<a> <op> <b>"
// (infix) or "<op> <a> <b>" (prefix) — both forms are accepted.
// All results displayed in both decimal and balanced ternary.
//
// Ops: + - * / % ** (power)  abs  neg
// Type 'quit' or 'exit' to leave.
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

fn trit_len(n: int) -> int {
    let s = to_balanced_ternary(n);
    return str_len(s);
}

fn print_result(a: int, op: str, b: int, result: int) {
    io::print("  ");
    io::print_int(a);
    io::print(" ");
    io::print(op);
    io::print(" ");
    io::print_int(b);
    io::print(" = ");
    io::print_int(result);
    io::print("   [0t");
    io::print(to_balanced_ternary(result));
    io::print(", ");
    io::print_int(trit_len(result));
    io::println(" trits]");
}

fn is_binop(op: str) -> bool {
    return op == "+" || op == "-" || op == "*" || op == "/" || op == "%" || op == "**";
}

fn apply_op(a: int, op: str, b: int) {
    if op == "+" { print_result(a, "+", b, a + b); }
    elif op == "-" { print_result(a, "-", b, a - b); }
    elif op == "*" { print_result(a, "*", b, a * b); }
    elif op == "/" {
        if b == 0 { io::println("  error: division by zero"); }
        else { print_result(a, "/", b, a / b); }
    }
    elif op == "%" {
        if b == 0 { io::println("  error: modulo by zero"); }
        else { print_result(a, "%", b, a - (a / b) * b); }
    }
    elif op == "**" { print_result(a, "**", b, power(a, b)); }
    else {
        io::print("  ? unknown op: ");
        io::println(op);
    }
}

fn power(base: int, exp: int) -> int {
    if exp == 0 { return 1; }
    if exp < 0  { return 0; }
    let mut result = 1;
    let mut e = exp;
    while e > 0 {
        result = result * base;
        e = e - 1;
    }
    return result;
}

fn main() {
    io::println("=== THATTEOS calc  —  balanced ternary arithmetic ===");
    io::println("  ops: + - * / % ** abs neg");
    io::println("  forms: <a> <op> <b>   or   <op> <a> <b>");
    io::println("  type 'quit' to exit");
    io::println("");

    let mut running = 1;
    while running == 1 {
        io::print("calc> ");
        let raw = io::read_line();
        let line = str_trim(raw);

        if line == "" { /* skip */ }
        elif line == "quit" || line == "exit" {
            running = 0;
        }
        else {
            // unary: "abs N" or "neg N"
            let sp1 = str_find(line, " ");
            if sp1 == -1 {
                io::print("  ? unknown: ");
                io::println(line);
            } else {
                let op = str_slice(line, 0, sp1);
                let rest = str_trim(str_slice(line, sp1 + 1, str_len(line)));

                if op == "abs" {
                    let n = str_parse_int(rest);
                    let r = if n < 0 { 0 - n } else { n };
                    io::print("  abs(");
                    io::print_int(n);
                    io::print(") = ");
                    io::print_int(r);
                    io::print("   [0t");
                    io::print(to_balanced_ternary(r));
                    io::println("]");
                }
                elif op == "neg" {
                    let n = str_parse_int(rest);
                    let r = 0 - n;
                    io::print("  neg(");
                    io::print_int(n);
                    io::print(") = ");
                    io::print_int(r);
                    io::print("   [0t");
                    io::print(to_balanced_ternary(r));
                    io::println("]");
                }
                elif is_binop(op) {
                    // prefix: "<op> <a> <b>"
                    let sp2 = str_find(rest, " ");
                    if sp2 == -1 {
                        io::println("  usage: <a> <op> <b>  or  <op> <a> <b>  or  abs/neg <num>");
                    } else {
                        let a = str_parse_int(str_slice(rest, 0, sp2));
                        let b = str_parse_int(str_trim(str_slice(rest, sp2 + 1, str_len(rest))));
                        apply_op(a, op, b);
                    }
                }
                else {
                    // infix: "<a> <op> <b>" — first token is the number a
                    let sp2 = str_find(rest, " ");
                    if sp2 == -1 {
                        io::println("  usage: <a> <op> <b>  or  <op> <a> <b>  or  abs/neg <num>");
                    } else {
                        let op2 = str_slice(rest, 0, sp2);
                        let b_s = str_trim(str_slice(rest, sp2 + 1, str_len(rest)));
                        if is_binop(op2) {
                            apply_op(str_parse_int(op), op2, str_parse_int(b_s));
                        } else {
                            io::print("  ? unknown op: ");
                            io::println(op2);
                        }
                    }
                }
            }
        }
    }
    io::println("  bye.");
}
