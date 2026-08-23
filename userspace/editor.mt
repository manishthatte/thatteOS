// userspace/editor.mt — thatteOS TUI Text Editor
//
// A nano-style terminal text editor.
//
// Usage:
//   editor <filename>       open file (creates if missing)
//   editor                  open empty buffer
//
// Keys:
//   ↑ ↓ ← →        move cursor (arrow keys)
//   Home / End      start / end of line
//   PgUp / PgDn     scroll one screen
//   Backspace       delete char before cursor
//   Delete          delete char at cursor
//   Enter           insert newline
//   Ctrl+S (19)     save
//   Ctrl+Q (17)     quit (prompts if unsaved changes)
//   Ctrl+F (6)      find (incremental search forward)
//   Ctrl+K (11)     delete current line
//   Tab (9)         insert 4 spaces
//
// Author: Manish Jagdish Thatte

use std::io;
use std::fs;
use std::env;

// ── key codes (from io_read_key) ─────────────────────────────────────────────

fn KEY_UP()     -> int { return 1000; }
fn KEY_DOWN()   -> int { return 1001; }
fn KEY_RIGHT()  -> int { return 1002; }
fn KEY_LEFT()   -> int { return 1003; }
fn KEY_PGUP()   -> int { return 1004; }
fn KEY_PGDN()   -> int { return 1005; }
fn KEY_HOME()   -> int { return 1006; }
fn KEY_END()    -> int { return 1007; }
fn KEY_DEL()    -> int { return 1008; }

fn CTRL_Q() -> int { return 17; }
fn CTRL_S() -> int { return 19; }
fn CTRL_F() -> int { return 6;  }
fn CTRL_K() -> int { return 11; }
fn TAB_W()  -> int { return 4;  }

// ── document helpers ──────────────────────────────────────────────────────────
// Document is a flat string with '\n' separators.

fn doc_line_count(doc: str) -> int {
    let len = str_len(doc);
    let mut n = 1;
    let mut i = 0;
    while i < len {
        if str_slice(doc, i, i + 1) == "\n" { n = n + 1; }
        i = i + 1;
    }
    return n;
}

// Byte offset of the first char of line `lnum` (0-indexed).
fn line_start(doc: str, lnum: int) -> int {
    if lnum == 0 { return 0; }
    let len  = str_len(doc);
    let mut n = 0;
    let mut i = 0;
    while i < len {
        if str_slice(doc, i, i + 1) == "\n" {
            n = n + 1;
            if n == lnum { return i + 1; }
        }
        i = i + 1;
    }
    return len;
}

// Byte offset just past the last char of line `lnum` (before the \n, or at len).
fn line_end_off(doc: str, lnum: int) -> int {
    let start = line_start(doc, lnum);
    let len   = str_len(doc);
    let mut i = start;
    while i < len {
        if str_slice(doc, i, i + 1) == "\n" { return i; }
        i = i + 1;
    }
    return len;
}

fn line_len(doc: str, lnum: int) -> int {
    return line_end_off(doc, lnum) - line_start(doc, lnum);
}

fn get_line(doc: str, lnum: int) -> str {
    let s = line_start(doc, lnum);
    let e = line_end_off(doc, lnum);
    if s >= e { return ""; }
    return str_slice(doc, s, e);
}

fn doc_insert(doc: str, pos: int, ins: str) -> str {
    let len    = str_len(doc);
    let before = str_slice(doc, 0, pos);
    let after  = str_slice(doc, pos, len);
    return str_concat(str_concat(before, ins), after);
}

fn doc_delete_at(doc: str, pos: int) -> str {
    let len = str_len(doc);
    if pos < 0 || pos >= len { return doc; }
    let before = str_slice(doc, 0, pos);
    let after  = str_slice(doc, pos + 1, len);
    return str_concat(before, after);
}

fn doc_delete_line(doc: str, lnum: int) -> str {
    let s   = line_start(doc, lnum);
    let e   = line_end_off(doc, lnum);
    let len = str_len(doc);
    let del_end = if e < len { e + 1 } else { e };
    let before  = str_slice(doc, 0, s);
    let after   = str_slice(doc, del_end, len);
    return str_concat(before, after);
}

// ── search ────────────────────────────────────────────────────────────────────

fn doc_find(doc: str, needle: str, from: int) -> int {
    let dlen = str_len(doc);
    let nlen = str_len(needle);
    if nlen == 0 { return from; }
    let mut i = from;
    while i + nlen <= dlen {
        if str_slice(doc, i, i + nlen) == needle { return i; }
        i = i + 1;
    }
    return -1;
}

fn offset_to_line(doc: str, off: int) -> int {
    let mut n = 0;
    let mut i = 0;
    while i < off {
        if str_slice(doc, i, i + 1) == "\n" { n = n + 1; }
        i = i + 1;
    }
    return n;
}

fn offset_to_col(doc: str, off: int) -> int {
    let lnum = offset_to_line(doc, off);
    return off - line_start(doc, lnum);
}

// ── rendering ─────────────────────────────────────────────────────────────────

fn render_status(path: str, total: int, row: int, col: int,
                 dirty: int, rows: int, cols: int) {
    io_move_cursor(1, 1);
    io_set_reverse();
    let fname = if str_len(path) == 0 { "[new file]" } else { path };
    let dirt  = if dirty == 1 { " [+]" } else { "" };
    let pos   = str_concat(" L", str_concat(str::from_int(row + 1),
                str_concat("/", str_concat(str::from_int(total),
                str_concat(" C", str::from_int(col + 1))))));
    let left  = str_concat(" thatteOS editor — ", str_concat(fname, dirt));
    let gap_n = cols - str_len(left) - str_len(pos);
    let mut gap = "";
    let mut g = 0;
    while g < gap_n { gap = str_concat(gap, " "); g = g + 1; }
    io::print(left);
    io::print(gap);
    io::print(pos);
    io_reset_attr();
}

fn render_hint_bar(rows: int, search_mode: int, search_buf: str) {
    io_move_cursor(rows, 1);
    io_set_reverse();
    if search_mode == 1 {
        io::print("  SEARCH: ");
        io::print(search_buf);
        io::print("_   ESC=cancel  Enter=next");
    } else {
        io::print("  ^S save   ^Q quit   ^K del-line   ^F find   arrows=move");
    }
    io_reset_attr();
}

fn render_content(doc: str, top_line: int, cur_row: int,
                  rows: int, cols: int) {
    let content_rows = rows - 2;   // row 1=status, row N=hint
    let mut r = 0;
    while r < content_rows {
        let lnum = top_line + r;
        io_move_cursor(r + 2, 1);
        let line    = get_line(doc, lnum);
        let llen    = str_len(line);
        let visible = if llen > cols { str_slice(line, 0, cols) } else { line };

        if lnum == cur_row { io_set_reverse(); }
        io::print(visible);
        // pad rest of line to clear old content
        let used  = str_len(visible);
        let pad_n = cols - used;
        let mut pad = "";
        let mut p = 0;
        while p < pad_n { pad = str_concat(pad, " "); p = p + 1; }
        io::print(pad);
        if lnum == cur_row { io_reset_attr(); }

        r = r + 1;
    }
}

fn place_cursor(top_line: int, cur_row: int, cur_col: int) {
    io_move_cursor(cur_row - top_line + 2, cur_col + 1);
}

// ── save / load ───────────────────────────────────────────────────────────────

fn do_save(path: str, doc: str) {
    fs::write_file(path, doc);
}

fn do_load(path: str) -> str {
    if str_len(path) == 0  { return ""; }
    if !fs::exists(path)   { return ""; }
    return fs::read_file(path);
}

// ── main ──────────────────────────────────────────────────────────────────────

fn main() {
    // Read argv twice so each call yields an independent string (no double-move).
    let mut save_path = if env::argc() > 1 { env::argv(1) } else { "" };
    let load_path     = if env::argc() > 1 { env::argv(1) } else { "" };
    let mut doc       = do_load(load_path);
    let mut dirty = 0;
    let mut cur_row  = 0;
    let mut cur_col  = 0;
    let mut top_line = 0;

    let mut search_mode = 0;
    let mut search_buf  = "";
    let mut search_from = 0;

    terminal_set_raw();
    io_clear_screen();

    let mut running = 1;
    while running == 1 {
        let rows = terminal_get_rows();
        let cols = terminal_get_cols();
        let content_rows = rows - 2;
        let total = doc_line_count(doc);

        // clamp cursor to document
        if cur_row >= total     { cur_row = total - 1; }
        if cur_row < 0          { cur_row = 0; }
        let cll = line_len(doc, cur_row);
        if cur_col > cll { cur_col = cll; }
        if cur_col < 0   { cur_col = 0;   }

        // scroll viewport
        if cur_row < top_line                      { top_line = cur_row; }
        if cur_row >= top_line + content_rows      { top_line = cur_row - content_rows + 1; }

        render_status(save_path, total, cur_row, cur_col, dirty, rows, cols);
        render_content(doc, top_line, cur_row, rows, cols);
        render_hint_bar(rows, search_mode, search_buf);
        place_cursor(top_line, cur_row, cur_col);

        let key = io_read_key();

        if search_mode == 1 {
            if key == 27 {   // ESC — exit search
                search_mode = 0;
                search_buf  = "";

            } elif key == 127 || key == 8 {   // Backspace
                let slen = str_len(search_buf);
                if slen > 0 { search_buf = str_slice(search_buf, 0, slen - 1); }

            } elif key == 13 || key == 10 || key == KEY_DOWN() {   // Enter/Down — next match
                let nxt = doc_find(doc, search_buf, search_from + 1);
                if nxt >= 0 {
                    cur_row     = offset_to_line(doc, nxt);
                    cur_col     = offset_to_col(doc, nxt);
                    search_from = nxt;
                }

            } elif key >= 32 && key < 127 {
                // Build char string from keycode — use str::from_int trick via runtime
                // str_from_char takes i8; we build a single-byte string manually
                let ch_s = str_slice("                                                  ",
                                     0, 1);   // placeholder space, will be replaced below
                // Use the char code directly: io_read_key gave us ASCII value,
                // build the byte string by inserting into a space char
                // Simplest approach: use the existing str_from_char (i8-based)
                // via cast — acceptable since key is ASCII 32-126 (fits i8)
                search_buf  = str_concat(search_buf, str_from_char(key));
                let off_now = line_start(doc, cur_row) + cur_col;
                let found   = doc_find(doc, search_buf, off_now);
                if found >= 0 {
                    cur_row     = offset_to_line(doc, found);
                    cur_col     = offset_to_col(doc, found);
                    search_from = found;
                }
            }

        } else {

            if key == CTRL_Q() {
                if dirty == 1 {
                    terminal_set_cooked();
                    io_clear_screen();
                    io::print("  Unsaved changes. Quit? [y/N] ");
                    let ans = str_trim(io::read_line());
                    terminal_set_raw();
                    if ans == "y" || ans == "Y" { running = 0; }
                } else {
                    running = 0;
                }

            } elif key == CTRL_S() {
                if str_len(save_path) == 0 {
                    terminal_set_cooked();
                    io_clear_screen();
                    io::print("  Save as: ");
                    let new_path = str_trim(io::read_line());
                    terminal_set_raw();
                    if str_len(new_path) > 0 {
                        save_path = str_concat(new_path, "");
                        do_save(save_path, doc);
                        dirty = 0;
                    }
                } else {
                    do_save(save_path, doc);
                    dirty = 0;
                }

            } elif key == CTRL_F() {
                search_mode = 1;
                search_buf  = "";
                search_from = line_start(doc, cur_row) + cur_col;

            } elif key == CTRL_K() {
                if doc_line_count(doc) > 1 {
                    doc   = doc_delete_line(doc, cur_row);
                    dirty = 1;
                    let nt = doc_line_count(doc);
                    if cur_row >= nt { cur_row = nt - 1; }
                } else {
                    doc   = "";
                    dirty = 1;
                }

            } elif key == KEY_UP() {
                if cur_row > 0 { cur_row = cur_row - 1; }

            } elif key == KEY_DOWN() {
                if cur_row < doc_line_count(doc) - 1 { cur_row = cur_row + 1; }

            } elif key == KEY_LEFT() {
                if cur_col > 0 {
                    cur_col = cur_col - 1;
                } elif cur_row > 0 {
                    cur_row = cur_row - 1;
                    cur_col = line_len(doc, cur_row);
                }

            } elif key == KEY_RIGHT() {
                let ll = line_len(doc, cur_row);
                if cur_col < ll {
                    cur_col = cur_col + 1;
                } elif cur_row < doc_line_count(doc) - 1 {
                    cur_row = cur_row + 1;
                    cur_col = 0;
                }

            } elif key == KEY_HOME() {
                cur_col = 0;

            } elif key == KEY_END() {
                cur_col = line_len(doc, cur_row);

            } elif key == KEY_PGUP() {
                cur_row = cur_row - content_rows;
                if cur_row < 0 { cur_row = 0; }

            } elif key == KEY_PGDN() {
                let nt2 = doc_line_count(doc);
                cur_row = cur_row + content_rows;
                if cur_row >= nt2 { cur_row = nt2 - 1; }

            } elif key == 127 || key == 8 {   // Backspace
                if cur_col > 0 {
                    let off = line_start(doc, cur_row) + cur_col - 1;
                    doc     = doc_delete_at(doc, off);
                    cur_col = cur_col - 1;
                    dirty   = 1;
                } elif cur_row > 0 {
                    let prev_len = line_len(doc, cur_row - 1);
                    let nl_off   = line_start(doc, cur_row) - 1;
                    doc     = doc_delete_at(doc, nl_off);
                    cur_row = cur_row - 1;
                    cur_col = prev_len;
                    dirty   = 1;
                }

            } elif key == KEY_DEL() {   // Forward delete
                let del_off = line_start(doc, cur_row) + cur_col;
                let dlen    = str_len(doc);
                if del_off < dlen {
                    doc   = doc_delete_at(doc, del_off);
                    dirty = 1;
                }

            } elif key == 13 || key == 10 {   // Enter — newline
                let ins_off = line_start(doc, cur_row) + cur_col;
                doc     = doc_insert(doc, ins_off, "\n");
                cur_row = cur_row + 1;
                cur_col = 0;
                dirty   = 1;

            } elif key == 9 {   // Tab → 4 spaces
                let tab_off = line_start(doc, cur_row) + cur_col;
                doc     = doc_insert(doc, tab_off, "    ");
                cur_col = cur_col + TAB_W();
                dirty   = 1;

            } elif key >= 32 && key < 127 {   // printable ASCII
                let ch_off = line_start(doc, cur_row) + cur_col;
                doc     = doc_insert(doc, ch_off, str_from_char(key));
                cur_col = cur_col + 1;
                dirty   = 1;
            }
        }
    }

    terminal_set_cooked();
    io_clear_screen();
    io::println("  editor: bye.");
}
