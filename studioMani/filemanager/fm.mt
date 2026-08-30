// filemanager/fm.mt — studioMani standalone dual-pane file manager
// Total Commander / Midnight Commander style, thatteOS native.
//
// Keys:
//   Tab          switch active pane
//   ↑↓ PgUp/Dn  navigate
//   Enter        open dir / run file
//   Backspace    go to parent
//   F5           copy  (active → inactive pane)
//   F6           move  (active → inactive pane)
//   F7           mkdir
//   F8/Delete    delete (with confirm)
//   F10/q/Esc    quit
//
// Author: Manish Jagdish Thatte

use std::io;

// ── Colors — Solarized Light ──────────────────────────────────────────────────

// The pane geometry plus the mouse. Grouped 30 August 2026 because
// `draw_pane` took ten parameters and the T3 calling convention passes
// arguments in R1-R8 with no stack argument area, so the file manager could
// not be built for its own target at all. See studioMani/layout.mt for the
// measurement: five functions in the repository were over the limit.
struct PaneRect {
    pub px: int, pub py: int, pub pw: int, pub ph: int,
    pub mx: int, pub my: int,
}

fn make_pane_rect(px: int, py: int, pw: int, ph: int, mx: int, my: int) -> PaneRect {
    return PaneRect { px: px, py: py, pw: pw, ph: ph, mx: mx, my: my };
}

fn c_bg()       -> int { return gui_set_color(253, 246, 227, 255); }   // base3
fn c_panel()    -> int { return gui_set_color(238, 232, 213, 255); }   // base2
fn c_active()   -> int { return gui_set_color(225, 238, 250, 255); }   // blue-tinted base3
fn c_sel()      -> int { return gui_set_color(196, 223, 245, 255); }   // blue tint
fn c_hover()    -> int { return gui_set_color(245, 239, 220, 255); }   // base3 tinted
fn c_toolbar()  -> int { return gui_set_color(238, 232, 213, 255); }   // base2
fn c_status()   -> int { return gui_set_color(38,  139, 210, 255); }   // blue
fn c_border()   -> int { return gui_set_color(147, 161, 161, 255); }   // base1
fn c_accent()   -> int { return gui_set_color(38,  139, 210, 255); }   // blue
fn c_white()    -> int { return gui_set_color(7,   54,  66,  255); }   // base02
fn c_text()     -> int { return gui_set_color(101, 123, 131, 255); }   // base00
fn c_dim()      -> int { return gui_set_color(147, 161, 161, 255); }   // base1
fn c_dir()      -> int { return gui_set_color(181, 137,   0, 255); }   // yellow
fn c_size()     -> int { return gui_set_color(147, 161, 161, 255); }   // base1

fn c_ext(name: str) {
    let len = str_len(name);
    let mut i = len - 1;
    while i > 0 { if str_slice(name, i, i + 1) == "." { break; } i = i - 1; }
    let ext = str_slice(name, i + 1, len);
    if ext == "mt"   { gui_set_color(86,  182, 194, 255); return; }
    if ext == "rs"   { gui_set_color(222, 165,  86, 255); return; }
    if ext == "md"   { gui_set_color(100, 149, 237, 255); return; }
    if ext == "sh"   { gui_set_color(130, 200, 130, 255); return; }
    if ext == "py"   { gui_set_color(255, 212,  59, 255); return; }
    if ext == "json" { gui_set_color(181, 206, 168, 255); return; }
    if ext == "toml" { gui_set_color(222, 165,  86, 255); return; }
    gui_set_color(212, 212, 212, 255);
}

fn HEADER_H()  -> int { return 30; }
fn TOOLBAR_H() -> int { return 30; }
fn STATUS_H()  -> int { return 22; }
fn ROW_H()     -> int { return 22; }
fn MARGIN()    -> int { return 8; }

// ── Helpers ───────────────────────────────────────────────────────────────────

fn in_rect(mx: int, my: int, bx: int, by: int, bw: int, bh: int) -> int {
    if mx < bx || my < by || mx >= bx + bw || my >= by + bh { return 0; }
    return 1;
}

fn draw_btn(label: str, bx: int, by: int, bw: int, bh: int, mx: int, my: int) -> int {
    let hot = in_rect(mx, my, bx, by, bw, bh);
    if hot == 1 { gui_set_color(70, 70, 70, 255); } else { gui_set_color(55, 55, 55, 255); }
    gui_fill_rect(bx, by, bw, bh);
    c_border();
    gui_draw_rect(bx, by, bw, bh);
    c_white();
    let tw = gui_text_width(label);
    let fh = gui_font_height();
    gui_draw_text(label, bx + (bw - tw) / 2, by + (bh - fh) / 2);
    return bx + bw + 4;
}

fn size_str(n: int) -> str {
    if n < 0       { return "?"; }
    if n < 1024    { return str_concat(str::from_int(n),        " B"); }
    if n < 1048576 { return str_concat(str::from_int(n / 1024), " K"); }
    return str_concat(str::from_int(n / 1048576), " M");
}


// ── Confirm dialog ────────────────────────────────────────────────────────────

fn confirm(msg: str, detail: str) -> int {
    let ww = gui_window_width();
    let wh = gui_window_height();
    let dw = 500; let dh = 140;
    let dx = (ww - dw) / 2; let dy = (wh - dh) / 2;
    let fh = gui_font_height();
    let mut result = -1;
    while result == -1 {
        gui_set_color(0, 0, 0, 160);
        gui_fill_rect(0, 0, ww, wh);
        gui_set_color(44, 44, 44, 255);
        gui_fill_rect(dx, dy, dw, dh);
        c_accent();
        gui_draw_rect(dx, dy, dw, dh);
        c_white();
        gui_draw_text(msg, dx + 16, dy + 18);
        c_dim();
        gui_draw_text(detail, dx + 16, dy + 42);
        let mx = gui_mouse_x(); let my = gui_mouse_y();
        let yes_x = dx + dw / 2 - 106;
        let no_x  = dx + dw / 2 + 10;
        let btn_y = dy + dh - 42;
        draw_btn("[Yes]",    yes_x, btn_y, 90, 28, mx, my);
        draw_btn("[Cancel]", no_x,  btn_y, 90, 28, mx, my);
        gui_present();
        gui_wait_event(100);
        let ev = gui_event_type();
        if ev == 1 { result = 0; }
        elif ev == 2 {
            let k = gui_event_key();
            if k == gui_key_escape() { result = 0; }
            elif k == gui_key_return() { result = 1; }
        } elif ev == 4 {
            let cx = gui_mouse_x(); let cy = gui_mouse_y();
            if in_rect(cx, cy, yes_x, btn_y, 90, 28) == 1 { result = 1; }
            elif in_rect(cx, cy, no_x,  btn_y, 90, 28) == 1 { result = 0; }
        }
    }
    return result;
}

// ── Draw one pane ─────────────────────────────────────────────────────────────

fn draw_pane(cwd: str, sel: int, scroll: int, active: int, r: PaneRect) {
    let fh = gui_font_height();

    // Pane background
    if active == 1 { c_active(); } else { c_panel(); }
    gui_fill_rect(r.px, r.py, r.pw, r.ph);
    if active == 1 { c_accent(); } else { c_border(); }
    gui_draw_rect(r.px, r.py, r.pw, r.ph);

    // Path header
    c_dim();
    let path_show = if str_len(cwd) > 36 { str_slice(cwd, str_len(cwd) - 36, str_len(cwd)) } else { cwd };
    gui_draw_text(path_show, r.px + MARGIN(), r.py + (24 - fh) / 2);
    c_border();
    gui_draw_line(r.px, r.py + 24, r.px + r.pw, r.py + 24);

    // Column headers
    gui_set_color(44, 44, 44, 255);
    gui_fill_rect(r.px, r.py + 24, r.pw, 20);
    c_dim();
    gui_draw_text("Name", r.px + MARGIN() + 20, r.py + 24 + (20 - fh) / 2);
    gui_draw_text("Size", r.px + r.pw - 72,       r.py + 24 + (20 - fh) / 2);
    c_border();
    gui_draw_line(r.px, r.py + 44, r.px + r.pw, r.py + 44);

    let list_top = r.py + 44;
    let visible  = (r.py + r.ph - list_top) / ROW_H();
    let count    = fs_list_dir_open(cwd);

    let mut i = 0;
    while i < visible {
        let idx  = scroll + i;
        if idx >= count { i = visible; } else {
        let name = fs_list_dir_entry(idx);
        let full = path_join(cwd, name);
        let is_d = fs_is_dir(full);
        let ry   = list_top + i * ROW_H();
        let issel = if sel == idx { 1 } else { 0 };
        let hot  = in_rect(r.mx, r.my, r.px, ry, r.pw, ROW_H());

        if issel == 1 { c_sel();   gui_fill_rect(r.px, ry, r.pw, ROW_H()); }
        elif hot == 1 { c_hover(); gui_fill_rect(r.px, ry, r.pw, ROW_H()); }

        // Icon (text)
        if is_d == 1 {
            c_dir();
            gui_draw_text("▶", r.px + MARGIN(), ry + (ROW_H() - fh) / 2);
            gui_draw_text(name, r.px + MARGIN() + 16, ry + (ROW_H() - fh) / 2);
            c_size();
            gui_draw_text("<dir>", r.px + r.pw - 72, ry + (ROW_H() - fh) / 2);
        } else {
            c_ext(name);
            gui_draw_text(" ", r.px + MARGIN(), ry + (ROW_H() - fh) / 2);
            gui_draw_text(name, r.px + MARGIN() + 16, ry + (ROW_H() - fh) / 2);
            let sz = fs_file_size(full);
            c_size();
            gui_draw_text(size_str(sz), r.px + r.pw - 72, ry + (ROW_H() - fh) / 2);
        }

        c_border();
        gui_draw_line(r.px, ry + ROW_H() - 1, r.px + r.pw, ry + ROW_H() - 1);
        i = i + 1;
        }
    }
}

// ── Main ──────────────────────────────────────────────────────────────────────

fn main() {
    gui_init(1200, 750, "studioMani file manager");

    let mut cwd_l   = "."; let mut cwd_r  = ".";
    let mut sel_l   = 0;   let mut sel_r  = 0;
    let mut scr_l   = 0;   let mut scr_r  = 0;
    let mut pane    = 0;   // 0=left  1=right
    let mut msg     = "";
    let mut last_t  = 0;   let mut last_i = -1;
    let mut running = 1;

    while running == 1 {
        let ww  = gui_window_width();
        let wh  = gui_window_height();
        let mx  = gui_mouse_x();
        let my  = gui_mouse_y();
        let fh  = gui_font_height();
        let half = ww / 2 - 1;

        // Content area
        let top_y  = HEADER_H() + 2;
        let bot_y  = wh - STATUS_H() - TOOLBAR_H();
        let pane_h = bot_y - top_y;

        // ── Draw ──────────────────────────────────────────────────────────────
        c_bg();
        gui_fill_rect(0, 0, ww, wh);

        // Header
        c_panel();
        gui_fill_rect(0, 0, ww, HEADER_H());
        c_accent();
        gui_draw_text_lg("studioMani fm", MARGIN(), 4);
        c_border();
        gui_draw_line(0, HEADER_H(), ww, HEADER_H());

        // Panes
        draw_pane(cwd_l, sel_l, scr_l, if pane == 0 { 1 } else { 0 },
                  make_pane_rect(0, top_y, half, pane_h, mx, my));
        draw_pane(cwd_r, sel_r, scr_r, if pane == 1 { 1 } else { 0 },
                  make_pane_rect(half + 2, top_y, ww - half - 2, pane_h, mx, my));

        // Toolbar (F-key bar, NC-style)
        let tb_y = bot_y;
        c_toolbar();
        gui_fill_rect(0, tb_y, ww, TOOLBAR_H());
        c_border();
        gui_draw_line(0, tb_y, ww, tb_y);
        let mut bx = MARGIN();
        bx = draw_btn("[F3 View]",  bx, tb_y + 3, 80, 24, mx, my);
        bx = draw_btn("[F4 Edit]",  bx, tb_y + 3, 76, 24, mx, my);
        bx = draw_btn("[F5 Copy]",  bx, tb_y + 3, 76, 24, mx, my);
        bx = draw_btn("[F6 Move]",  bx, tb_y + 3, 76, 24, mx, my);
        bx = draw_btn("[F7 MkDir]", bx, tb_y + 3, 84, 24, mx, my);
        bx = draw_btn("[F8 Del]",   bx, tb_y + 3, 74, 24, mx, my);
        draw_btn("[F10 Quit]", bx, tb_y + 3, 84, 24, mx, my);

        // Status bar
        let sb_y = wh - STATUS_H();
        c_status();
        gui_fill_rect(0, sb_y, ww, STATUS_H());
        c_white();
        let active_cwd = if pane == 0 { cwd_l } else { cwd_r };
        let stat = str_concat(active_cwd, if str_len(msg) > 0 { str_concat("   ", msg) } else { "" });
        gui_draw_text(stat, MARGIN(), sb_y + (STATUS_H() - fh) / 2);
        c_dim();
        gui_draw_text("Tab:switch  Enter:open  Bksp:up  F5:copy  F8:delete", ww - 400, sb_y + (STATUS_H() - fh) / 2);

        gui_present();

        // ── Events ────────────────────────────────────────────────────────────
        gui_wait_event(16);
        let ev = gui_event_type();

        if ev == 1 { running = 0; }
        elif ev == 2 {
            let k = gui_event_key();
            msg = "";

            if k == gui_key_escape() || k == 113 || k == gui_key_f10() {
                running = 0;

            } elif k == gui_key_tab() {
                pane = if pane == 0 { 1 } else { 0 };

            } elif k == gui_key_up() {
                if pane == 0 { if sel_l > 0 { sel_l = sel_l - 1; } }
                else { if sel_r > 0 { sel_r = sel_r - 1; } }

            } elif k == gui_key_down() {
                if pane == 0 {
                    let cnt = fs_list_dir_open(cwd_l);
                    if cnt > 0 && sel_l < cnt - 1 { sel_l = sel_l + 1; }
                } else {
                    let cnt = fs_list_dir_open(cwd_r);
                    if cnt > 0 && sel_r < cnt - 1 { sel_r = sel_r + 1; }
                }

            } elif k == gui_key_home() {
                if pane == 0 { sel_l = 0; scr_l = 0; }
                else { sel_r = 0; scr_r = 0; }

            } elif k == gui_key_end() {
                if pane == 0 { let cnt = fs_list_dir_open(cwd_l); if cnt > 0 { sel_l = cnt - 1; } }
                else { let cnt = fs_list_dir_open(cwd_r); if cnt > 0 { sel_r = cnt - 1; } }

            } elif k == gui_key_return() {
                if pane == 0 {
                    let cnt = fs_list_dir_open(cwd_l);
                    if cnt > 0 {
                        let name_l = fs_list_dir_entry(sel_l);
                        if fs_is_dir(path_join(cwd_l, name_l)) == 1 { cwd_l = path_join(cwd_l, name_l); sel_l = 0; scr_l = 0; }
                        else { process_spawn(path_join(cwd_l, name_l)); }
                    }
                } else {
                    let cnt = fs_list_dir_open(cwd_r);
                    if cnt > 0 {
                        let name_r = fs_list_dir_entry(sel_r);
                        if fs_is_dir(path_join(cwd_r, name_r)) == 1 { cwd_r = path_join(cwd_r, name_r); sel_r = 0; scr_r = 0; }
                        else { process_spawn(path_join(cwd_r, name_r)); }
                    }
                }

            } elif k == gui_key_backspace() {
                if pane == 0 { cwd_l = path_parent(cwd_l); sel_l = 0; scr_l = 0; }
                else { cwd_r = path_parent(cwd_r); sel_r = 0; scr_r = 0; }

            } elif k == gui_key_delete() || k == gui_key_f8() {
                if pane == 0 {
                    let cnt = fs_list_dir_open(cwd_l);
                    if cnt > 0 {
                        let name = fs_list_dir_entry(sel_l);
                        let full = path_join(cwd_l, name);
                        let ok   = confirm("Delete?", full);
                        if ok == 1 { fs_remove_file(full); msg = str_concat("deleted: ", name); if sel_l > 0 { sel_l = sel_l - 1; } }
                    }
                } else {
                    let cnt = fs_list_dir_open(cwd_r);
                    if cnt > 0 {
                        let name = fs_list_dir_entry(sel_r);
                        let full = path_join(cwd_r, name);
                        let ok   = confirm("Delete?", full);
                        if ok == 1 { fs_remove_file(full); msg = str_concat("deleted: ", name); if sel_r > 0 { sel_r = sel_r - 1; } }
                    }
                }

            } elif k == gui_key_f5() {
                // Copy: TODO — requires fs_copy_file stdlib addition
                msg = "F5 copy: pending fs_copy_file stdlib support";

            } elif k == gui_key_f6() {
                // Move: TODO — requires fs_rename stdlib addition
                msg = "F6 move: pending fs_rename stdlib support";
            }

            // Keep selection visible
            let visible = pane_h / ROW_H();
            if pane == 0 {
                if sel_l < scr_l { scr_l = sel_l; }
                if sel_l >= scr_l + visible { scr_l = sel_l - visible + 1; }
            } else {
                if sel_r < scr_r { scr_r = sel_r; }
                if sel_r >= scr_r + visible { scr_r = sel_r - visible + 1; }
            }

        } elif ev == 4 {
            let cx = gui_mouse_x();
            let cy = gui_mouse_y();
            let top_y2 = HEADER_H() + 2;
            let bot_y2 = wh - STATUS_H() - TOOLBAR_H();

            if cy >= top_y2 && cy < bot_y2 {
                let row_h = ROW_H();
                let hdr_h = 44;   // path + column header
                let list_top = top_y2 + hdr_h;
                let row      = (cy - list_top) / row_h;

                if cx < half {
                    pane = 0;
                    let idx  = scr_l + row;
                    let now  = gui_ticks();
                    if idx == last_i && now - last_t < 400 {
                        let nm_l = fs_list_dir_entry(idx);
                        if fs_is_dir(path_join(cwd_l, nm_l)) == 1 { cwd_l = path_join(cwd_l, nm_l); sel_l = 0; scr_l = 0; }
                        else { process_spawn(path_join(cwd_l, nm_l)); }
                        last_i = -1;
                    } else {
                        sel_l = idx; last_i = idx; last_t = now;
                    }
                } else {
                    pane = 1;
                    let idx  = scr_r + row;
                    let now  = gui_ticks();
                    if idx == last_i && now - last_t < 400 {
                        let nm_r = fs_list_dir_entry(idx);
                        if fs_is_dir(path_join(cwd_r, nm_r)) == 1 { cwd_r = path_join(cwd_r, nm_r); sel_r = 0; scr_r = 0; }
                        else { process_spawn(path_join(cwd_r, nm_r)); }
                        last_i = -1;
                    } else {
                        sel_r = idx; last_i = idx; last_t = now;
                    }
                }
            }

        } elif ev == 7 {
            let wy = gui_wheel_dy();
            if pane == 0 { if wy > 0 { if scr_l > 0 { scr_l = scr_l - 3; } } else { scr_l = scr_l + 3; } }
            else { if wy > 0 { if scr_r > 0 { scr_r = scr_r - 3; } } else { scr_r = scr_r + 3; } }
        }
    }

    gui_quit();
}
