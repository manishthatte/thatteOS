// userspace/gui_browser.mt — THATTEOS Graphical Text Browser
//
// SDL2-based web browser: fetches HTTP/HTTPS pages via libcurl,
// strips HTML tags, and renders as scrollable text.
//
// Keys:
//   F5 / Enter (in URL bar)  fetch URL
//   ↑ / ↓ / PgUp / PgDn     scroll content
//   Home / End               jump to top / bottom
//   Backspace                go to previous page
//   Esc / q                  quit
//
// Mouse:
//   Click URL bar            start editing
//   Click [Go]               fetch
//   Click [Back]             history back
//   Scroll wheel             scroll content
//
// Author: Manish Jagdish Thatte

use std::io;

// ── layout ────────────────────────────────────────────────────────────────────

fn TITLE_H()   -> int { return 36; }
fn ADDR_H()    -> int { return 38; }
fn STATUS_H()  -> int { return 26; }
fn LINE_H()    -> int { return 18; }
fn MARGIN()    -> int { return 12; }

// ── colors ────────────────────────────────────────────────────────────────────

fn col_bg()        -> int { return gui_set_color(24,  24,  32,  255); }
fn col_title_bg()  -> int { return gui_set_color(18,  18,  26,  255); }
fn col_addr_bg()   -> int { return gui_set_color(34,  34,  46,  255); }
fn col_addr_hl()   -> int { return gui_set_color(44,  54,  80,  255); }
fn col_status_bg() -> int { return gui_set_color(18,  18,  26,  255); }
fn col_border()    -> int { return gui_set_color(60,  60,  85,  255); }
fn col_btn()       -> int { return gui_set_color(50,  50,  72,  255); }
fn col_btn_hl()    -> int { return gui_set_color(70,  80, 120,  255); }
fn col_text()      -> int { return gui_set_color(210, 210, 210, 255); }
fn col_white()     -> int { return gui_set_color(245, 245, 245, 255); }
fn col_dim()       -> int { return gui_set_color(130, 130, 150, 255); }
fn col_accent()    -> int { return gui_set_color(90,  140, 220, 255); }
fn col_cursor()    -> int { return gui_set_color(180, 200, 255, 255); }

// ── HTML stripping (same logic as TUI browser) ───────────────────────────────

fn strip_html(raw: str) -> str {
    let len     = str_len(raw);
    let mut out = "";
    let mut i   = 0;
    let mut in_tag = 0;

    while i < len {
        let ch = str_slice(raw, i, i + 1);

        if in_tag == 1 {
            if ch == ">" { in_tag = 0; }
            i = i + 1;

        } elif ch == "<" {
            in_tag = 1;
            let peek8 = str_to_lower(str_slice(raw, i, i + 8));
            if str_starts_with(peek8, "<br")  ||
               str_starts_with(peek8, "<p")   ||
               str_starts_with(peek8, "<tr")  ||
               str_starts_with(peek8, "<li")  ||
               str_starts_with(peek8, "<h1")  ||
               str_starts_with(peek8, "<h2")  ||
               str_starts_with(peek8, "<h3")  ||
               str_starts_with(peek8, "<h4")  ||
               str_starts_with(peek8, "<h5")  ||
               str_starts_with(peek8, "<h6")  ||
               str_starts_with(peek8, "</div") ||
               str_starts_with(peek8, "</p>") {
                out = str_concat(out, "\n");
            }
            i = i + 1;

        } elif ch == "&" {
            let ent6 = str_slice(raw, i, i + 6);
            if str_starts_with(ent6, "&amp;")  { out = str_concat(out, "&");  i = i + 5; }
            elif str_starts_with(ent6, "&lt;")  { out = str_concat(out, "<");  i = i + 4; }
            elif str_starts_with(ent6, "&gt;")  { out = str_concat(out, ">");  i = i + 4; }
            elif str_starts_with(ent6, "&nbsp;") { out = str_concat(out, " ");  i = i + 6; }
            elif str_starts_with(ent6, "&quot;") { out = str_concat(out, "\""); i = i + 6; }
            elif str_starts_with(ent6, "&#39;")  { out = str_concat(out, "'");  i = i + 5; }
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

// ── line splitting ────────────────────────────────────────────────────────────
// Split text at newlines; wrap long lines to fit window width.
// Returns total line count — lines stored in a flat string separated by \n.
// (ManiT has no arrays, so we pass through fs cache via repeated index.)

fn count_text_lines(text: str) -> int {
    let len = str_len(text);
    let mut n = 1;
    let mut i = 0;
    while i < len {
        if str_slice(text, i, i + 1) == "\n" { n = n + 1; }
        i = i + 1;
    }
    return n;
}

// Return the n-th line (0-indexed) from newline-separated text.
fn get_line(text: str, n: int) -> str {
    let len = str_len(text);
    let mut cur_line = 0;
    let mut i = 0;
    let mut out = "";
    while i < len {
        let ch = str_slice(text, i, i + 1);
        if ch == "\n" {
            if cur_line == n { return out; }
            cur_line = cur_line + 1;
            out = "";
        } else {
            if cur_line == n { out = str_concat(out, ch); }
        }
        i = i + 1;
    }
    return out;
}

// ── history ───────────────────────────────────────────────────────────────────

fn hist_add(hist: str, url: str) -> str {
    return str_concat(hist, str_concat(url, "\n"));
}

fn hist_last(hist: str) -> str {
    let len = str_len(hist);
    if len == 0 { return ""; }
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

fn hist_pop(hist: str) -> str {
    let len = str_len(hist);
    if len == 0 { return ""; }
    let mut end = len - 1;
    let mut i   = end - 1;
    while i >= 0 {
        if str_slice(hist, i, i + 1) == "\n" { return str_slice(hist, 0, i + 1); }
        i = i - 1;
    }
    return "";
}

// ── in_rect helper ────────────────────────────────────────────────────────────

fn in_rect(mx: int, my: int, bx: int, by: int, bw: int, bh: int) -> int {
    if mx < bx { return 0; }
    if my < by { return 0; }
    if mx >= bx + bw { return 0; }
    if my >= by + bh { return 0; }
    return 1;
}

fn draw_btn(label: str, bx: int, by: int, bw: int, bh: int, mx: int, my: int) -> int {
    let hot = in_rect(mx, my, bx, by, bw, bh);
    if hot == 1 { col_btn_hl(); } else { col_btn(); }
    gui_fill_rect(bx, by, bw, bh);
    col_border();
    gui_draw_rect(bx, by, bw, bh);
    col_white();
    let tw = gui_text_width(label);
    let tx = bx + (bw - tw) / 2;
    let fh = gui_font_height();
    let ty = by + (bh - fh) / 2;
    gui_draw_text(label, tx, ty);
    return bx + bw + 6;
}

// ── main render ───────────────────────────────────────────────────────────────

fn draw_frame(url_buf: str, content: str, total_lines: int, scroll: int,
              status: str, addr_focused: int, mx: int, my: int) {
    let ww = gui_window_width();
    let wh = gui_window_height();
    let fh = gui_font_height();

    // background
    col_bg();
    gui_fill_rect(0, 0, ww, wh);

    // title bar
    col_title_bg();
    gui_fill_rect(0, 0, ww, TITLE_H());
    gui_set_color(80, 130, 210, 255);
    gui_draw_text_lg("THATTEOS browser", MARGIN(), 6);

    // address bar row
    let addr_y = TITLE_H();
    col_addr_bg();
    gui_fill_rect(0, addr_y, ww, ADDR_H());
    col_border();
    gui_draw_line(0, addr_y + ADDR_H(), ww, addr_y + ADDR_H());

    // [Back] and [Go] buttons
    let btn_y  = addr_y + 4;
    let btn_h  = ADDR_H() - 8;
    let mx_now = gui_mouse_x();
    let my_now = gui_mouse_y();
    let after_back = draw_btn("[Back]", MARGIN(), btn_y, 58, btn_h, mx_now, my_now);
    let go_x = ww - MARGIN() - 54;
    draw_btn("[Go]", go_x, btn_y, 54, btn_h, mx_now, my_now);

    // URL input box
    let box_x = after_back + 4;
    let box_w = go_x - box_x - 8;
    let box_y = addr_y + 5;
    let box_h = ADDR_H() - 10;
    if addr_focused == 1 { col_addr_hl(); } else { col_addr_bg(); }
    gui_fill_rect(box_x, box_y, box_w, box_h);
    col_border();
    gui_draw_rect(box_x, box_y, box_w, box_h);
    col_white();
    let url_show = if str_len(url_buf) == 0 { "enter URL..." } else { url_buf };
    gui_draw_text(url_show, box_x + 6, box_y + (box_h - fh) / 2);

    // cursor in address bar
    if addr_focused == 1 {
        let cw = gui_text_width(url_buf);
        let cx = box_x + 6 + cw;
        let cy = box_y + 3;
        col_cursor();
        gui_draw_line(cx, cy, cx, cy + box_h - 6);
    }

    // content area
    let content_top = TITLE_H() + ADDR_H() + 2;
    let content_bot = wh - STATUS_H();
    let content_h   = content_bot - content_top;
    let visible_lines = content_h / LINE_H();

    let text_x = MARGIN();
    let mut row = 0;
    while row < visible_lines {
        let line_idx = scroll + row;
        if line_idx < total_lines {
            let line = get_line(content, line_idx);
            let row_y = content_top + row * LINE_H();
            col_text();
            gui_draw_text(line, text_x, row_y);
        }
        row = row + 1;
    }

    // scrollbar
    if total_lines > 0 && total_lines > visible_lines {
        let sb_x = ww - 10;
        let sb_h = content_h;
        col_border();
        gui_fill_rect(sb_x, content_top, 8, sb_h);

        let thumb_h = sb_h * visible_lines / total_lines;
        let thumb_y = content_top + sb_h * scroll / total_lines;
        col_btn();
        gui_fill_rect(sb_x, thumb_y, 8, thumb_h);
    }

    // status bar
    col_status_bg();
    gui_fill_rect(0, content_bot, ww, STATUS_H());
    col_border();
    gui_draw_line(0, content_bot, ww, content_bot);
    col_dim();
    gui_draw_text(status, MARGIN(), content_bot + (STATUS_H() - fh) / 2);

    // scroll position hint
    if total_lines > 0 {
        let pct = ((scroll + visible_lines) * 100) / total_lines;
        let pct_s = str_concat(str_from_int(pct), "%");
        let pw = gui_text_width(pct_s);
        col_dim();
        gui_draw_text(pct_s, ww - pw - MARGIN(), content_bot + (STATUS_H() - fh) / 2);
    }
}

// ── fetch + process a URL ─────────────────────────────────────────────────────

fn ensure_scheme(url: str) -> str {
    if str_starts_with(url, "http://")  { return url; }
    if str_starts_with(url, "https://") { return url; }
    return str_concat("https://", url);
}

// ── main ─────────────────────────────────────────────────────────────────────

fn main() {
    gui_init(1000, 680, "THATTEOS Browser");

    let mut url_buf      = "";
    let mut content      = "";
    let mut total_lines  = 0;
    let mut scroll       = 0;
    let mut status       = "ready — enter a URL and press Enter or [Go]";
    let mut history      = "";
    let mut addr_focused = 1;
    let mut running      = 1;

    while running == 1 {
        let ww = gui_window_width();
        let wh = gui_window_height();
        let content_top  = TITLE_H() + ADDR_H() + 2;
        let content_bot  = wh - STATUS_H();
        let content_h    = content_bot - content_top;
        let visible_lines = content_h / LINE_H();

        let mx = gui_mouse_x();
        let my = gui_mouse_y();
        draw_frame(url_buf, content, total_lines, scroll,
                   status, addr_focused, mx, my);
        gui_present();

        gui_wait_event(50);
        let ev = gui_event_type();

        if ev == 1 {   // SDL_QUIT
            running = 0;

        } elif ev == 2 {   // SDL_KEYDOWN
            let k = gui_event_key();

            if k == gui_key_escape() {
                if addr_focused == 1 {
                    addr_focused = 0;
                } else {
                    running = 0;
                }

            } elif k == gui_key_return() {
                if addr_focused == 1 && str_len(url_buf) > 0 {
                    // fetch — normalise URL in-place, then use url_buf throughout
                    url_buf = ensure_scheme(url_buf);
                    status  = str_concat("fetching: ", url_buf);
                    draw_frame(url_buf, content, total_lines, scroll,
                               status, addr_focused, mx, my);
                    gui_present();

                    let raw = net_http_get(url_buf);
                    if str_starts_with(raw, "(curl error:") {
                        status  = str_concat("error: ", raw);
                        content = str_concat("error: ", raw);
                        total_lines = 1;
                    } elif str_len(raw) == 0 {
                        status  = "empty response";
                        content = "empty response";
                        total_lines = 1;
                    } else {
                        content     = collapse_blanks(strip_html(raw));
                        total_lines = count_text_lines(content);
                        status      = str_concat("loaded: ", url_buf);
                        history     = hist_add(history, url_buf);
                        scroll      = 0;
                    }
                    addr_focused = 0;
                }

            } elif k == gui_key_backspace() {
                if addr_focused == 1 {
                    let L = str_len(url_buf);
                    if L > 0 { url_buf = str_slice(url_buf, 0, L - 1); }
                } else {
                    // history back
                    if str_len(history) > 0 {
                        history = hist_pop(history);
                        url_buf = hist_last(history);
                        if str_len(url_buf) > 0 {
                            status  = str_concat("fetching: ", url_buf);
                            draw_frame(url_buf, content, total_lines, scroll,
                                       status, addr_focused, mx, my);
                            gui_present();

                            let raw2 = net_http_get(url_buf);
                            if str_len(raw2) > 0 {
                                content     = collapse_blanks(strip_html(raw2));
                                total_lines = count_text_lines(content);
                                status      = str_concat("loaded: ", url_buf);
                                scroll      = 0;
                            } else {
                                status = "empty response";
                            }
                        } else {
                            status = "no previous page";
                        }
                    }
                }

            } elif k == gui_key_up() {
                if addr_focused == 0 {
                    if scroll > 0 { scroll = scroll - 1; }
                }

            } elif k == gui_key_down() {
                if addr_focused == 0 {
                    if scroll + visible_lines < total_lines {
                        scroll = scroll + 1;
                    }
                }

            } elif k == gui_key_pageup() {
                scroll = scroll - visible_lines;
                if scroll < 0 { scroll = 0; }

            } elif k == gui_key_pagedown() {
                scroll = scroll + visible_lines;
                if scroll + visible_lines >= total_lines {
                    scroll = total_lines - visible_lines;
                    if scroll < 0 { scroll = 0; }
                }

            } elif k == gui_key_home() {
                scroll = 0;

            } elif k == gui_key_end() {
                scroll = total_lines - visible_lines;
                if scroll < 0 { scroll = 0; }

            } elif k == gui_key_f5() {
                if str_len(url_buf) > 0 {
                    url_buf = ensure_scheme(url_buf);
                    status  = str_concat("refreshing: ", url_buf);
                    draw_frame(url_buf, content, total_lines, scroll,
                               status, addr_focused, mx, my);
                    gui_present();

                    let raw3 = net_http_get(url_buf);
                    if str_len(raw3) > 0 {
                        content     = collapse_blanks(strip_html(raw3));
                        total_lines = count_text_lines(content);
                        status      = str_concat("refreshed: ", url_buf);
                        scroll      = 0;
                    }
                }

            } elif k == gui_key_tab() {
                // toggle address bar focus
                addr_focused = if addr_focused == 1 { 0 } else { 1 };
            }

        } elif ev == 6 {   // SDL_TEXTINPUT
            if addr_focused == 1 {
                url_buf = str_concat(url_buf, gui_event_text_str());
            }

        } elif ev == 4 {   // SDL_MOUSEBUTTONDOWN
            let cx = gui_mouse_x();
            let cy = gui_mouse_y();
            let addr_y = TITLE_H();
            let btn_y  = addr_y + 4;
            let btn_h  = ADDR_H() - 8;
            let after_back = MARGIN() + 58 + 4;
            let go_x = ww - MARGIN() - 54;
            let box_x = after_back + 4;
            let box_w = go_x - box_x - 8;

            if in_rect(cx, cy, MARGIN(), btn_y, 58, btn_h) == 1 {
                // [Back] button
                if str_len(history) > 0 {
                    history = hist_pop(history);
                    url_buf = hist_last(history);
                    if str_len(url_buf) > 0 {
                        status  = str_concat("fetching: ", url_buf);
                        draw_frame(url_buf, content, total_lines, scroll,
                                   status, addr_focused, mx, my);
                        gui_present();
                        let raw4 = net_http_get(url_buf);
                        if str_len(raw4) > 0 {
                            content     = collapse_blanks(strip_html(raw4));
                            total_lines = count_text_lines(content);
                            status      = str_concat("loaded: ", url_buf);
                            scroll      = 0;
                        }
                    }
                }

            } elif in_rect(cx, cy, go_x, btn_y, 54, btn_h) == 1 {
                // [Go] button — same as Enter
                if str_len(url_buf) > 0 {
                    url_buf = ensure_scheme(url_buf);
                    status  = str_concat("fetching: ", url_buf);
                    draw_frame(url_buf, content, total_lines, scroll,
                               status, addr_focused, mx, my);
                    gui_present();
                    let raw5 = net_http_get(url_buf);
                    if str_starts_with(raw5, "(curl error:") {
                        status  = str_concat("error: ", raw5);
                        content = str_concat("error: ", raw5);
                        total_lines = 1;
                    } elif str_len(raw5) == 0 {
                        status  = "empty response";
                        content = "empty response";
                        total_lines = 1;
                    } else {
                        content     = collapse_blanks(strip_html(raw5));
                        total_lines = count_text_lines(content);
                        status      = str_concat("loaded: ", url_buf);
                        history     = hist_add(history, url_buf);
                        scroll      = 0;
                    }
                    addr_focused = 0;
                }

            } elif in_rect(cx, cy, box_x, btn_y - 1, box_w, btn_h + 2) == 1 {
                // URL box — focus
                addr_focused = 1;

            } else {
                addr_focused = 0;
            }

        } elif ev == 7 {   // SDL_MOUSEWHEEL
            let wy = gui_wheel_dy();
            if wy > 0 {
                scroll = scroll - 3;
                if scroll < 0 { scroll = 0; }
            } elif wy < 0 {
                scroll = scroll + 3;
                let mut max_s = total_lines - visible_lines;
                if max_s < 0 { max_s = 0; }
                if scroll > max_s { scroll = max_s; }
            }
        }
    }

    gui_quit();
}
