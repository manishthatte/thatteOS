// frame.mt — the whole frame, drawn
// Author: Manish Jagdish Thatte
// © Manish Jagdish Thatte
//
// Split out of main.mt on 30 August 2026 (ENHANCEMENT_PLAN §5.6). PURE CODE
// MOTION: the statements below are what main() ran, with every state name
// qualified through `app` and the per-frame locals re-derived from `View` at
// the top. No condition, no ordering and no value was changed.

fn draw_frame(app: App, v: View, ww: int, wh: int, cur_file: str) {
    let mx      = v.mx;
    let my      = v.my;
    let top_bar = v.top_y;
    let bot_bar = v.bot_y;

    c_bg();
    gui_fill_rect(0, 0, ww, wh);

    draw_titlebar(app.ui.active_tab, if str_len(app.ed.open_files) > 0 { ed_tab_file(app.ed.open_files, app.ed.active_ed_tab) } else { "" },
                  app.ed.dirty, mx, my);

    if app.ui.active_tab == TAB_EDITOR() {
        // Sidebar
        if app.ed.sidebar_vis == 1 {
            draw_sidebar(app.ed.cwd,
                         if str_len(app.ed.open_files) > 0 { ed_tab_file(app.ed.open_files, app.ed.active_ed_tab) } else { "" },
                         app.ed.ft_sel, app.ed.ft_scroll, app.ed.git_out,
                         make_ctx(app.ed.ctx_row, app.ed.ctx_x, app.ed.ctx_y),
                         make_view(top_bar, bot_bar, mx, my));
        }
        // Open-file tab bar
        let ed_tab_top = top_bar;
        let ntabs = ed_tab_count(app.ed.open_files);
        if ntabs > 0 {
            draw_editor_file_tabs(app.ed.open_files, app.ed.active_ed_tab, app.ed.dirty, ed_tab_top, mx, my);
        }
        let ed_top = top_bar + (if ntabs > 0 { L_EDTAB() } else { 0 }) + L_BREADCRUMB();
        draw_breadcrumb(if str_len(app.ed.open_files) > 0 { ed_tab_file(app.ed.open_files, app.ed.active_ed_tab) } else { "" },
                        app.ed.dirty,
                        top_bar + (if ntabs > 0 { L_EDTAB() } else { 0 }));
        draw_editor(app.ed.buf, app.ed.ed_scroll, app.ed.sel_anchor, app.ed.find_q, app.ed.find_vis, app.ed.replace_q, ed_top, bot_bar);

    } elif app.ui.active_tab == TAB_EXPLORER() {
        draw_explorer(app.ex.ex_cwd_l, app.ex.ex_cwd_r, app.ex.ex_sel_l, app.ex.ex_sel_r,
                      app.ex.ex_scroll_l, app.ex.ex_scroll_r, app.ex.ex_pane,
                      make_view(top_bar, bot_bar, mx, my));
        if app.ex.ex_dlg_vis == 7 {
            draw_input_dialog("New Folder", "Folder name:", app.ex.ex_dlg_input, mx, my);
        } elif app.ex.ex_dlg_vis == 8 {
            draw_confirm_dialog("Delete", "Delete selected item?", mx, my);
        }

    } elif app.ui.active_tab == TAB_BROWSER() {
        let can_back = if app.br.br_hist_pos < text_line_count(app.br.br_hist) - 1 { 1 } else { 0 };
        let can_fwd  = if app.br.br_hist_pos > 0 { 1 } else { 0 };
        draw_browser(app.br.br_url, app.br.br_content, app.br.br_total, app.br.br_scroll, app.br.br_status,
                     make_nav(app.br.br_addr_focus, can_back, can_fwd),
                     make_view(top_bar, bot_bar, mx, my));

    } elif app.ui.active_tab == TAB_EMAIL() {
        draw_email(app.em.em_folder, app.em.em_sel, app.em.em_scroll, app.em.em_show_body,
                   make_compose(app.em.em_compose, app.em.em_to, app.em.em_sub, app.em.em_body, app.em.em_field),
                   make_view(top_bar, bot_bar, mx, my));

    } elif app.ui.active_tab == TAB_TERMINAL() {
        draw_terminal(app.tm.term_output, app.tm.term_cmd, app.tm.term_scroll, top_bar, bot_bar, mx, my);
    }

    // `cur_file` is the parameter: main() computes this same expression once
    // per frame, before the event is read, and hands the SAME snapshot to the
    // handlers. Deriving it twice would be two chances to disagree.
    draw_statusbar(cur_file, buf_line(app.ed.buf), buf_col(app.ed.buf),
                   if app.ui.active_tab == TAB_EDITOR()   { "EDITOR"   }
                   elif app.ui.active_tab == TAB_EXPLORER() { "EXPLORER" }
                   elif app.ui.active_tab == TAB_BROWSER()  { "BROWSER"  }
                   elif app.ui.active_tab == TAB_EMAIL()    { "EMAIL"    }
                   else { "TERMINAL" }, app.ed.dirty);

    // Dialogs (generic input/confirm/msg)
    if app.ui.dlg_vis == 1 { draw_input_dialog(app.ui.dlg_title, app.ui.dlg_prompt, app.ui.dlg_value, mx, my); }
    elif app.ui.dlg_vis == 2 { draw_confirm_dialog(app.ui.dlg_title, app.ui.dlg_prompt, mx, my); }
    elif app.ui.dlg_vis == 3 { draw_msg_dialog(app.ui.dlg_title, app.ui.dlg_prompt); }

    if app.ui.palette_vis == 1 { draw_palette(app.ui.palette_q, app.ui.palette_sel, mx, my); }

    gui_present();
}
