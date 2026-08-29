// studioMani/studioMani/explorer.mt — dual-pane file manager (EXPLORER tab)
// F5=copy, F6=move, F7=mkdir, F8=delete.  Tab key switches active pane.
// Depends on: theme.mt, layout.mt, dialogs.mt
// Author: Manish Jagdish Thatte

fn draw_explorer(cwd_l: str, cwd_r: str, sel_l: int, sel_r: int,
                 scroll_l: int, scroll_r: int,
                 active_pane: int, top_y: int, bot_y: int,
                 mx: int, my: int) {
    let ww    = gui_window_width();
    let fh    = gui_font_height();
    let half  = ww / 2;
    let ph    = 26;    // pane header height
    let row_h = 22;
    let tool_h = 34;
    let list_top = top_y + ph + 2;
    let list_bot = bot_y - tool_h;
    let visible  = (list_bot - list_top) / row_h;

    // Pane header bar
    c_tabbar();
    gui_fill_rect(0, top_y, ww, ph);
    c_border();
    gui_draw_line(half, top_y, half, list_bot);
    gui_draw_line(0, top_y + ph, ww, top_y + ph);

    // Path labels in headers
    if active_pane == 0 { c_accent(); } else { c_dim(); }
    gui_draw_text(cwd_l, L_MARGIN(), top_y + (ph - fh) / 2);
    if active_pane == 1 { c_accent(); } else { c_dim(); }
    gui_draw_text(cwd_r, half + L_MARGIN(), top_y + (ph - fh) / 2);

    // ── Left pane ──────────────────────────────────────────────────────────
    let count_l = fs_list_dir_open(cwd_l);
    let mut li  = 0;
    // ".." entry
    let par_l_y   = list_top;
    let par_l_hot = in_rect(mx, my, 0, par_l_y, half, row_h);
    if par_l_hot == 1 { c_hover(); gui_fill_rect(0, par_l_y, half, row_h); }
    c_dim();
    gui_draw_text("↑ ..", L_MARGIN() + 8, par_l_y + (row_h - fh) / 2);

    let lfile_top = list_top + row_h;
    let lvis      = (list_bot - lfile_top) / row_h;
    while li < lvis {
        let idx  = scroll_l + li;
        if idx >= count_l { li = lvis; } else {
        let name = fs_list_dir_entry(idx);
        let full = path_join(cwd_l, name);
        let is_d = fs_is_dir(full);
        let ry   = lfile_top + li * row_h;
        let sel  = if active_pane == 0 && sel_l == idx { 1 } else { 0 };
        let hot  = in_rect(mx, my, 0, ry, half, row_h);

        if sel == 1 { c_selection(); gui_fill_rect(0, ry, half, row_h); }
        elif hot == 1 { c_hover(); gui_fill_rect(0, ry, half, row_h); }

        if is_d == 1 {
            c_ft_dir();
            gui_draw_text(str_concat("▸ ", name), L_MARGIN() + 8, ry + (row_h - fh) / 2);
        } else {
            ft_ext_color(name);
            let size_s = "";   // fs_file_size available but keep row clean
            gui_draw_text(str_concat("  ", name), L_MARGIN() + 8, ry + (row_h - fh) / 2);
        }
        c_border();
        gui_draw_line(0, ry + row_h - 1, half - 1, ry + row_h - 1);
        li = li + 1;
        }
    }
    draw_scrollbar(half - 12, lfile_top, list_bot - lfile_top, count_l, lvis, scroll_l);

    // ── Right pane ─────────────────────────────────────────────────────────
    let count_r = fs_list_dir_open(cwd_r);
    let mut ri  = 0;
    let par_r_y   = list_top;
    let par_r_hot = in_rect(mx, my, half, par_r_y, half, row_h);
    if par_r_hot == 1 { c_hover(); gui_fill_rect(half, par_r_y, half, row_h); }
    c_dim();
    gui_draw_text("↑ ..", half + L_MARGIN() + 8, par_r_y + (row_h - fh) / 2);

    let rfile_top = list_top + row_h;
    let rvis      = (list_bot - rfile_top) / row_h;
    while ri < rvis {
        let idx  = scroll_r + ri;
        if idx >= count_r { ri = rvis; } else {
        let name = fs_list_dir_entry(idx);
        let full = path_join(cwd_r, name);
        let is_d = fs_is_dir(full);
        let ry   = rfile_top + ri * row_h;
        let sel  = if active_pane == 1 && sel_r == idx { 1 } else { 0 };
        let hot  = in_rect(mx, my, half, ry, half, row_h);

        if sel == 1 { c_selection(); gui_fill_rect(half, ry, half, row_h); }
        elif hot == 1 { c_hover(); gui_fill_rect(half, ry, half, row_h); }

        if is_d == 1 {
            c_ft_dir();
            gui_draw_text(str_concat("▸ ", name), half + L_MARGIN() + 8, ry + (row_h - fh) / 2);
        } else {
            ft_ext_color(name);
            gui_draw_text(str_concat("  ", name), half + L_MARGIN() + 8, ry + (row_h - fh) / 2);
        }
        c_border();
        gui_draw_line(half, ry + row_h - 1, ww, ry + row_h - 1);
        ri = ri + 1;
        }
    }
    draw_scrollbar(ww - 12, rfile_top, list_bot - rfile_top, count_r, rvis, scroll_r);

    // ── Bottom toolbar ─────────────────────────────────────────────────────
    let tool_y = list_bot;
    c_tabbar();
    gui_fill_rect(0, tool_y, ww, tool_h);
    c_border();
    gui_draw_line(0, tool_y, ww, tool_y);
    let mut bx2 = L_MARGIN();
    bx2 = draw_btn("F5 Copy",  bx2, tool_y + 3, 78, 26, mx, my);
    bx2 = draw_btn("F6 Move",  bx2, tool_y + 3, 78, 26, mx, my);
    bx2 = draw_btn("F7 MkDir", bx2, tool_y + 3, 86, 26, mx, my);
    bx2 = draw_btn("F8 Del",   bx2, tool_y + 3, 72, 26, mx, my);

    // Active-pane indicator
    let pane_label = if active_pane == 0 { "← Left  (Tab to switch)" }
                     else { "Right → (Tab to switch)" };
    c_dim();
    gui_draw_text(pane_label, bx2 + 12, tool_y + (tool_h - gui_font_height()) / 2);
}

// Returns the selected entry's full path in the given pane (active_pane 0=left,1=right).
fn ex_selected_path(cwd_l: str, cwd_r: str, sel_l: int, sel_r: int,
                    active_pane: int) -> str {
    if active_pane == 0 {
        let count_l = fs_list_dir_open(cwd_l);
        if sel_l < 0 || sel_l >= count_l { return ""; }
        return path_join(cwd_l, fs_list_dir_entry(sel_l));
    }
    let count_r = fs_list_dir_open(cwd_r);
    if sel_r < 0 || sel_r >= count_r { return ""; }
    return path_join(cwd_r, fs_list_dir_entry(sel_r));
}

// ── ExplorerState ─────────────────────────────────────────────────────────────
struct ExplorerState {
    pub ex_cwd_l:     str,
    pub ex_cwd_r:     str,
    pub ex_sel_l:     int,
    pub ex_sel_r:     int,
    pub ex_scroll_l:  int,
    pub ex_scroll_r:  int,
    pub ex_pane:      int,   // 0=left active, 1=right active
    pub ex_dlg_vis:   int,   // 0=none 5=copy 6=move 7=mkdir 8=delete
    pub ex_dlg_input: str,
}

fn explorer_state_init(cwd: str) -> ExplorerState {
    // A struct-literal FIELD is one of the four sites maniTC's move checker
    // consumes at (report.txt P51), so `cwd` cannot fill two of them. Passing a
    // value to a function does NOT move it, so the second copy comes from a call.
    let cwd_r: str = str::concat(cwd, "");
    return ExplorerState {
        ex_cwd_l: cwd, ex_cwd_r: cwd_r,
        ex_sel_l: 0, ex_sel_r: 0,
        ex_scroll_l: 0, ex_scroll_r: 0,
        ex_pane: 0, ex_dlg_vis: 0, ex_dlg_input: "",
    };
}
