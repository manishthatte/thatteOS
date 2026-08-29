// studioMani/studioMani/palette.mt — VSCode-style command palette
// F1 to open. Type to filter. Enter to execute. Esc to dismiss.
// Depends on: theme.mt, layout.mt (in_rect, int_min)
// Author: Manish Jagdish Thatte

// All available commands (index matches action codes used in main.mt).
fn palette_label(idx: int) -> str {
    if idx ==  0 { return "Open File…"; }
    if idx ==  1 { return "New File"; }
    if idx ==  2 { return "Save File"; }
    if idx ==  3 { return "Close Tab"; }
    if idx ==  4 { return "Go to Line…"; }
    if idx ==  5 { return "Find in File  (Ctrl+F)"; }
    if idx ==  6 { return "Find + Replace  (Ctrl+H)"; }
    if idx ==  7 { return "Toggle Sidebar  (F4)"; }
    if idx ==  8 { return "Toggle Terminal  (F12→TERM)"; }
    if idx ==  9 { return "Switch to Editor  (F10)"; }
    if idx == 10 { return "Switch to Explorer  (F11)"; }
    if idx == 11 { return "Switch to Browser  (F12)"; }
    if idx == 12 { return "Undo  (Ctrl+Z)"; }
    if idx == 13 { return "Redo  (Ctrl+Y)"; }
    if idx == 14 { return "Copy  (Ctrl+C)"; }
    if idx == 15 { return "Paste  (Ctrl+V)"; }
    return "";
}

fn palette_count() -> int { return 16; }

// Returns 1 if label matches query (case-insensitive prefix or substring).
fn palette_matches(label: str, query: str) -> int {
    if str_len(query) == 0 { return 1; }
    let ll = str::to_lower(label);
    let ql = str::to_lower(query);
    return if find_first(ll, ql) >= 0 { 1 } else { 0 };
}

// Draw the command palette overlay.
// sel_idx: currently highlighted row (keyboard navigation).
// Returns the action index of the item the cursor is hovering over, or -1.
fn draw_palette(query: str, sel_idx: int, mx: int, my: int) -> int {
    let ww = gui_window_width();
    let wh = gui_window_height();
    let fh = gui_font_height();

    // Dim overlay
    gui_set_color(0, 0, 0, 130);
    gui_fill_rect(0, 0, ww, wh);

    // Palette box — top-center (VSCode style)
    let pw = int_min(620, ww - 80);
    let px = (ww - pw) / 2;
    let py = 60;

    // Count matching items
    let n       = palette_count();
    let row_h   = 28;
    let input_h = 38;
    let mut match_count = 0;
    let mut i   = 0;
    while i < n {
        if palette_matches(palette_label(i), query) == 1 { match_count = match_count + 1; }
        i = i + 1;
    }
    let ph = input_h + match_count * row_h + 4;

    // Box shadow
    gui_set_color(0, 0, 0, 60);
    gui_fill_rect(px + 4, py + 4, pw, ph);

    // Box
    gui_set_color(245, 238, 220, 255);
    gui_fill_rect(px, py, pw, ph);
    c_accent();
    gui_draw_rect(px, py, pw, ph);

    // Input row
    gui_set_color(253, 246, 227, 255);
    gui_fill_rect(px + 1, py, pw - 2, input_h);
    c_border();
    gui_draw_line(px, py + input_h, px + pw, py + input_h);
    c_white();
    gui_draw_text(query, px + 12, py + (input_h - fh) / 2);
    let qcw = gui_text_width(query);
    c_cursor();
    gui_draw_line(px + 12 + qcw, py + 8, px + 12 + qcw, py + input_h - 8);
    // Hint
    c_dim();
    let hint = "type to filter, Enter to execute, Esc to close";
    let hw = gui_text_width(hint);
    gui_draw_text(hint, px + pw - hw - 10, py + (input_h - fh) / 2);

    // Item rows
    let mut row    = 0;
    let mut hovered = -1;
    let mut idx    = 0;
    while idx < n {
        let label = palette_label(idx);
        if palette_matches(label, query) == 1 {
            let ry    = py + input_h + 2 + row * row_h;
            let hot   = in_rect(mx, my, px, ry, pw, row_h);
            let is_sel = if row == sel_idx { 1 } else { 0 };

            if is_sel == 1 {
                c_selection();
                gui_fill_rect(px + 1, ry, pw - 2, row_h);
                c_white();
            } elif hot == 1 {
                c_hover();
                gui_fill_rect(px + 1, ry, pw - 2, row_h);
                c_dim();
                hovered = idx;
            } else {
                c_dim();
            }
            // Cmd number hint (right side)
            let num_s = str::from_int(idx);
            let nw2   = gui_text_width(num_s);
            gui_set_color(180, 180, 180, 255);
            gui_draw_text(num_s, px + pw - nw2 - 10, ry + (row_h - fh) / 2);

            if is_sel == 1 { c_white(); } else { c_text(); }
            gui_draw_text(label, px + 16, ry + (row_h - fh) / 2);
            row = row + 1;
        }
        idx = idx + 1;
    }

    if match_count == 0 {
        c_dim();
        gui_draw_text("No matching commands", px + 16,
                      py + input_h + 2 + (row_h - fh) / 2);
    }

    return hovered;
}

// Given a query, return the action code of the sel_idx-th matching item, or -1.
fn palette_action(query: str, sel_idx: int) -> int {
    let n   = palette_count();
    let mut row = 0;
    let mut i   = 0;
    while i < n {
        if palette_matches(palette_label(i), query) == 1 {
            if row == sel_idx { return i; }
            row = row + 1;
        }
        i = i + 1;
    }
    return -1;
}

// Count matching items for a query (used for sel_idx bounds checking).
fn palette_match_count(query: str) -> int {
    let n   = palette_count();
    let mut count = 0;
    let mut i = 0;
    while i < n {
        if palette_matches(palette_label(i), query) == 1 { count = count + 1; }
        i = i + 1;
    }
    return count;
}
