// titlebar.mt — the window title bar and the five main tabs
// Author: Manish Jagdish Thatte
// © Manish Jagdish Thatte
//
// Moved verbatim out of main.mt on 30 August 2026 (ENHANCEMENT_PLAN §5.6).
// It takes bare scalars rather than `App` on purpose: it only READS, so
// there is nothing to write back, and five arguments fit the R1-R8 budget.

fn draw_titlebar(active_tab: int, open_file: str, dirty: int, mx: int, my: int) {
    let ww = gui_window_width();
    let fh = gui_font_height();

    c_titlebar();
    gui_fill_rect(0, 0, ww, L_TITLEBAR());

    // App name
    gui_set_color(38, 139, 210, 255);
    gui_draw_text_lg("studioMani", L_MARGIN(), 5);

    // Open file indicator (right side of title bar)
    if str_len(open_file) > 0 {
        let label = if dirty == 1 { str_concat("● ", path_basename(open_file)) }
                    else { path_basename(open_file) };
        if dirty == 1 { c_warning(); } else { c_dim(); }
        let lw = gui_text_width(label);
        gui_draw_text(label, ww - lw - L_MARGIN(), (L_TITLEBAR() - fh) / 2);
    }

    // Main tab bar (below title)
    let tby    = L_TITLEBAR();
    let tab_w  = 110;
    let tab_labels = ["EDITOR", "EXPLORER", "BROWSER", "EMAIL", "TERMINAL"];
    c_tabbar();
    gui_fill_rect(0, tby, ww, L_TABBAR());
    let mut tx = L_MARGIN();
    let mut ti = 0;
    while ti < 5 {
        let hot = in_rect(mx, my, tx, tby, tab_w, L_TABBAR());
        if active_tab == ti {
            c_tab_active();
            gui_fill_rect(tx, tby, tab_w, L_TABBAR());
            c_tab_border();
            gui_draw_line(tx, tby + L_TABBAR() - 2, tx + tab_w, tby + L_TABBAR() - 2);
            c_white();
        } elif hot == 1 {
            c_tab_hover();
            gui_fill_rect(tx, tby, tab_w, L_TABBAR());
            c_text();
        } else {
            c_tab_inactive();
            gui_fill_rect(tx, tby, tab_w, L_TABBAR());
            c_dim();
        }
        let lw = gui_text_width(tab_labels[ti]);
        gui_draw_text(tab_labels[ti], tx + (tab_w - lw) / 2, tby + (L_TABBAR() - fh) / 2);
        c_border();
        gui_draw_line(tx + tab_w, tby, tx + tab_w, tby + L_TABBAR());
        tx = tx + tab_w;
        ti = ti + 1;
    }
    c_border();
    gui_draw_line(0, tby + L_TABBAR(), ww, tby + L_TABBAR());
}
