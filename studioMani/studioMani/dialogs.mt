// studioMani/studioMani/dialogs.mt — modal dialog widgets
// draw_input_dialog, draw_confirm_dialog, draw_msg_dialog, draw_context_menu
// Depends on: theme.mt, layout.mt (in_rect, int_min, c_* colors)
// Author: Manish Jagdish Thatte

// Semi-transparent dark overlay covering the entire window.
fn draw_modal_overlay() {
    gui_set_color(0, 0, 0, 100);
    gui_fill_rect(0, 0, gui_window_width(), gui_window_height());
}

// Single-line text-input dialog.
// Returns 1 if OK button area hovered, 2 if Cancel, 0 otherwise.
// Caller draws this each frame while dlg_vis==1; clicks are handled in the event loop.
fn draw_input_dialog(title: str, prompt: str, value: str, mx: int, my: int) -> int {
    draw_modal_overlay();
    let ww  = gui_window_width();
    let wh  = gui_window_height();
    let fh  = gui_font_height();
    let pw  = int_min(500, ww - 120);
    let ph  = 156;
    let px  = (ww - pw) / 2;
    let py  = (wh - ph) / 2;

    // Box
    gui_set_color(245, 238, 220, 255);
    gui_fill_rect(px, py, pw, ph);
    c_border();
    gui_draw_rect(px, py, pw, ph);

    // Title strip
    c_accent();
    gui_fill_rect(px, py, pw, 28);
    c_statusbar_txt();
    gui_draw_text(title, px + 10, py + (28 - fh) / 2);

    // Prompt label
    c_white();
    gui_draw_text(prompt, px + 10, py + 38);

    // Input field
    let ix = px + 10;
    let iy = py + 44 + fh;
    let iw = pw - 20;
    let ih = 28;
    gui_set_color(255, 252, 243, 255);
    gui_fill_rect(ix, iy, iw, ih);
    c_accent();
    gui_draw_rect(ix, iy, iw, ih);
    c_white();
    gui_draw_text(value, ix + 6, iy + (ih - fh) / 2);
    let vcw = gui_text_width(value);
    c_cursor();
    gui_draw_line(ix + 6 + vcw, iy + 4, ix + 6 + vcw, iy + ih - 4);

    // Buttons
    let bh    = 28;
    let btn_y = py + ph - 38;
    let ok_x  = px + pw - 174;
    let ca_x  = px + pw - 86;

    let ok_hot = in_rect(mx, my, ok_x, btn_y, 80, bh);
    if ok_hot == 1 { gui_set_color(50, 160, 230, 255); } else { c_accent(); }
    gui_fill_rect(ok_x, btn_y, 80, bh);
    c_statusbar_txt();
    let ow = gui_text_width("OK");
    gui_draw_text("OK", ok_x + (80 - ow) / 2, btn_y + (bh - fh) / 2);

    let ca_hot = in_rect(mx, my, ca_x, btn_y, 78, bh);
    if ca_hot == 1 { gui_set_color(70, 70, 70, 255); } else { gui_set_color(55, 55, 55, 255); }
    gui_fill_rect(ca_x, btn_y, 78, bh);
    c_statusbar_txt();
    let caw = gui_text_width("Cancel");
    gui_draw_text("Cancel", ca_x + (78 - caw) / 2, btn_y + (bh - fh) / 2);

    if ok_hot == 1  { return 1; }
    if ca_hot == 1  { return 2; }
    return 0;
}

// Yes / No confirmation dialog.
// Returns 1 if Yes area hovered, 2 if No area hovered, 0 otherwise.
fn draw_confirm_dialog(title: str, msg: str, mx: int, my: int) -> int {
    draw_modal_overlay();
    let ww = gui_window_width();
    let wh = gui_window_height();
    let fh = gui_font_height();
    let pw = int_min(420, ww - 120);
    let ph = 132;
    let px = (ww - pw) / 2;
    let py = (wh - ph) / 2;

    gui_set_color(245, 238, 220, 255);
    gui_fill_rect(px, py, pw, ph);
    c_border();
    gui_draw_rect(px, py, pw, ph);

    c_accent();
    gui_fill_rect(px, py, pw, 28);
    c_statusbar_txt();
    gui_draw_text(title, px + 10, py + (28 - fh) / 2);
    c_white();
    gui_draw_text(msg, px + 10, py + 40);

    let bh     = 28;
    let btn_y  = py + ph - 38;
    let yes_x  = px + pw - 182;
    let no_x   = px + pw - 90;

    let yes_hot = in_rect(mx, my, yes_x, btn_y, 84, bh);
    if yes_hot == 1 { gui_set_color(50, 160, 230, 255); } else { c_accent(); }
    gui_fill_rect(yes_x, btn_y, 84, bh);
    c_statusbar_txt();
    let yw = gui_text_width("Yes");
    gui_draw_text("Yes", yes_x + (84 - yw) / 2, btn_y + (bh - fh) / 2);

    let no_hot = in_rect(mx, my, no_x, btn_y, 80, bh);
    if no_hot == 1 { gui_set_color(200, 60, 50, 255); } else { gui_set_color(160, 50, 40, 255); }
    gui_fill_rect(no_x, btn_y, 80, bh);
    c_statusbar_txt();
    let nw = gui_text_width("No");
    gui_draw_text("No", no_x + (80 - nw) / 2, btn_y + (bh - fh) / 2);

    if yes_hot == 1 { return 1; }
    if no_hot  == 1 { return 2; }
    return 0;
}

// Info / message dialog (press Esc to dismiss).
fn draw_msg_dialog(title: str, msg: str) {
    draw_modal_overlay();
    let ww = gui_window_width();
    let wh = gui_window_height();
    let fh = gui_font_height();
    let pw = int_min(480, ww - 120);
    let ph = 114;
    let px = (ww - pw) / 2;
    let py = (wh - ph) / 2;

    gui_set_color(245, 238, 220, 255);
    gui_fill_rect(px, py, pw, ph);
    c_border();
    gui_draw_rect(px, py, pw, ph);

    c_accent();
    gui_fill_rect(px, py, pw, 28);
    c_statusbar_txt();
    gui_draw_text(title, px + 10, py + (28 - fh) / 2);
    c_white();
    gui_draw_text(msg, px + 10, py + 40);
    c_dim();
    gui_draw_text("Press Esc to close", px + 10, py + ph - 22);
}

// Right-click context menu (for file tree and explorer).
// items_str: "\n"-delimited list of item labels (max 8).
// item_count: number of items.
// Returns hovered item index (0-based), or -1 if none.
fn draw_context_menu(x: int, y: int, items_str: str, item_count: int,
                     mx: int, my: int) -> int {
    let ww    = gui_window_width();
    let wh    = gui_window_height();
    let fh    = gui_font_height();
    let mw    = 152;
    let row_h = 26;
    let mh    = item_count * row_h + 4;
    // Keep on screen
    let rx = if x + mw > ww { ww - mw - 4 } else { x };
    let ry = if y + mh > wh { wh - mh - 4 } else { y };

    // Shadow
    gui_set_color(0, 0, 0, 40);
    gui_fill_rect(rx + 3, ry + 3, mw, mh);

    // Box
    gui_set_color(250, 244, 226, 255);
    gui_fill_rect(rx, ry, mw, mh);
    c_border();
    gui_draw_rect(rx, ry, mw, mh);

    let mut hovered = -1;
    let mut i = 0;
    while i < item_count {
        let iy    = ry + 2 + i * row_h;
        let label = text_get_line(items_str, i);
        let hot   = in_rect(mx, my, rx, iy, mw, row_h);
        if hot == 1 {
            c_selection();
            gui_fill_rect(rx + 1, iy, mw - 2, row_h);
            hovered = i;
        }
        // "Delete" item in red
        if str::starts_with(label, "Delete") { c_error(); }
        else { c_white(); }
        gui_draw_text(label, rx + 10, iy + (row_h - fh) / 2);
        i = i + 1;
    }
    return hovered;
}
