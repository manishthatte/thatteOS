// userspace/browser.mt — THATTEOS Text Web Browser
//
// Fetches HTTP/HTTPS pages via libcurl and renders them as readable text
// in the terminal.  Supports keyboard paging and URL history.
//
// Commands at the prompt:
//   <url>    fetch and display URL
//   back     go to previous page
//   history  show URL history
//   quit     exit
//
// During page display:
//   Space / n    next screen
//   b            previous screen
//   q            back to prompt
//
// Author: Manish Jagdish Thatte

use std::io;

// ── HTML stripping ──────────────────────────────────────────────────────────

// Returns 1 if character at position i in s is inside a tag < ... >
// We scan linearly since ManiT has no regex.

fn strip_html(raw: str) -> str {
    let len     = str_len(raw);
    let mut out = "";
    let mut i   = 0;
    let mut in_tag    = 0;
    let mut in_script = 0;
    let mut in_style  = 0;

    while i < len {
        let ch = str_slice(raw, i, i + 1);

        if in_tag == 1 {
            if ch == ">" {
                in_tag = 0;
            }
            // detect </script> and </style> ends
            i = i + 1;

        } elif ch == "<" {
            in_tag = 1;
            // detect block-level tags that should produce newlines
            let peek8 = str_to_lower(str_slice(raw, i, i + 8));
            if str_starts_with(peek8, "<br") ||
               str_starts_with(peek8, "<p") ||
               str_starts_with(peek8, "<tr") ||
               str_starts_with(peek8, "<li") ||
               str_starts_with(peek8, "<h1") ||
               str_starts_with(peek8, "<h2") ||
               str_starts_with(peek8, "<h3") ||
               str_starts_with(peek8, "<h4") ||
               str_starts_with(peek8, "<h5") ||
               str_starts_with(peek8, "<h6") ||
               str_starts_with(peek8, "</div") ||
               str_starts_with(peek8, "</p>") {
                out = str_concat(out, "\n");
            }
            i = i + 1;

        } elif ch == "&" {
            // decode common HTML entities
            let ent6 = str_slice(raw, i, i + 6);
            if str_starts_with(ent6, "&amp;")  { out = str_concat(out, "&");  i = i + 5; }
            elif str_starts_with(ent6, "&lt;")  { out = str_concat(out, "<");  i = i + 4; }
            elif str_starts_with(ent6, "&gt;")  { out = str_concat(out, ">");  i = i + 4; }
            elif str_starts_with(ent6, "&nbsp;") { out = str_concat(out, " ");  i = i + 6; }
            elif str_starts_with(ent6, "&quot;") { out = str_concat(out, "\""); i = i + 6; }
            elif str_starts_with(ent6, "&#39;")  { out = str_concat(out, "'");  i = i + 5; }
            else { out = str_concat(out, ch); i = i + 1; }

        } elif ch == "\r" {
            i = i + 1;  // skip CR

        } else {
            out = str_concat(out, ch);
            i   = i + 1;
        }
    }
    return out;
}

// Collapse runs of blank lines (> 2 consecutive \n) to at most 2
fn collapse_blanks(s: str) -> str {
    let len     = str_len(s);
    let mut out = "";
    let mut nl  = 0;
    let mut i   = 0;
    while i < len {
        let ch = str_slice(s, i, i + 1);
        if ch == "\n" {
            nl = nl + 1;
            if nl <= 2 { out = str_concat(out, "\n"); }
        } else {
            nl = 0;
            out = str_concat(out, ch);
        }
        i = i + 1;
    }
    return out;
}

// ── pagination ──────────────────────────────────────────────────────────────

// Count lines in text
fn count_lines(s: str) -> int {
    let len  = str_len(s);
    let mut n = 1;
    let mut i = 0;
    while i < len {
        if str_slice(s, i, i + 1) == "\n" { n = n + 1; }
        i = i + 1;
    }
    return n;
}

// Return lines [start, start+height) from text, 0-indexed
fn page_slice(s: str, start_line: int, height: int) -> str {
    let len      = str_len(s);
    let mut line = 0;
    let mut i    = 0;
    let mut out  = "";
    let end_line = start_line + height;

    while i < len {
        let ch = str_slice(s, i, i + 1);
        if line >= start_line && line < end_line {
            out = str_concat(out, ch);
        }
        if ch == "\n" {
            line = line + 1;
            if line >= end_line { return out; }
        }
        i = i + 1;
    }
    return out;
}

fn display_page(text: str, start_line: int, page_h: int,
                url: str, total_lines: int) {
    io_clear_screen();
    // status bar top
    io_move_cursor(1, 1);
    io_set_bold();
    io::print("  ");
    io::println(url);
    io_reset_attr();

    // content
    io::print(page_slice(text, start_line, page_h));

    // bottom bar
    let end_line = start_line + page_h;
    let pct = if total_lines > 0 { (end_line * 100) / total_lines } else { 100 };
    io_move_cursor(page_h + 2, 1);
    io::print("  [line ");
    io::print_int(start_line + 1);
    io::print("/");
    io::print_int(total_lines);
    io::print("  ");
    io::print_int(pct);
    io::print("%]   Space/n:next  b:prev  q:prompt");
}

fn view_page(text: str, url: str) {
    let rows     = terminal_get_rows();
    let page_h   = rows - 3;
    let total    = count_lines(text);
    let mut line = 0;
    let mut paging = 1;

    terminal_set_raw();

    while paging == 1 {
        display_page(text, line, page_h, url, total);
        let key = io_read_key();

        if key == 113 || key == 27 {       // q or ESC
            paging = 0;
        } elif key == 32 || key == 110 || key == 1001 {  // Space, n, Down
            line = line + page_h;
            if line >= total { line = total - page_h; }
            if line < 0 { line = 0; }
        } elif key == 98 || key == 1000 {  // b, Up
            line = line - page_h;
            if line < 0 { line = 0; }
        } elif key == 1006 {               // Home
            line = 0;
        } elif key == 1007 {               // End
            line = total - page_h;
            if line < 0 { line = 0; }
        }
    }

    terminal_set_cooked();
}

// ── URL history ─────────────────────────────────────────────────────────────
// Store up to 20 history entries as a single newline-separated string

fn history_add(hist: str, url: str) -> str {
    return str_concat(hist, str_concat(url, "\n"));
}

fn history_last(hist: str) -> str {
    // find second-to-last newline
    let len = str_len(hist);
    if len == 0 { return ""; }
    // skip trailing newline
    let mut end = len - 1;
    let mut i   = end - 1;
    while i >= 0 {
        if str_slice(hist, i, i + 1) == "\n" {
            return str_slice(hist, i + 1, end);
        }
        i = i - 1;
    }
    return str_slice(hist, 0, end);
}

fn history_pop(hist: str) -> str {
    // remove last entry
    let len = str_len(hist);
    if len == 0 { return ""; }
    let mut end = len - 1;  // skip trailing \n
    let mut i   = end - 1;
    while i >= 0 {
        if str_slice(hist, i, i + 1) == "\n" { return str_slice(hist, 0, i + 1); }
        i = i - 1;
    }
    return "";
}

fn print_history(hist: str) {
    io::println("  --- URL history ---");
    let len = str_len(hist);
    let mut i   = 0;
    let mut n   = 1;
    let mut cur = "";
    while i < len {
        let ch = str_slice(hist, i, i + 1);
        if ch == "\n" {
            if str_len(cur) > 0 {
                io::print("  ");
                io::print_int(n);
                io::print(". ");
                io::println(cur);
                n   = n + 1;
                cur = "";
            }
        } else {
            cur = str_concat(cur, ch);
        }
        i = i + 1;
    }
}

// ── main ────────────────────────────────────────────────────────────────────

fn main() {
    io::println("=== THATTEOS browser — text web browser ===");
    io::println("  HTTP/HTTPS via libcurl.  Type a URL or 'quit'.");
    io::println("  Commands: <url>  back  history  quit");
    io::println("");

    let mut history  = "";
    let mut running  = 1;
    let mut last_url = "";

    while running == 1 {
        io::print("browser> ");
        let raw  = io::read_line();
        let line = str_trim(raw);

        if line == "" {
            // skip

        } elif line == "quit" || line == "exit" {
            running = 0;

        } elif line == "back" {
            if str_len(history) == 0 {
                io::println("  (no history)");
            } else {
                // pop current from history and go to previous
                history = history_pop(history);
                if str_len(history_last(history)) == 0 {
                    io::println("  (no previous page)");
                } else {
                    io::print("  fetching: ");
                    io::println(history_last(history));
                    let raw_html = net_http_get(history_last(history));
                    if str_len(raw_html) == 0 {
                        io::println("  (empty response)");
                    } else {
                        let text = collapse_blanks(strip_html(raw_html));
                        last_url = history_last(history);
                        view_page(text, history_last(history));
                    }
                }
            }

        } elif line == "history" {
            print_history(history);

        } else {
            // treat as URL — add https:// if no scheme
            // store in last_url so we can reuse without moving
            let has_scheme = str_starts_with(line, "http://") ||
                             str_starts_with(line, "https://");
            last_url = if has_scheme { line } else { str_concat("https://", line) };

            io::print("  fetching: ");
            io::println(last_url);
            let raw_html = net_http_get(last_url);

            if str_starts_with(raw_html, "(curl error:") {
                io::print("  ERROR: ");
                io::println(raw_html);
            } elif str_len(raw_html) == 0 {
                io::println("  (empty response)");
            } else {
                let text = collapse_blanks(strip_html(raw_html));
                history  = history_add(history, last_url);
                view_page(text, last_url);
            }
        }
    }

    io::println("  bye.");
}
