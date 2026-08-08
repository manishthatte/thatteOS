// userspace/gui_fm.mt — THATTEOS Graphical File Manager
//
// SDL2-based file manager with mouse and keyboard navigation.
//
// Keys:
//   ↑ / ↓       move selection
//   Enter        open directory / run binary
//   Backspace    go to parent directory
//   Delete       delete selected file (with confirm dialog)
//   Home / End   jump to first / last entry
//   F5           refresh listing
//   q / Esc      quit
//
// Mouse:
//   Click        select entry
//   Double-click open directory / run binary
//
// Author: Manish Jagdish Thatte

use std::io;

// ── layout constants ─────────────────────────────────────────────────────────

fn TITLE_H()   -> int { return 36; }   // top title bar height
fn TOOLBAR_H() -> int { return 32; }   // toolbar row height
fn STATUS_H()  -> int { return 28; }   // bottom status bar height
fn ROW_H()     -> int { return 22; }   // file row height
fn MARGIN()    -> int { return 8; }    // left margin

// ── colors ───────────────────────────────────────────────────────────────────

fn col_bg()       -> int { return gui_set_color(28,  28,  35,  255); }
fn col_title()    -> int { return gui_set_color(20,  20,  28,  255); }
fn col_toolbar()  -> int { return gui_set_color(36,  36,  48,  255); }
fn col_status()   -> int { return gui_set_color(20,  20,  28,  255); }
fn col_sel()      -> int { return gui_set_color(60,  100, 180, 255); }
fn col_hover()    -> int { return gui_set_color(45,  45,  60,  255); }
fn col_dir()      -> int { return gui_set_color(120, 180, 255, 255); }
fn col_file()     -> int { return gui_set_color(210, 210, 210, 255); }
fn col_size()     -> int { return gui_set_color(140, 140, 160, 255); }
fn col_white()    -> int { return gui_set_color(240, 240, 240, 255); }
fn col_border()   -> int { return gui_set_color(60,  60,  80,  255); }
fn col_btn()      -> int { return gui_set_color(50,  50,  70,  255); }
fn col_btn_hl()   -> int { return gui_set_color(70,  70,  100, 255); }

// ── path helpers ─────────────────────────────────────────────────────────────

fn gfm_join(base: str, name: str) -> str {
    if str_ends_with(base, "/") {
        return str_concat(base, name);
    }
    return str_concat(str_concat(base, "/"), name);
}

fn gfm_parent(p: str) -> str {
    let len = str_len(p);
    if len <= 1 { return "/"; }
    let mut end = len;
    if str_slice(p, len - 1, len) == "/" { end = len - 1; }
    let mut i = end - 1;
    while i > 0 {
        if str_slice(p, i, i + 1) == "/" { return str_slice(p, 0, i); }
        i = i - 1;
    }
    return "/";
}

fn size_str(n: int) -> str {
    if n < 0       { return "?"; }
    if n < 1024    { return str_concat(str_from_int(n), " B"); }
    if n < 1048576 { return str_concat(str_from_int(n / 1024), " K"); }
    return str_concat(str_from_int(n / 1048576), " M");
}

// ── button helper ─────────────────────────────────────────────────────────────
// Returns 1 if (mx,my) is inside rect (bx,by,bw,bh)

fn in_rect(mx: int, my: int, bx: int, by: int, bw: int, bh: int) -> int {
    if mx < bx { return 0; }
    if my < by { return 0; }
    if mx >= bx + bw { return 0; }
    if my >= by + bh { return 0; }
    return 1;
}

// Draw a labelled button; returns its x+w for chaining
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
    return bx + bw + 4;
}

// ── confirm dialog ────────────────────────────────────────────────────────────

fn confirm_delete(name: str) -> int {
    let ww = gui_window_width();
    let wh = gui_window_height();
    let dw = 480;
    let dh = 140;
    let dx = (ww - dw) / 2;
    let dy = (wh - dh) / 2;

    let mut result = -1;   // -1 = pending
    while result == -1 {
        // dim background
        gui_set_color(0, 0, 0, 160);
        gui_fill_rect(0, 0, ww, wh);

        // dialog box
        gui_set_color(40, 40, 55, 255);
        gui_fill_rect(dx, dy, dw, dh);
        col_border();
        gui_draw_rect(dx, dy, dw, dh);

        // message
        col_white();
        gui_draw_text("Delete this file?", dx + 20, dy + 20);
        col_file();
        gui_draw_text(name, dx + 20, dy + 44);

        // buttons
        let yes_x = dx + dw / 2 - 110;
        let no_x  = dx + dw / 2 + 10;
        let btn_y = dy + dh - 46;
        let mx = gui_mouse_x();
        let my = gui_mouse_y();
        draw_btn("Yes, delete", yes_x, btn_y, 100, 30, mx, my);
        draw_btn("Cancel",      no_x,  btn_y, 80,  30, mx, my);
        gui_present();

        gui_wait_event(200);
        let ev = gui_event_type();
        if ev == 1 {   // SDL_QUIT
            result = 0;
        } elif ev == 2 {   // SDL_KEYDOWN
            let k = gui_event_key();
            if k == gui_key_escape() { result = 0; }
            elif k == gui_key_return() { result = 1; }
        } elif ev == 4 {   // SDL_MOUSEBUTTONDOWN
            let cx = gui_mouse_x();
            let cy = gui_mouse_y();
            if in_rect(cx, cy, yes_x, btn_y, 100, 30) == 1 { result = 1; }
            elif in_rect(cx, cy, no_x,  btn_y, 80,  30) == 1 { result = 0; }
        }
    }
    return result;
}

// ── main render ───────────────────────────────────────────────────────────────

fn draw_frame(cwd: str, count: int, selected: int, offset: int,
              msg: str, mx: int, my: int) {
    let ww = gui_window_width();
    let wh = gui_window_height();
    let fh = gui_font_height();

    // background
    col_bg();
    gui_fill_rect(0, 0, ww, wh);

    // title bar
    col_title();
    gui_fill_rect(0, 0, ww, TITLE_H());
    gui_set_color(80, 120, 200, 255);
    gui_draw_text_lg("THATTEOS fm", MARGIN(), 6);
    col_file();
    gui_draw_text(cwd, MARGIN() + 160, (TITLE_H() - fh) / 2 + 2);

    // toolbar
    let tb_y = TITLE_H();
    col_toolbar();
    gui_fill_rect(0, tb_y, ww, TOOLBAR_H());

    let btn_y = tb_y + 4;
    let btn_h = TOOLBAR_H() - 8;
    let mut bx = MARGIN();
    bx = draw_btn("[Up]",   bx, btn_y, 54, btn_h, mx, my);
    bx = draw_btn("[Home]", bx, btn_y, 64, btn_h, mx, my);
    bx = draw_btn("[Del]",  bx, btn_y, 54, btn_h, mx, my);
    bx = draw_btn("[F5]",   bx, btn_y, 44, btn_h, mx, my);

    // separator
    col_border();
    gui_draw_line(0, TITLE_H() + TOOLBAR_H(), ww, TITLE_H() + TOOLBAR_H());

    // file list area
    let list_top = TITLE_H() + TOOLBAR_H() + 2;
    let list_bot = wh - STATUS_H();
    let list_h   = list_bot - list_top;
    let visible  = list_h / ROW_H();

    let mut i = 0;
    while i < visible {
        let idx = offset + i;
        if idx >= count { i = i + visible; } else {
        let row_y = list_top + i * ROW_H();
        let is_sel = if selected == idx { 1 } else { 0 };
        let is_hot = if in_rect(mx, my, 0, row_y, ww, ROW_H()) == 1 && is_sel == 0 { 1 } else { 0 };

        if is_sel == 1 {
            col_sel();
            gui_fill_rect(0, row_y, ww, ROW_H());
        } elif is_hot == 1 {
            col_hover();
            gui_fill_rect(0, row_y, ww, ROW_H());
        }

        let name = fs_list_dir_entry(idx);
        let full = gfm_join(cwd, name);
        let is_d = fs_is_dir(full);
        let ty   = fh / 5;

        if is_d == 1 {
            col_dir();
            gui_draw_text(str_concat("[d] ", name), MARGIN() + 24, row_y + ty);
            col_size();
            gui_draw_text("<dir>", ww - 80, row_y + ty);
        } else {
            col_file();
            gui_draw_text(str_concat("    ", name), MARGIN() + 24, row_y + ty);
            let sz = fs_file_size(gfm_join(cwd, name));
            col_size();
            gui_draw_text(size_str(sz), ww - 80, row_y + ty);
        }

        // row divider (subtle)
        gui_set_color(40, 40, 52, 255);
        gui_draw_line(0, row_y + ROW_H() - 1, ww, row_y + ROW_H() - 1);
        }
        i = i + 1;
    }

    // status bar
    col_status();
    gui_fill_rect(0, list_bot, ww, STATUS_H());
    col_border();
    gui_draw_line(0, list_bot, ww, list_bot);

    let stat = if count > 0 {
        str_concat(str_from_int(selected + 1),
            str_concat("/", str_concat(str_from_int(count), " entries")))
    } else {
        "empty directory"
    };
    let stat2 = if str_len(msg) > 0 {
        str_concat(stat, str_concat("   ", msg))
    } else { stat };
    col_file();
    gui_draw_text(stat2, MARGIN(), list_bot + (STATUS_H() - fh) / 2);

    // help hint
    col_size();
    let hint = "Enter:open  Bksp:up  Del:delete  q:quit";
    let hw = gui_text_width(hint);
    gui_draw_text(hint, ww - hw - MARGIN(), list_bot + (STATUS_H() - fh) / 2);
}

// ── main ─────────────────────────────────────────────────────────────────────

fn main() {
    gui_init(900, 600, "THATTEOS File Manager");

    let mut cwd      = ".";
    let mut selected = 0;
    let mut offset   = 0;
    let mut msg      = "";
    let mut running  = 1;
    let mut last_click_time = 0;
    let mut last_click_idx  = -1;

    while running == 1 {
        let ww = gui_window_width();
        let wh = gui_window_height();
        let list_top = TITLE_H() + TOOLBAR_H() + 2;
        let list_bot = wh - STATUS_H();
        let list_h   = list_bot - list_top;
        let visible  = list_h / ROW_H();

        let count = fs_list_dir_open(cwd);
        if count < 0 {
            msg = str_concat("cannot open: ", cwd);
            cwd = ".";
        }

        if count > 0 && selected >= count { selected = count - 1; }
        if selected < 0 { selected = 0; }
        if selected < offset { offset = selected; }
        if selected >= offset + visible { offset = selected - visible + 1; }

        let mx = gui_mouse_x();
        let my = gui_mouse_y();
        draw_frame(cwd, count, selected, offset, msg, mx, my);
        gui_present();

        gui_wait_event(50);
        let ev = gui_event_type();

        if ev == 1 {   // SDL_QUIT
            running = 0;

        } elif ev == 2 {   // SDL_KEYDOWN
            let k = gui_event_key();
            msg = "";

            if k == gui_key_escape() || k == 113 {
                running = 0;

            } elif k == gui_key_up() {
                if selected > 0 { selected = selected - 1; }

            } elif k == gui_key_down() {
                if count > 0 && selected < count - 1 { selected = selected + 1; }

            } elif k == gui_key_home() {
                selected = 0;
                offset   = 0;

            } elif k == gui_key_end() {
                if count > 0 { selected = count - 1; }

            } elif k == gui_key_pageup() {
                selected = selected - visible;
                if selected < 0 { selected = 0; }

            } elif k == gui_key_pagedown() {
                selected = selected + visible;
                if count > 0 && selected >= count { selected = count - 1; }

            } elif k == gui_key_return() {
                if count > 0 {
                    let name = fs_list_dir_entry(selected);
                    if fs_is_dir(gfm_join(cwd, name)) == 1 {
                        cwd      = gfm_join(cwd, name);
                        selected = 0;
                        offset   = 0;
                    } else {
                        process_spawn(gfm_join(cwd, name));
                    }
                }

            } elif k == gui_key_backspace() {
                cwd      = gfm_parent(cwd);
                selected = 0;
                offset   = 0;

            } elif k == gui_key_delete() {
                if count > 0 {
                    let name = fs_list_dir_entry(selected);
                    let ok = confirm_delete(gfm_join(cwd, name));
                    if ok == 1 {
                        fs_remove_file(gfm_join(cwd, name));
                        msg = str_concat("deleted: ", name);
                        if selected > 0 { selected = selected - 1; }
                    }
                }

            } elif k == gui_key_f5() {
                msg = "refreshed";
            }

        } elif ev == 4 {   // SDL_MOUSEBUTTONDOWN
            let cx = gui_mouse_x();
            let cy = gui_mouse_y();
            let tb_y = TITLE_H();
            let btn_y = tb_y + 4;
            let btn_h = TOOLBAR_H() - 8;
            msg = "";

            // toolbar buttons
            if in_rect(cx, cy, MARGIN(), btn_y, 54, btn_h) == 1 {
                // Up button
                cwd      = gfm_parent(cwd);
                selected = 0;
                offset   = 0;

            } elif in_rect(cx, cy, MARGIN() + 58, btn_y, 64, btn_h) == 1 {
                // Home button
                cwd      = ".";
                selected = 0;
                offset   = 0;

            } elif in_rect(cx, cy, MARGIN() + 126, btn_y, 54, btn_h) == 1 {
                // Del button
                if count > 0 {
                    let name = fs_list_dir_entry(selected);
                    let ok = confirm_delete(gfm_join(cwd, name));
                    if ok == 1 {
                        fs_remove_file(gfm_join(cwd, name));
                        msg = str_concat("deleted: ", name);
                        if selected > 0 { selected = selected - 1; }
                    }
                }

            } elif in_rect(cx, cy, MARGIN() + 184, btn_y, 44, btn_h) == 1 {
                // F5 refresh
                msg = "refreshed";

            } elif cy >= list_top && cy < list_bot {
                // file list click
                let row = (cy - list_top) / ROW_H();
                let idx = offset + row;
                if idx < count {
                    let now = gui_ticks();
                    if idx == last_click_idx && now - last_click_time < 400 {
                        // double-click
                        let name = fs_list_dir_entry(idx);
                        if fs_is_dir(gfm_join(cwd, name)) == 1 {
                            cwd      = gfm_join(cwd, name);
                            selected = 0;
                            offset   = 0;
                        } else {
                            process_spawn(gfm_join(cwd, name));
                        }
                        last_click_idx  = -1;
                        last_click_time = 0;
                    } else {
                        selected        = idx;
                        last_click_idx  = idx;
                        last_click_time = now;
                    }
                }
            }
        }
    }

    gui_quit();
}
