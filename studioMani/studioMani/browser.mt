// studioMani/studioMani/browser.mt — HTTP text browser with history
// strip_html, collapse_blanks, history helpers, draw_browser
// Depends on: theme.mt, layout.mt (draw_btn, draw_scrollbar, text_get_line, text_line_count)
// Author: Manish Jagdish Thatte

// ── HTML stripping ────────────────────────────────────────────────────────────
fn strip_html(raw: str) -> str {
    let len    = str_len(raw);
    let mut out    = "";
    let mut in_tag = 0;
    let mut i      = 0;
    while i < len {
        let ch = str_slice(raw, i, i + 1);
        if in_tag == 1 {
            if ch == ">" { in_tag = 0; }
            i = i + 1;
        } elif ch == "<" {
            in_tag = 1;
            let p = str::to_lower(str_slice(raw, i, i + 5));
            if str::starts_with(p, "<br")  || str::starts_with(p, "<p")  ||
               str::starts_with(p, "<tr")  || str::starts_with(p, "<li") ||
               str::starts_with(p, "<h")   || str::starts_with(p, "</p") ||
               str::starts_with(p, "</di") || str::starts_with(p, "<div") {
                out = str_concat(out, "\n");
            }
            i = i + 1;
        } elif ch == "&" {
            let e = str_slice(raw, i, i + 7);
            if str::starts_with(e, "&amp;")   { out = str_concat(out, "&");  i = i + 5; }
            elif str::starts_with(e, "&lt;")  { out = str_concat(out, "<");  i = i + 4; }
            elif str::starts_with(e, "&gt;")  { out = str_concat(out, ">");  i = i + 4; }
            elif str::starts_with(e, "&nbsp;") { out = str_concat(out, " "); i = i + 6; }
            elif str::starts_with(e, "&quot;") { out = str_concat(out, "\""); i = i + 6; }
            elif str::starts_with(e, "&#39;")  { out = str_concat(out, "'"); i = i + 5; }
            else { out = str_concat(out, ch); i = i + 1; }
        } elif ch == "\r" {
            i = i + 1;
        } else {
            out = str_concat(out, ch);
            i   = i + 1;
        }
    }
    return out;
}

fn collapse_blanks(s: str) -> str {
    let len    = str_len(s);
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

// ── History helpers ───────────────────────────────────────────────────────────
// History is a "\n"-delimited stack of visited URLs.

fn hist_push(stack: str, url: str) -> str {
    if str_len(url) == 0 { return stack; }
    if str_len(stack) == 0 { return url; }
    return str_concat(stack, str_concat("\n", url));
}

// Returns the most recent URL before the current one (for Back).
// hist_pos = current position from the end (0=latest).
fn hist_back_url(stack: str, hist_pos: int) -> str {
    let n = text_line_count(stack);
    if n == 0 { return ""; }
    let idx = n - 1 - hist_pos - 1;
    if idx < 0 { return ""; }
    return text_get_line(stack, idx);
}

fn hist_fwd_url(stack: str, hist_pos: int) -> str {
    if hist_pos <= 0 { return ""; }
    let n = text_line_count(stack);
    let idx = n - 1 - hist_pos + 1;
    if idx >= n { return ""; }
    return text_get_line(stack, idx);
}

// ── Browser draw ──────────────────────────────────────────────────────────────
fn draw_browser(url_buf: str, content: str, br_total: int, br_scroll: int,
                status: str, nav: NavState, v: View) {
    let ww  = gui_window_width();
    let fh  = gui_font_height();

    c_editor();
    gui_fill_rect(0, v.top_y, ww, v.bot_y - v.top_y);

    // Address bar
    let addr_h = 36;
    let addr_y = v.top_y;
    gui_set_color(238, 232, 213, 255);
    gui_fill_rect(0, addr_y, ww, addr_h);
    c_border();
    gui_draw_line(0, addr_y + addr_h, ww, addr_y + addr_h);

    let btn_y = addr_y + 4;
    let btn_h = addr_h - 8;

    // Back / Fwd / Refresh buttons
    if nav.can_back == 1 { c_accent(); } else { c_dim(); }
    let bx2  = draw_btn("◀", L_MARGIN(), btn_y, 32, btn_h, v.mx, v.my);
    if nav.can_fwd == 1 { c_accent(); } else { c_dim(); }
    let bx3  = draw_btn("▶", bx2, btn_y, 32, btn_h, v.mx, v.my);
    let bx4  = draw_btn("↺", bx3, btn_y, 32, btn_h, v.mx, v.my);
    let go_x = ww - L_MARGIN() - 48;
    draw_btn_accent("Go", go_x, btn_y, 48, btn_h, v.mx, v.my);

    // URL box
    let box_x = bx4 + 4;
    let box_w = go_x - box_x - 8;
    let box_y = addr_y + 4;
    let box_h = addr_h - 8;
    if nav.addr_focused == 1 { gui_set_color(253, 246, 227, 255); }
    else                 { gui_set_color(245, 238, 220, 255); }
    gui_fill_rect(box_x, box_y, box_w, box_h);
    if nav.addr_focused == 1 { c_accent(); } else { c_border(); }
    gui_draw_rect(box_x, box_y, box_w, box_h);
    if str_len(url_buf) == 0 {
        c_dim();
        gui_draw_text("Enter URL and press Enter…", box_x + 6, box_y + (box_h - fh) / 2);
    } else {
        c_white();
        gui_draw_text(url_buf, box_x + 6, box_y + (box_h - fh) / 2);
    }
    if nav.addr_focused == 1 {
        let ucw = gui_text_width(url_buf);
        c_cursor();
        gui_draw_line(box_x + 6 + ucw, box_y + 3, box_x + 6 + ucw, box_y + box_h - 3);
    }

    // Content area
    let ct   = v.top_y + addr_h + 2;
    let cb   = v.bot_y - 26;
    let vis  = (cb - ct) / L_LINE();

    let mut r = 0;
    while r < vis {
        let li = br_scroll + r;
        if li < br_total {
            let line = text_get_line(content, li);
            let ry   = ct + r * L_LINE();
            // Simple markup: lines starting with # are headings
            let len2 = str_len(line);
            if len2 > 0 && str_slice(line, 0, 1) == "#" {
                c_accent();
                gui_draw_text(str_slice(line, 2, len2), L_MARGIN() + 4, ry + (L_LINE() - fh) / 2);
            } elif str::starts_with(line, "http://") || str::starts_with(line, "https://") {
                c_fn_();
                gui_draw_text(line, L_MARGIN() + 4, ry + (L_LINE() - fh) / 2);
            } else {
                c_text();
                gui_draw_text(line, L_MARGIN() + 4, ry + (L_LINE() - fh) / 2);
            }
        }
        r = r + 1;
    }

    draw_scrollbar(ww - 12, ct, cb - ct, br_total, vis, br_scroll);

    // Status strip
    gui_set_color(238, 232, 213, 255);
    gui_fill_rect(0, cb, ww, 26);
    c_border();
    gui_draw_line(0, cb, ww, cb);
    c_dim();
    gui_draw_text(status, L_MARGIN(), cb + (26 - fh) / 2);
}

// ── BrowserState ──────────────────────────────────────────────────────────────
struct BrowserState {
    pub br_url:        str,
    pub br_content:    str,
    pub br_total:      int,
    pub br_scroll:     int,
    pub br_status:     str,
    pub br_addr_focus: int,
    pub br_hist:       str,
    pub br_hist_pos:   int,
}

fn browser_state_init() -> BrowserState {
    return BrowserState {
        br_url: "", br_content: "", br_total: 0, br_scroll: 0,
        br_status: "ready  —  Enter URL and press Enter",
        br_addr_focus: 1, br_hist: "", br_hist_pos: 0,
    };
}
