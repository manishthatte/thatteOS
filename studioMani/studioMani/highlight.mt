// studioMani/studioMani/highlight.mt — ManiT syntax highlighter
// Draws one syntax-highlighted line; also provides selection background helper.
// Depends on: theme.mt (c_* color fns), layout.mt (L_LINE, int_max, c_selection)
// Author: Manish Jagdish Thatte

// `ch` is a one-character string. Relational operators on `str` are REFUSED by
// maniTC (report.txt P45: `Ord` and `>` disagreed about which types are ordered,
// and the operator's answer won), and before P45 they compared ADDRESSES, so
// this test never meant what it reads as. Compare code points instead.
fn hl_is_alpha(ch: str) -> int {
    let c = str::char_at(ch, 0) as int;
    if c >= 97 && c <= 122 { return 1; }   // a-z
    if c >= 65 && c <= 90  { return 1; }   // A-Z
    if c == 95 { return 1; }               // _
    return 0;
}

fn hl_is_digit(ch: str) -> int {
    let c = str::char_at(ch, 0) as int;
    if c >= 48 && c <= 57 { return 1; }    // 0-9
    return 0;
}

fn hl_is_alnum(ch: str) -> int {
    if hl_is_alpha(ch) == 1 { return 1; }
    if hl_is_digit(ch) == 1 { return 1; }
    return 0;
}

fn hl_is_kw(w: str) -> int {
    if w == "fn"       { return 1; } if w == "let"      { return 1; }
    if w == "mut"      { return 1; } if w == "return"   { return 1; }
    if w == "if"       { return 1; } if w == "elif"     { return 1; }
    if w == "else"     { return 1; } if w == "while"    { return 1; }
    if w == "for"      { return 1; } if w == "in"       { return 1; }
    if w == "use"      { return 1; } if w == "match"    { return 1; }
    if w == "tif"      { return 1; } if w == "struct"   { return 1; }
    if w == "break"    { return 1; } if w == "continue" { return 1; }
    if w == "pub"      { return 1; } if w == "impl"     { return 1; }
    return 0;
}

fn hl_is_type(w: str) -> int {
    if w == "int"    { return 1; } if w == "str"     { return 1; }
    if w == "trit"   { return 1; } if w == "tryte"   { return 1; }
    if w == "bool3"  { return 1; } if w == "bool"    { return 1; }
    if w == "Result" { return 1; } if w == "Ok"      { return 1; }
    if w == "Err"    { return 1; } if w == "Unknown" { return 1; }
    if w == "True"   { return 1; } if w == "False"   { return 1; }
    if w == "None"   { return 1; } if w == "Some"    { return 1; }
    if w == "void"   { return 1; }
    return 0;
}

// Draw selection background for characters of `line` that fall in [sel_lo, sel_hi).
// line_off = byte offset in the full text where this line starts.
// Call this BEFORE hl_draw_line so text renders on top of the highlight.
fn hl_draw_sel_bg(line: str, x: int, y: int, line_off: int, sel_lo: int, sel_hi: int) {
    if sel_lo >= sel_hi { return; }
    let llen     = str_len(line);
    let line_end = line_off + llen;
    if sel_lo >= line_end { return; }
    if sel_hi <= line_off { return; }
    let lo = int_max(sel_lo, line_off) - line_off;
    let hi = int_min(sel_hi, line_end) - line_off;
    let sx = x + gui_text_width(str_slice(line, 0, lo));
    let sw = int_max(gui_text_width(str_slice(line, lo, hi)), 3);
    c_selection();
    gui_fill_rect(sx, y, sw, L_LINE());
}

// Draw one syntax-highlighted line; returns ending x position.
fn hl_draw_line(line: str, x: int, y: int) -> int {
    let len    = str_len(line);
    let mut i  = 0;
    let mut cx = x;

    while i < len {
        let ch = str_slice(line, i, i + 1);

        // Line comment //
        if ch == "/" && i + 1 < len && str_slice(line, i + 1, i + 2) == "/" {
            c_cmt();
            let rest = str_slice(line, i, len);
            gui_draw_text(rest, cx, y);
            return cx + gui_text_width(rest);
        }

        // String literal "..."
        if ch == "\"" {
            let mut j = i + 1;
            while j < len {
                if str_slice(line, j, j + 1) == "\\" && j + 1 < len { j = j + 2; }
                elif str_slice(line, j, j + 1) == "\"" { j = j + 1; break; }
                else { j = j + 1; }
            }
            let tok = str_slice(line, i, j);
            c_str_();
            gui_draw_text(tok, cx, y);
            cx = cx + gui_text_width(tok);
            i  = j;

        // Trit literal 0t[+\-0]+
        } elif ch == "0" && i + 1 < len && str_slice(line, i + 1, i + 2) == "t" {
            let mut j = i + 2;
            while j < len {
                let c2 = str_slice(line, j, j + 1);
                if c2 == "+" || c2 == "-" || c2 == "0" { j = j + 1; } else { break; }
            }
            let tok = str_slice(line, i, j);
            c_trit();
            gui_draw_text(tok, cx, y);
            cx = cx + gui_text_width(tok);
            i  = j;

        // Number (decimal, hex prefix 0x, with . and _ separators)
        } elif hl_is_digit(ch) == 1 {
            let mut j = i + 1;
            while j < len {
                let c2 = str_slice(line, j, j + 1);
                if hl_is_digit(c2) == 1 || c2 == "." || c2 == "x" || c2 == "_" { j = j + 1; }
                else { break; }
            }
            let tok = str_slice(line, i, j);
            c_num();
            gui_draw_text(tok, cx, y);
            cx = cx + gui_text_width(tok);
            i  = j;

        // Identifier / keyword / type / function call
        } elif hl_is_alpha(ch) == 1 {
            let mut j = i + 1;
            while j < len && hl_is_alnum(str_slice(line, j, j + 1)) == 1 { j = j + 1; }
            let ident = str_slice(line, i, j);
            let after = if j < len { str_slice(line, j, j + 1) } else { "" };
            if hl_is_kw(ident) == 1     { c_kw();  }
            elif hl_is_type(ident) == 1 { c_ty();  }
            elif after == "("           { c_fn_(); }
            else                        { c_text(); }
            gui_draw_text(ident, cx, y);
            cx = cx + gui_text_width(ident);
            i  = j;

        } else {
            c_op();
            gui_draw_text(ch, cx, y);
            cx = cx + gui_text_width(ch);
            i  = i + 1;
        }
    }
    return cx;
}
