// browser/browser.mt — studioMani standalone browser
// Full-screen HTTP text browser. Shares color theme with studioMani IDE.
// Can be launched standalone or via process_spawn from studioMani.
//
// Keys: Enter/[Go]=fetch  ↑↓PgUp PgDn=scroll  Bksp=back  F5=refresh  q/Esc=quit
// Author: Manish Jagdish Thatte

use std::io;

// ── Colors — Solarized Light ──────────────────────────────────────────────────

fn c_bg()     -> int { return gui_set_color(253, 246, 227, 255); }   // base3
fn c_addr()   -> int { return gui_set_color(238, 232, 213, 255); }   // base2
fn c_addr_hl()-> int { return gui_set_color(196, 223, 245, 255); }   // blue tint
fn c_status() -> int { return gui_set_color(38,  139, 210, 255); }   // blue
fn c_border() -> int { return gui_set_color(147, 161, 161, 255); }   // base1
fn c_btn()    -> int { return gui_set_color(225, 220, 203, 255); }   // base2 darker
fn c_btn_hl() -> int { return gui_set_color(196, 223, 245, 255); }   // blue tint
fn c_text()   -> int { return gui_set_color(101, 123, 131, 255); }   // base00
fn c_white()  -> int { return gui_set_color(7,   54,  66,  255); }   // base02
fn c_dim()    -> int { return gui_set_color(147, 161, 161, 255); }   // base1
fn c_accent() -> int { return gui_set_color(38,  139, 210, 255); }   // blue
fn c_cursor() -> int { return gui_set_color(7,   54,  66,  255); }   // base02

fn ADDR_H()   -> int { return 40; }
fn STATUS_H() -> int { return 22; }
fn LINE_H()   -> int { return 20; }
fn MARGIN()   -> int { return 10; }

// ── Helpers ───────────────────────────────────────────────────────────────────

fn in_rect(mx: int, my: int, bx: int, by: int, bw: int, bh: int) -> int {
    if mx < bx || my < by || mx >= bx + bw || my >= by + bh { return 0; }
    return 1;
}

fn draw_btn(label: str, bx: int, by: int, bw: int, bh: int, mx: int, my: int) -> int {
    let hot = in_rect(mx, my, bx, by, bw, bh);
    if hot == 1 { c_btn_hl(); } else { c_btn(); }
    gui_fill_rect(bx, by, bw, bh);
    c_border();
    gui_draw_rect(bx, by, bw, bh);
    c_white();
    let tw = gui_text_width(label);
    let fh = gui_font_height();
    gui_draw_text(label, bx + (bw - tw) / 2, by + (bh - fh) / 2);
    return bx + bw + 4;
}

// ── HTML stripping ────────────────────────────────────────────────────────────

fn strip_html(raw: str) -> str {
    let len = str_len(raw);
    let mut out = ""; let mut in_tag = 0; let mut i = 0;
    while i < len {
        let ch = str_slice(raw, i, i + 1);
        if in_tag == 1 {
            if ch == ">" { in_tag = 0; }
            i = i + 1;
        } elif ch == "<" {
            in_tag = 1;
            let p = str::to_lower(str_slice(raw, i, i + 5));
            if str::starts_with(p, "<br") || str::starts_with(p, "<p") ||
               str::starts_with(p, "<li") || str::starts_with(p, "<h") {
                out = str_concat(out, "\n");
            }
            i = i + 1;
        } elif ch == "&" {
            let e = str_slice(raw, i, i + 6);
            if str::starts_with(e, "&amp;")  { out = str_concat(out, "&"); i = i + 5; }
            elif str::starts_with(e, "&lt;") { out = str_concat(out, "<"); i = i + 4; }
            elif str::starts_with(e, "&gt;") { out = str_concat(out, ">"); i = i + 4; }
            elif str::starts_with(e, "&nbsp;"){ out = str_concat(out, " "); i = i + 6; }
            else { out = str_concat(out, ch); i = i + 1; }
        } elif ch == "\r" { i = i + 1; }
        else { out = str_concat(out, ch); i = i + 1; }
    }
    return out;
}

fn collapse_blanks(s: str) -> str {
    let len = str_len(s);
    let mut out = ""; let mut nl = 0; let mut i = 0;
    while i < len {
        let ch = str_slice(s, i, i + 1);
        if ch == "\n" { nl = nl + 1; if nl <= 2 { out = str_concat(out, "\n"); } }
        else { nl = 0; out = str_concat(out, ch); }
        i = i + 1;
    }
    return out;
}

fn count_lines(text: str) -> int {
    let len = str_len(text); let mut n = 1; let mut i = 0;
    while i < len { if str_slice(text, i, i + 1) == "\n" { n = n + 1; } i = i + 1; }
    return n;
}

fn get_line(text: str, n: int) -> str {
    let len = str_len(text);
    let mut cur = 0; let mut i = 0; let mut out = "";
    while i < len {
        let ch = str_slice(text, i, i + 1);
        if ch == "\n" { if cur == n { return out; } cur = cur + 1; out = ""; }
        else { if cur == n { out = str_concat(out, ch); } }
        i = i + 1;
    }
    if cur == n { return out; }
    return "";
}

fn ensure_scheme(url: str) -> str {
    if str::starts_with(url, "http://")  { return url; }
    if str::starts_with(url, "https://") { return url; }
    return str_concat("https://", url);
}

// ── History ───────────────────────────────────────────────────────────────────

fn hist_push(h: str, url: str) -> str { return str_concat(h, str_concat(url, "\n")); }

fn hist_pop(h: str) -> str {
    let len = str_len(h); if len == 0 { return ""; }
    let mut end = len; if str_slice(h, len - 1, len) == "\n" { end = len - 1; }
    let mut i = end - 1;
    while i > 0 { if str_slice(h, i, i + 1) == "\n" { return str_slice(h, 0, i + 1); } i = i - 1; }
    return "";
}

fn hist_last(h: str) -> str {
    let len = str_len(h); if len == 0 { return ""; }
    let mut end = len; if str_slice(h, len - 1, len) == "\n" { end = len - 1; }
    let mut i = end - 1;
    while i > 0 { if str_slice(h, i, i + 1) == "\n" { return str_slice(h, i + 1, end); } i = i - 1; }
    return str_slice(h, 0, end);
}

// ── Draw ──────────────────────────────────────────────────────────────────────

fn draw(url_buf: str, content: str, total: int, scroll: int,
        status: str, focused: int, mx: int, my: int) {
    let ww = gui_window_width();
    let wh = gui_window_height();
    let fh = gui_font_height();

    c_bg();
    gui_fill_rect(0, 0, ww, wh);

    // Address bar
    c_addr();
    gui_fill_rect(0, 0, ww, ADDR_H());
    c_border();
    gui_draw_line(0, ADDR_H(), ww, ADDR_H());

    let btn_y  = 4;
    let btn_h  = ADDR_H() - 8;
    let bx     = draw_btn("[<]",  MARGIN(),    btn_y, 36, btn_h, mx, my);
    let bx2    = draw_btn("[>]",  bx,          btn_y, 36, btn_h, mx, my);
    let bx3    = draw_btn("[R]",  bx2,         btn_y, 32, btn_h, mx, my);
    let go_x   = ww - MARGIN() - 48;
    draw_btn("[Go]", go_x, btn_y, 48, btn_h, mx, my);

    let box_x = bx3 + 4;
    let box_w = go_x - box_x - 8;
    if focused == 1 { c_addr_hl(); } else { c_addr(); }
    gui_fill_rect(box_x, btn_y, box_w, btn_h);
    if focused == 1 { c_accent(); } else { c_border(); }
    gui_draw_rect(box_x, btn_y, box_w, btn_h);
    c_white();
    let show = if str_len(url_buf) == 0 { "enter URL…" } else { url_buf };
    gui_draw_text(show, box_x + 6, btn_y + (btn_h - fh) / 2);
    if focused == 1 {
        let cw = gui_text_width(url_buf);
        c_cursor();
        gui_draw_line(box_x + 6 + cw, btn_y + 3, box_x + 6 + cw, btn_y + btn_h - 3);
    }

    // Content
    let ct  = ADDR_H() + 2;
    let cb  = wh - STATUS_H();
    let vis = (cb - ct) / LINE_H();
    let mut r = 0;
    while r < vis {
        let li = scroll + r;
        if li < total {
            let line = get_line(content, li);
            c_text();
            gui_draw_text(line, MARGIN(), ct + r * LINE_H() + (LINE_H() - fh) / 2);
        }
        r = r + 1;
    }

    // Scrollbar
    if total > vis {
        let sb_x = ww - 10;
        c_border();
        gui_fill_rect(sb_x, ct, 8, cb - ct);
        let th = (cb - ct) * vis / total;
        let ty = ct + (cb - ct) * scroll / total;
        gui_set_color(100, 100, 100, 255);
        gui_fill_rect(sb_x, ty, 8, th);
    }

    // Status bar
    c_status();
    gui_fill_rect(0, cb, ww, STATUS_H());
    c_white();
    gui_draw_text(status, MARGIN(), cb + (STATUS_H() - fh) / 2);
    if total > 0 {
        let pct = ((scroll + vis) * 100) / total;
        let ps  = str_concat(str::from_int(pct), "%");
        let pw  = gui_text_width(ps);
        gui_draw_text(ps, ww - pw - MARGIN(), cb + (STATUS_H() - fh) / 2);
    }
}

// ── Main ──────────────────────────────────────────────────────────────────────

fn main() {
    gui_init(1200, 800, "studioMani browser");

    let mut url_buf = ""; let mut content = ""; let mut total = 0;
    let mut scroll  = 0;  let mut status  = "ready — enter a URL and press Enter";
    let mut history = ""; let mut focused = 1; let mut running = 1;

    while running == 1 {
        let wh  = gui_window_height();
        let mx  = gui_mouse_x();
        let my  = gui_mouse_y();
        let vis = (wh - ADDR_H() - 2 - STATUS_H()) / LINE_H();

        draw(url_buf, content, total, scroll, status, focused, mx, my);
        gui_present();
        gui_wait_event(16);

        let ev = gui_event_type();

        if ev == 1 { running = 0; }
        elif ev == 2 {
            let k = gui_event_key();
            if k == gui_key_escape() || k == 113 { running = 0; }
            elif k == gui_key_return() && focused == 1 && str_len(url_buf) > 0 {
                url_buf  = ensure_scheme(url_buf);
                status   = str_concat("fetching: ", url_buf);
                draw(url_buf, content, total, scroll, status, focused, mx, my);
                gui_present();
                let raw  = net_http_get(url_buf);
                content  = collapse_blanks(strip_html(raw));
                total    = count_lines(content);
                status   = str_concat("loaded: ", url_buf);
                history  = hist_push(history, url_buf);
                scroll   = 0;
                focused  = 0;
            } elif k == gui_key_backspace() {
                if focused == 1 {
                    let n = str_len(url_buf);
                    if n > 0 { url_buf = str_slice(url_buf, 0, n - 1); }
                } elif str_len(history) > 0 {
                    history = hist_pop(history);
                    url_buf = hist_last(history);
                    if str_len(url_buf) > 0 {
                        let raw = net_http_get(url_buf);
                        content = collapse_blanks(strip_html(raw));
                        total   = count_lines(content);
                        status  = str_concat("loaded: ", url_buf);
                        scroll  = 0;
                    }
                }
            } elif k == gui_key_up()       && focused == 0 { if scroll > 0 { scroll = scroll - 1; } }
            elif k == gui_key_down()       && focused == 0 { if scroll + vis < total { scroll = scroll + 1; } }
            elif k == gui_key_pageup()     { if scroll >= vis { scroll = scroll - vis; } else { scroll = 0; } }
            elif k == gui_key_pagedown()   { scroll = scroll + vis; if scroll + vis >= total { scroll = total - vis; if scroll < 0 { scroll = 0; } } }
            elif k == gui_key_home()       { scroll = 0; }
            elif k == gui_key_end()        { scroll = total - vis; if scroll < 0 { scroll = 0; } }
            elif k == gui_key_f5()         { focused = if focused == 0 { 1 } else { 0 }; }
            elif k == gui_key_tab()        { focused = if focused == 0 { 1 } else { 0 }; }
        }
        elif ev == 6 {
            if focused == 1 { url_buf = str_concat(url_buf, gui_event_text_str()); }
        }
        elif ev == 4 { focused = 1; }
        elif ev == 7 {
            let wy = gui_wheel_dy();
            if wy > 0 { if scroll > 0 { scroll = scroll - 3; } }
            else { scroll = scroll + 3; if scroll + vis >= total { scroll = total - vis; if scroll < 0 { scroll = 0; } } }
        }
    }
    gui_quit();
}
