// studioMani/buffer.mt — gap buffer, cursor navigation, undo/redo
// Representation: buf = pre + SEP + post  (SEP = "\r", never appears in source)
// Author: Manish Jagdish Thatte

fn SEP() -> str { return "\r"; }

// ── Construction ──────────────────────────────────────────────────────────────
fn buf_new(content: str) -> str { return str_concat(content, str_concat(SEP(), "")); }
fn buf_empty()            -> str { return str_concat("", str_concat(SEP(), "")); }

// ── Internal accessors ────────────────────────────────────────────────────────
fn buf_pre(b: str) -> str {
    let len = str_len(b);
    let mut i = 0;
    while i < len {
        if str_slice(b, i, i + 1) == SEP() { return str_slice(b, 0, i); }
        i = i + 1;
    }
    return b;
}

fn buf_post(b: str) -> str {
    let len = str_len(b);
    let mut i = 0;
    while i < len {
        if str_slice(b, i, i + 1) == SEP() { return str_slice(b, i + 1, len); }
        i = i + 1;
    }
    return "";
}

fn buf_pack(pre: str, post: str) -> str { return str_concat(pre, str_concat(SEP(), post)); }
fn buf_text(b: str)               -> str { return str_concat(buf_pre(b), buf_post(b)); }

// ── Editing ───────────────────────────────────────────────────────────────────
fn buf_insert(b: str, ch: str) -> str {
    return buf_pack(str_concat(buf_pre(b), ch), buf_post(b));
}

fn buf_backspace(b: str) -> str {
    let pre = buf_pre(b);
    let n   = str_len(pre);
    if n == 0 { return b; }
    return buf_pack(str_slice(pre, 0, n - 1), buf_post(b));
}

fn buf_delete(b: str) -> str {
    let post = buf_post(b);
    let n    = str_len(post);
    if n == 0 { return b; }
    return buf_pack(buf_pre(b), str_slice(post, 1, n));
}

// Delete from cursor to end of word (Ctrl+Delete)
fn buf_delete_word_right(b: str) -> str {
    let post = buf_post(b);
    let n    = str_len(post);
    if n == 0 { return b; }
    let mut i = 0;
    // skip non-alnum
    while i < n && str_slice(post, i, i + 1) == " " { i = i + 1; }
    // skip alnum
    while i < n {
        let ch = str_slice(post, i, i + 1);
        if ch == " " || ch == "\n" || ch == "(" || ch == ")" || ch == ";" { i = i + 1; break; }
        i = i + 1;
    }
    return buf_pack(buf_pre(b), str_slice(post, i, n));
}

// ── Cursor movement ───────────────────────────────────────────────────────────
fn buf_right(b: str) -> str {
    let post = buf_post(b);
    if str_len(post) == 0 { return b; }
    return buf_pack(str_concat(buf_pre(b), str_slice(post, 0, 1)),
                    str_slice(post, 1, str_len(post)));
}

fn buf_left(b: str) -> str {
    let pre = buf_pre(b);
    let n   = str_len(pre);
    if n == 0 { return b; }
    return buf_pack(str_slice(pre, 0, n - 1),
                    str_concat(str_slice(pre, n - 1, n), buf_post(b)));
}

fn buf_word_right(b: str) -> str {
    let post = buf_post(b);
    let n    = str_len(post);
    if n == 0 { return b; }
    let mut cur = b;
    let mut i = 0;
    // skip whitespace
    while i < n && str_slice(post, i, i + 1) == " " { cur = buf_right(cur); i = i + 1; }
    // skip word chars
    while i < n {
        let ch = str_slice(post, i, i + 1);
        if ch == " " || ch == "\n" || ch == "(" || ch == ")" { break; }
        cur = buf_right(cur);
        i = i + 1;
    }
    return cur;
}

fn buf_word_left(b: str) -> str {
    let pre = buf_pre(b);
    let n   = str_len(pre);
    if n == 0 { return b; }
    let mut cur = b;
    let mut i = n;
    // skip whitespace
    while i > 0 && str_slice(pre, i - 1, i) == " " { cur = buf_left(cur); i = i - 1; }
    // skip word chars
    while i > 0 {
        let ch = str_slice(pre, i - 1, i);
        if ch == " " || ch == "\n" || ch == "(" || ch == ")" { break; }
        cur = buf_left(cur);
        i = i - 1;
    }
    return cur;
}

// ── Cursor position queries ───────────────────────────────────────────────────
fn buf_line(b: str) -> int {
    let pre = buf_pre(b);
    let len = str_len(pre);
    let mut n = 0;
    let mut i = 0;
    while i < len { if str_slice(pre, i, i + 1) == "\n" { n = n + 1; } i = i + 1; }
    return n;
}

fn buf_col(b: str) -> int {
    let pre = buf_pre(b);
    let len = str_len(pre);
    let mut col = 0;
    let mut i   = len;
    while i > 0 && str_slice(pre, i - 1, i) != "\n" { col = col + 1; i = i - 1; }
    return col;
}

fn buf_cursor_offset(b: str) -> int { return str_len(buf_pre(b)); }

fn buf_line_count(b: str) -> int {
    let text = buf_text(b);
    let len  = str_len(text);
    let mut n = 1;
    let mut i = 0;
    while i < len { if str_slice(text, i, i + 1) == "\n" { n = n + 1; } i = i + 1; }
    return n;
}

fn buf_get_line(b: str, n: int) -> str {
    let text = buf_text(b);
    let len  = str_len(text);
    let mut cur = 0;
    let mut i   = 0;
    let mut out = "";
    while i < len {
        let ch = str_slice(text, i, i + 1);
        if ch == "\n" {
            if cur == n { return out; }
            cur = cur + 1;
            out = "";
        } else {
            if cur == n { out = str_concat(out, ch); }
        }
        i = i + 1;
    }
    if cur == n { return out; }
    return "";
}

// ── Line-level navigation ─────────────────────────────────────────────────────
fn buf_home(b: str) -> str {
    let pre = buf_pre(b);
    let len = str_len(pre);
    let mut i = len;
    while i > 0 && str_slice(pre, i - 1, i) != "\n" { i = i - 1; }
    // skip leading spaces (smart home: go to first non-space, then to col 0)
    let tail = str_slice(pre, i, len);
    return buf_pack(str_slice(pre, 0, i), str_concat(tail, buf_post(b)));
}

fn buf_end(b: str) -> str {
    let post = buf_post(b);
    let len  = str_len(post);
    let mut i = 0;
    while i < len && str_slice(post, i, i + 1) != "\n" { i = i + 1; }
    return buf_pack(str_concat(buf_pre(b), str_slice(post, 0, i)),
                    str_slice(post, i, len));
}

fn buf_up(b: str) -> str {
    let pre     = buf_pre(b);
    let pre_len = str_len(pre);
    let mut col = 0;
    let mut i   = pre_len;
    while i > 0 && str_slice(pre, i - 1, i) != "\n" { col = col + 1; i = i - 1; }
    if i == 0 { return b; }
    let prev_end = i - 1;
    let mut j    = prev_end;
    while j > 0 && str_slice(pre, j - 1, j) != "\n" { j = j - 1; }
    let prev_len = prev_end - j;
    let new_col  = int_min(col, prev_len);
    let full     = buf_text(b);
    let nc       = j + new_col;
    return buf_pack(str_slice(full, 0, nc), str_slice(full, nc, str_len(full)));
}

fn buf_down(b: str) -> str {
    let pre      = buf_pre(b);
    let post     = buf_post(b);
    let pre_len  = str_len(pre);
    let post_len = str_len(post);
    let mut col  = 0;
    let mut i    = pre_len;
    while i > 0 && str_slice(pre, i - 1, i) != "\n" { col = col + 1; i = i - 1; }
    let mut j    = 0;
    while j < post_len && str_slice(post, j, j + 1) != "\n" { j = j + 1; }
    if j >= post_len { return b; }
    let next_start = j + 1;
    let mut k      = next_start;
    while k < post_len && str_slice(post, k, k + 1) != "\n" { k = k + 1; }
    let next_len = k - next_start;
    let new_col  = int_min(col, next_len);
    let full     = buf_text(b);
    let nc       = pre_len + next_start + new_col;
    return buf_pack(str_slice(full, 0, nc), str_slice(full, nc, str_len(full)));
}

// Go to specific line number (0-indexed)
fn buf_goto_line(b: str, target: int) -> str {
    let text = buf_text(b);
    let len  = str_len(text);
    let mut cur = 0;
    let mut i   = 0;
    while i < len {
        if cur == target {
            return buf_pack(str_slice(text, 0, i), str_slice(text, i, len));
        }
        if str_slice(text, i, i + 1) == "\n" { cur = cur + 1; }
        i = i + 1;
    }
    // target beyond end: go to last line
    return buf_pack(text, "");
}

// ── Auto-indent helper ────────────────────────────────────────────────────────
fn buf_leading_spaces(line: str) -> str {
    let len = str_len(line);
    let mut i = 0;
    let mut out = "";
    while i < len && str_slice(line, i, i + 1) == " " {
        out = str_concat(out, " ");
        i = i + 1;
    }
    return out;
}

// Insert newline with auto-indent matching previous line
fn buf_newline_indent(b: str) -> str {
    let ln   = buf_line(b);
    let line = buf_get_line(b, ln);
    let indent = buf_leading_spaces(line);
    // Extra indent after {
    let cur_col = buf_col(b);
    let extra = if cur_col > 0 && str_slice(line, cur_col - 1, cur_col) == "{" { "    " } else { "" };
    return buf_insert(b, str_concat("\n", str_concat(indent, extra)));
}

// ── Selection helpers ─────────────────────────────────────────────────────────
fn sel_text(b: str, sel_start: int, sel_end: int) -> str {
    let text = buf_text(b);
    let lo = int_min(sel_start, sel_end);
    let hi = int_max(sel_start, sel_end);
    let tlen = str_len(text);
    if lo < 0 { return ""; }
    if hi > tlen { return ""; }
    return str_slice(text, lo, hi);
}

fn buf_delete_selection(b: str, sel_start: int, sel_end: int) -> str {
    let text = buf_text(b);
    let lo   = int_min(sel_start, sel_end);
    let hi   = int_max(sel_start, sel_end);
    let tlen = str_len(text);
    let new_text = str_concat(str_slice(text, 0, lo), str_slice(text, hi, tlen));
    return buf_pack(str_slice(new_text, 0, lo), str_slice(new_text, lo, str_len(new_text)));
}

fn buf_replace_all(b: str, from: str, to: str) -> str {
    let text = buf_text(b);
    let flen = str_len(from);
    let tlen = str_len(to);
    let slen = str_len(text);
    if flen == 0 { return b; }
    let mut out = "";
    let mut i   = 0;
    while i <= slen - flen {
        if str_slice(text, i, i + flen) == from {
            out = str_concat(out, to);
            i   = i + flen;
        } else {
            out = str_concat(out, str_slice(text, i, i + 1));
            i   = i + 1;
        }
    }
    while i < slen { out = str_concat(out, str_slice(text, i, i + 1)); i = i + 1; }
    return buf_new(out);
}

// ── Find ──────────────────────────────────────────────────────────────────────
fn find_first(text: str, query: str) -> int {
    let tlen = str_len(text);
    let qlen = str_len(query);
    if qlen == 0 { return -1; }
    let mut i = 0;
    while i <= tlen - qlen {
        if str_slice(text, i, i + qlen) == query { return i; }
        i = i + 1;
    }
    return -1;
}

// Find next occurrence after 'from' offset
fn find_next(text: str, query: str, from: int) -> int {
    let tlen = str_len(text);
    let qlen = str_len(query);
    if qlen == 0 { return -1; }
    let mut i = from + 1;
    while i <= tlen - qlen {
        if str_slice(text, i, i + qlen) == query { return i; }
        i = i + 1;
    }
    return -1;
}

// ── Undo / Redo ───────────────────────────────────────────────────────────────
fn UNDO_SEP() -> str { return "\r"; }

fn undo_push(stack: str, snapshot: str) -> str {
    return str_concat(stack, str_concat(snapshot, UNDO_SEP()));
}

fn undo_pop(stack: str) -> str {
    let len = str_len(stack);
    if len == 0 { return ""; }
    let mut end = len;
    if str_slice(stack, len - 1, len) == UNDO_SEP() { end = len - 1; }
    let mut i = end - 1;
    while i > 0 {
        if str_slice(stack, i, i + 1) == UNDO_SEP() { return str_slice(stack, i + 1, end); }
        i = i - 1;
    }
    return str_slice(stack, 0, end);
}

fn undo_stack_without_last(stack: str) -> str {
    let len = str_len(stack);
    if len == 0 { return ""; }
    let mut end = len;
    if str_slice(stack, len - 1, len) == UNDO_SEP() { end = len - 1; }
    let mut i = end - 1;
    while i > 0 {
        if str_slice(stack, i, i + 1) == UNDO_SEP() { return str_slice(stack, 0, i + 1); }
        i = i - 1;
    }
    return "";
}
