// studioMani/studioMani/terminal.mt — embedded terminal with command history
// Uses shell_exec to run commands and capture output.
// Depends on: theme.mt, layout.mt (draw_scrollbar, text_get_line, text_line_count)
// Author: Manish Jagdish Thatte

// Strip basic ANSI escape sequences (\033[...m and \033[...;...m) from text.
fn strip_ansi(s: str) -> str {
    let len    = str_len(s);
    let mut out = "";
    let mut i   = 0;
    while i < len {
        let ch = str_slice(s, i, i + 1);
        // ESC char: skip until 'm'
        if ch == "\\" && i + 1 < len && str_slice(s, i + 1, i + 2) == "0" &&
           i + 2 < len && str_slice(s, i + 2, i + 3) == "3" &&
           i + 3 < len && str_slice(s, i + 3, i + 4) == "3" {
            // Skip \033[...m
            i = i + 4;
            while i < len && str_slice(s, i, i + 1) != "m" { i = i + 1; }
            i = i + 1;
        } else {
            out = str_concat(out, ch);
            i   = i + 1;
        }
    }
    return out;
}

// Retrieve command from history (newline-delimited) at index from the end.
// idx 0 = most recent command.
fn term_hist_get(history: str, idx: int) -> str {
    let n = text_line_count(history);
    if n == 0 { return ""; }
    let target = n - 1 - idx;
    if target < 0 { return ""; }
    return text_get_line(history, target);
}

// Add command to history (dedup consecutive). Returns new history string.
fn term_hist_push(history: str, cmd: str) -> str {
    if str_len(cmd) == 0 { return history; }
    // Don't add duplicate of most recent
    let n = text_line_count(history);
    if n > 0 && text_get_line(history, n - 1) == cmd { return history; }
    if str_len(history) == 0 { return cmd; }
    return str_concat(history, str_concat("\n", cmd));
}

fn draw_terminal(term_output: str, cmd_buf: str,
                 term_scroll: int, top_y: int, bot_y: int,
                 mx: int, my: int) {
    let ww = gui_window_width();
    let fh = gui_font_height();

    // Dark background
    gui_set_color(18, 18, 18, 255);
    gui_fill_rect(0, top_y, ww, bot_y - top_y);

    // Prompt bar at bottom
    let prompt_h = 30;
    let prompt_y = bot_y - prompt_h;
    gui_set_color(24, 24, 24, 255);
    gui_fill_rect(0, prompt_y, ww, prompt_h);
    gui_set_color(50, 50, 50, 255);
    gui_draw_line(0, prompt_y, ww, prompt_y);

    // Prompt symbol
    gui_set_color(0, 200, 100, 255);
    gui_draw_text("$ ", L_MARGIN(), prompt_y + (prompt_h - fh) / 2);
    let px2 = L_MARGIN() + gui_text_width("$ ");
    gui_set_color(220, 220, 220, 255);
    gui_draw_text(cmd_buf, px2, prompt_y + (prompt_h - fh) / 2);
    // Blinking cursor (always shown — no blink state in this render)
    let ccw = gui_text_width(cmd_buf);
    gui_set_color(200, 200, 200, 255);
    gui_fill_rect(px2 + ccw, prompt_y + 6, 2, prompt_h - 12);

    // Output area
    let out_top  = top_y + 4;
    let out_bot  = prompt_y - 4;
    let vis      = (out_bot - out_top) / L_LINE();
    let total    = text_line_count(term_output);

    let mut r = 0;
    while r < vis {
        let ln = term_scroll + r;
        if ln < total {
            let line = text_get_line(term_output, ln);
            let ry   = out_top + r * L_LINE();
            // Color coding
            let llen = str_len(line);
            if llen == 0 {
                r = r + 1;
            } else {
                let ch0 = str_slice(line, 0, 1);
                if ch0 == "$" {
                    gui_set_color(0, 200, 100, 255);
                } elif str::starts_with(line, "error") || str::starts_with(line, "Error") ||
                       str::starts_with(line, "ERROR") || str::starts_with(line, "fatal") {
                    gui_set_color(230, 80, 80, 255);
                } elif str::starts_with(line, "warning") || str::starts_with(line, "Warning") {
                    gui_set_color(220, 180, 60, 255);
                } elif str::starts_with(line, "==>") || str::starts_with(line, ">>>") {
                    gui_set_color(100, 180, 230, 255);
                } else {
                    gui_set_color(200, 200, 200, 255);
                }
                gui_draw_text(line, L_MARGIN(), ry + (L_LINE() - fh) / 2);
                r = r + 1;
            }
        } else {
            r = r + 1;
        }
    }

    draw_scrollbar(ww - 10, out_top, out_bot - out_top, total, vis, term_scroll);
}

// ── TerminalState ─────────────────────────────────────────────────────────────
struct TerminalState {
    pub term_output:   str,
    pub term_cmd:      str,
    pub term_hist:     str,
    pub term_hist_idx: int,
    pub term_scroll:   int,
}

fn terminal_state_init() -> TerminalState {
    return TerminalState {
        term_output: "studioMani terminal\n$ ",
        term_cmd: "", term_hist: "", term_hist_idx: -1, term_scroll: 0,
    };
}
