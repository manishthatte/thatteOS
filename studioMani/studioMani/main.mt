// studioMani/studioMani/main.mt — IDE shell: title bar + event loop
// All drawing delegates to the other modules (theme/layout/buffer/highlight/
// dialogs/sidebar/editor/explorer/browser/email/terminal/palette).
// This file is concatenated LAST by build.sh.
// Author: Manish Jagdish Thatte

use std::io;

// ── Title bar + main tab bar ──────────────────────────────────────────────────
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

// ── Main ──────────────────────────────────────────────────────────────────────
fn main() {
    gui_init(1400, 900, "studioMani");

    // ── Editor ───────────────────────────────────────────────────────────────
    let mut open_files    = "";        // "\n"-delimited list of open file paths
    let mut active_ed_tab = 0;
    let mut buf           = buf_empty();
    let mut ed_scroll     = 0;
    let mut dirty         = 0;
    let mut sel_anchor    = -1;        // -1 = no selection; else anchor byte offset
    let mut find_vis      = 0;         // 0=hidden 1=find 2=find+replace
    let mut find_focus    = 0;         // 0=find input 1=replace input (when find_vis==2)
    let mut find_q        = "";
    let mut replace_q     = "";
    let mut find_result   = -1;
    let mut undo_stack    = "";        // plain-text snapshots for Ctrl+Z, \r-separated
    // Sidebar
    let mut cwd           = ".";
    let mut ft_sel        = 0;
    let mut ft_scroll     = 0;
    let mut sidebar_vis   = 1;
    let mut git_out       = "";
    let mut ctx_row       = -1;        // -1 = context menu hidden
    let mut ctx_x         = 0;
    let mut ctx_y         = 0;

    // ── Explorer ─────────────────────────────────────────────────────────────
    let mut ex_cwd_l      = ".";
    let mut ex_cwd_r      = ".";
    let mut ex_sel_l      = 0;
    let mut ex_sel_r      = 0;
    let mut ex_scroll_l   = 0;
    let mut ex_scroll_r   = 0;
    let mut ex_pane       = 0;
    let mut ex_dlg_vis    = 0;         // 7=mkdir 8=del 5=copy 6=move 0=none
    let mut ex_dlg_input  = "";

    // ── Browser ──────────────────────────────────────────────────────────────
    let mut br_url        = "";
    let mut br_content    = "";
    let mut br_total      = 0;
    let mut br_scroll     = 0;
    let mut br_status     = "ready  —  Enter URL and press Enter";
    let mut br_addr_focus = 1;
    let mut br_hist       = "";
    let mut br_hist_pos   = 0;

    // ── Email ─────────────────────────────────────────────────────────────────
    let mut em_folder     = "INBOX";
    let mut em_sel        = 0;
    let mut em_scroll     = 0;
    let mut em_show_body  = 0;
    let mut em_compose    = 0;
    let mut em_to         = "";
    let mut em_sub        = "";
    let mut em_body       = "";
    let mut em_field      = 0;

    // ── Terminal ──────────────────────────────────────────────────────────────
    let mut term_output   = "studioMani terminal\n$ ";
    let mut term_cmd      = "";
    let mut term_hist     = "";
    let mut term_hist_idx = -1;
    let mut term_scroll   = 0;

    // ── Palette ───────────────────────────────────────────────────────────────
    let mut palette_vis   = 0;
    let mut palette_q     = "";
    let mut palette_sel   = 0;

    // ── Dialog ────────────────────────────────────────────────────────────────
    let mut dlg_vis       = 0;         // 0=none 1=input 2=confirm 3=msg
    let mut dlg_title     = "";
    let mut dlg_prompt    = "";
    let mut dlg_value     = "";
    let mut dlg_action    = 0;         // 1=goto_line 2=new_file 3=rename 7=mkdir

    let mut active_tab    = TAB_EDITOR();
    let mut running       = 1;

    while running == 1 {
        let ww       = gui_window_width();
        let wh       = gui_window_height();
        let mx       = gui_mouse_x();
        let my       = gui_mouse_y();
        let top_bar  = L_TITLEBAR() + L_TABBAR();
        let bot_bar  = wh - L_STATUSBAR();

        // ── Draw ─────────────────────────────────────────────────────────────
        c_bg();
        gui_fill_rect(0, 0, ww, wh);

        draw_titlebar(active_tab, if str_len(open_files) > 0 { ed_tab_file(open_files, active_ed_tab) } else { "" },
                      dirty, mx, my);

        if active_tab == TAB_EDITOR() {
            // Sidebar
            if sidebar_vis == 1 {
                draw_sidebar(cwd,
                             if str_len(open_files) > 0 { ed_tab_file(open_files, active_ed_tab) } else { "" },
                             ft_sel, ft_scroll, git_out,
                             ctx_row, ctx_x, ctx_y, mx, my, top_bar, bot_bar);
            }
            // Open-file tab bar
            let ed_tab_top = top_bar;
            let ntabs = ed_tab_count(open_files);
            if ntabs > 0 {
                draw_editor_file_tabs(open_files, active_ed_tab, dirty, ed_tab_top, mx, my);
            }
            let ed_top = top_bar + (if ntabs > 0 { L_EDTAB() } else { 0 }) + L_BREADCRUMB();
            draw_breadcrumb(if str_len(open_files) > 0 { ed_tab_file(open_files, active_ed_tab) } else { "" },
                            dirty,
                            top_bar + (if ntabs > 0 { L_EDTAB() } else { 0 }));
            draw_editor(buf, ed_scroll, sel_anchor, find_q, find_vis, replace_q, ed_top, bot_bar);

        } elif active_tab == TAB_EXPLORER() {
            draw_explorer(ex_cwd_l, ex_cwd_r, ex_sel_l, ex_sel_r,
                          ex_scroll_l, ex_scroll_r, ex_pane, top_bar, bot_bar, mx, my);
            if ex_dlg_vis == 7 {
                draw_input_dialog("New Folder", "Folder name:", ex_dlg_input, mx, my);
            } elif ex_dlg_vis == 8 {
                draw_confirm_dialog("Delete", "Delete selected item?", mx, my);
            }

        } elif active_tab == TAB_BROWSER() {
            let can_back = if br_hist_pos < text_line_count(br_hist) - 1 { 1 } else { 0 };
            let can_fwd  = if br_hist_pos > 0 { 1 } else { 0 };
            draw_browser(br_url, br_content, br_total, br_scroll,
                         br_status, br_addr_focus, can_back, can_fwd,
                         top_bar, bot_bar, mx, my);

        } elif active_tab == TAB_EMAIL() {
            draw_email(em_folder, em_sel, em_scroll, em_show_body,
                       em_compose, em_to, em_sub, em_body, em_field,
                       top_bar, bot_bar, mx, my);

        } elif active_tab == TAB_TERMINAL() {
            draw_terminal(term_output, term_cmd, term_scroll, top_bar, bot_bar, mx, my);
        }

        let cur_file = if str_len(open_files) > 0 { ed_tab_file(open_files, active_ed_tab) } else { "" };
        draw_statusbar(cur_file, buf_line(buf), buf_col(buf),
                       if active_tab == TAB_EDITOR()   { "EDITOR"   }
                       elif active_tab == TAB_EXPLORER() { "EXPLORER" }
                       elif active_tab == TAB_BROWSER()  { "BROWSER"  }
                       elif active_tab == TAB_EMAIL()    { "EMAIL"    }
                       else { "TERMINAL" }, dirty);

        // Dialogs (generic input/confirm/msg)
        if dlg_vis == 1 { draw_input_dialog(dlg_title, dlg_prompt, dlg_value, mx, my); }
        elif dlg_vis == 2 { draw_confirm_dialog(dlg_title, dlg_prompt, mx, my); }
        elif dlg_vis == 3 { draw_msg_dialog(dlg_title, dlg_prompt); }

        if palette_vis == 1 { draw_palette(palette_q, palette_sel, mx, my); }

        gui_present();

        // ── Events ───────────────────────────────────────────────────────────
        gui_wait_event(16);
        let ev = gui_event_type();

        if ev == 1 {
            // SDL_QUIT — save if dirty then exit
            if dirty == 1 && str_len(cur_file) > 0 {
                fs_write_file(cur_file, buf_text(buf));
            }
            running = 0;

        } elif ev == 2 {
            // SDL_KEYDOWN
            let k     = gui_event_key();
            let ctrl  = gui_key_mod_ctrl();
            let shift = gui_key_mod_shift();

            // ── Context menu dismiss ────────────────────────────────────────
            if ctx_row >= 0 { ctx_row = -1; }

            // ── Dialog key handling ─────────────────────────────────────────
            if dlg_vis == 1 {
                if k == gui_key_return() {
                    // Execute action
                    if dlg_action == 0 {
                        // Open file by path
                        if str_len(dlg_value) > 0 {
                            if dirty == 1 && str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(buf)); dirty = 0; }
                            open_files = ed_open_tab(open_files, str_concat(dlg_value, ""));
                            active_ed_tab = ed_find_tab(open_files, dlg_value);
                            buf = buf_new(fs_read_file(dlg_value)); ed_scroll = 0; dirty = 0; sel_anchor = -1;
                            active_tab = TAB_EDITOR();
                        }
                    } elif dlg_action == 1 {
                        // Go to line
                        let target = str::parse_int(dlg_value) - 1;
                        buf = buf_goto_line(buf, target);
                        ed_scroll = int_max(0, target - 10);
                    } elif dlg_action == 2 {
                        // New file — create and open
                        let new_path = path_join(str_concat(cwd, ""), dlg_value);
                        fs_write_file(str_concat(new_path, ""), "");
                        if dirty == 1 && str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(buf)); dirty = 0; }
                        open_files = ed_open_tab(open_files, str_concat(new_path, ""));
                        active_ed_tab = ed_find_tab(open_files, new_path);
                        buf = buf_empty(); ed_scroll = 0; dirty = 0;
                    } elif dlg_action == 3 {
                        // Rename current file
                        if str_len(cur_file) > 0 {
                            let new_name = path_join(path_dirname(cur_file), dlg_value);
                            fs_rename(str_concat(cur_file, ""), str_concat(new_name, ""));
                            open_files = ed_close_tab(open_files, active_ed_tab);
                            open_files = ed_open_tab(open_files, str_concat(new_name, ""));
                            active_ed_tab = ed_find_tab(open_files, new_name);
                        }
                    } elif dlg_action == 7 {
                        // New folder (from sidebar context menu)
                        if str_len(dlg_value) > 0 { fs_mkdir(path_join(str_concat(cwd, ""), dlg_value)); }
                    }
                    dlg_vis = 0;
                } elif k == gui_key_escape() {
                    dlg_vis = 0;
                } elif k == gui_key_backspace() {
                    let n = str_len(dlg_value);
                    if n > 0 { dlg_value = str_slice(dlg_value, 0, n - 1); }
                }

            } elif dlg_vis == 2 {
                if k == gui_key_return() || k == gui_key_f5() {
                    dlg_vis = 0;   // Confirmed action handled on click
                } elif k == gui_key_escape() {
                    dlg_vis = 0;
                }

            } elif dlg_vis == 3 {
                if k == gui_key_escape() || k == gui_key_return() { dlg_vis = 0; }

            } elif palette_vis == 1 {
                // ── Palette keys ─────────────────────────────────────────────
                if k == gui_key_escape() { palette_vis = 0; }
                elif k == gui_key_return() {
                    let action = palette_action(palette_q, palette_sel);
                    palette_vis = 0;
                    // Execute palette action
                    if action == 0 { dlg_vis = 1; dlg_title = "Open File"; dlg_prompt = "File path:"; dlg_value = str_concat(cwd, ""); dlg_action = 0; }
                    elif action == 1 { dlg_vis = 1; dlg_title = "New File"; dlg_prompt = "File name:"; dlg_value = ""; dlg_action = 2; }
                    elif action == 2 {
                        if str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(buf)); dirty = 0; }
                    }
                    elif action == 3 {
                        if str_len(open_files) > 0 {
                            if dirty == 1 && str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(buf)); dirty = 0; }
                            open_files = ed_close_tab(open_files, active_ed_tab);
                            if ed_tab_count(open_files) == 0 { buf = buf_empty(); active_ed_tab = 0; }
                            else { active_ed_tab = int_max(0, active_ed_tab - 1); let nf = ed_tab_file(open_files, active_ed_tab); buf = buf_new(fs_read_file(nf)); ed_scroll = 0; dirty = 0; }
                        }
                    }
                    elif action == 4 { dlg_vis = 1; dlg_title = "Go to Line"; dlg_prompt = "Line number:"; dlg_value = ""; dlg_action = 1; }
                    elif action == 5 { find_vis = 1; palette_vis = 0; }
                    elif action == 6 { find_vis = 2; palette_vis = 0; }
                    elif action == 7 { sidebar_vis = if sidebar_vis == 0 { 1 } else { 0 }; }
                    elif action ==  9 { active_tab = TAB_EDITOR(); }
                    elif action == 10 { active_tab = TAB_EXPLORER(); }
                    elif action == 11 { active_tab = TAB_BROWSER(); }
                    elif action == 12 { // Undo — no-op in palette (use Ctrl+Z in editor)
                    }
                }
                elif k == gui_key_up() {
                    if palette_sel > 0 { palette_sel = palette_sel - 1; }
                }
                elif k == gui_key_down() {
                    let mc = palette_match_count(palette_q);
                    if palette_sel < mc - 1 { palette_sel = palette_sel + 1; }
                }
                elif k == gui_key_backspace() {
                    let n = str_len(palette_q);
                    if n > 0 { palette_q = str_slice(palette_q, 0, n - 1); palette_sel = 0; }
                }

            } else {

                // ── Global shortcuts (no dialog/palette) ─────────────────────
                if k == gui_key_f1() {
                    palette_vis = if palette_vis == 0 { 1 } else { 0 };
                    palette_q = ""; palette_sel = 0;

                } elif k == gui_key_escape() {
                    if find_vis > 0 { find_vis = 0; }
                    elif em_compose == 1 { em_compose = 0; }
                    elif ex_dlg_vis > 0 { ex_dlg_vis = 0; }

                } elif k == gui_key_tab() && ctrl == 0 && active_tab == TAB_EDITOR() && find_vis == 0 {
                    // Tab in editor = indent
                    let old = buf_text(buf);
                    buf = buf_insert(buf, "    ");
                    dirty = 1;

                } elif k == gui_key_f3() || (k == gui_key_f() && ctrl == 1) {
                    find_vis = if find_vis > 0 { 0 } else { 1 };
                    find_q = ""; find_focus = 0;

                } elif k == gui_key_h() && ctrl == 1 {
                    find_vis = if find_vis == 2 { 0 } else { 2 };
                    find_q = ""; replace_q = ""; find_focus = 0;

                } elif k == gui_key_f4() {
                    sidebar_vis = if sidebar_vis == 0 { 1 } else { 0 };

                } elif k == gui_key_f10() { active_tab = TAB_EDITOR();   }
                elif k == gui_key_f11()  { active_tab = TAB_EXPLORER(); }
                elif k == gui_key_f12()  { active_tab = TAB_BROWSER();  }

                // ── Find bar keys ────────────────────────────────────────────
                elif active_tab == TAB_EDITOR() && find_vis > 0 {
                    if k == gui_key_backspace() {
                        if find_focus == 0 {
                            let n = str_len(find_q);
                            if n > 0 { find_q = str_slice(find_q, 0, n - 1); }
                        } else {
                            let n = str_len(replace_q);
                            if n > 0 { replace_q = str_slice(replace_q, 0, n - 1); }
                        }
                    } elif k == gui_key_return() {
                        if find_vis == 1 || find_focus == 0 {
                            // Find next
                            let text = buf_text(buf);
                            let start = if find_result >= 0 { find_result + 1 } else { 0 };
                            let res = find_next(text, find_q, start);
                            if res >= 0 {
                                find_result = res;
                                buf = buf_goto_line(buf, 0);  // reset, then jump
                                // Place cursor at result offset
                                let full = buf_text(buf);
                                buf = buf_pack(str_slice(full, 0, res), str_slice(full, res, str_len(full)));
                                let cur_ln2 = buf_line(buf);
                                ed_scroll = int_max(0, cur_ln2 - 5);
                            }
                        } elif find_vis == 2 && find_focus == 1 {
                            // Replace all
                            buf = buf_replace_all(buf, find_q, replace_q); dirty = 1;
                        }
                    } elif k == gui_key_tab() {
                        // Toggle focus between find / replace inputs
                        if find_vis == 2 { find_focus = if find_focus == 0 { 1 } else { 0 }; }
                    }

                // ── Editor keys ──────────────────────────────────────────────
                } elif active_tab == TAB_EDITOR() {
                    let old_text = buf_text(buf);

                    // Ctrl shortcuts
                    if ctrl == 1 {
                        if k == gui_key_s() {
                            if str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(buf)); dirty = 0; }
                        } elif k == gui_key_z() {
                            // Undo: pop the last snapshot from the undo stack
                            let prev = undo_pop(undo_stack);
                            if str_len(prev) > 0 {
                                undo_stack = undo_stack_without_last(undo_stack);
                                buf = buf_new(str_concat(prev, ""));
                                dirty = 1;
                            }
                        } elif k == gui_key_c() {
                            // Copy selection
                            let cur_off2 = buf_cursor_offset(buf);
                            let slo = if sel_anchor < 0 { -1 } elif sel_anchor < cur_off2 { sel_anchor } else { cur_off2 };
                            let shi = if sel_anchor < 0 { -1 } elif sel_anchor > cur_off2 { sel_anchor } else { cur_off2 };
                            if slo >= 0 && shi > slo { gui_clipboard_set(sel_text(buf, slo, shi)); }
                        } elif k == gui_key_x() {
                            // Cut selection
                            let cur_off2 = buf_cursor_offset(buf);
                            let slo = if sel_anchor < 0 { -1 } elif sel_anchor < cur_off2 { sel_anchor } else { cur_off2 };
                            let shi = if sel_anchor < 0 { -1 } elif sel_anchor > cur_off2 { sel_anchor } else { cur_off2 };
                            if slo >= 0 && shi > slo {
                                gui_clipboard_set(sel_text(buf, slo, shi));
                                buf = buf_delete_selection(buf, slo, shi);
                                sel_anchor = -1; dirty = 1;
                            }
                        } elif k == gui_key_v() {
                            // Paste
                            let clip = gui_clipboard_get();
                            let cur_off2 = buf_cursor_offset(buf);
                            let slo = if sel_anchor < 0 { -1 } elif sel_anchor < cur_off2 { sel_anchor } else { cur_off2 };
                            let shi = if sel_anchor < 0 { -1 } elif sel_anchor > cur_off2 { sel_anchor } else { cur_off2 };
                            if slo >= 0 && shi > slo { buf = buf_delete_selection(buf, slo, shi); sel_anchor = -1; }
                            buf = buf_insert(buf, clip); dirty = 1;
                        } elif k == gui_key_a() {
                            // Select all
                            let full = buf_text(buf);
                            sel_anchor = 0;
                            let flen = str_len(full);
                            buf = buf_pack(full, "");
                        } elif k == gui_key_left() {
                            buf = buf_word_left(buf);
                            if shift == 0 { sel_anchor = -1; }
                        } elif k == gui_key_right() {
                            buf = buf_word_right(buf);
                            if shift == 0 { sel_anchor = -1; }
                        } elif k == gui_key_delete() {
                            buf = buf_delete_word_right(buf); dirty = 1;
                        }
                    } else {
                        // Non-ctrl editor navigation / editing
                        if k == gui_key_backspace() {
                            let cur_off2 = buf_cursor_offset(buf);
                            let slo = if sel_anchor < 0 { -1 } elif sel_anchor < cur_off2 { sel_anchor } else { cur_off2 };
                            let shi = if sel_anchor < 0 { -1 } elif sel_anchor > cur_off2 { sel_anchor } else { cur_off2 };
                            if slo >= 0 && shi > slo { buf = buf_delete_selection(buf, slo, shi); sel_anchor = -1; }
                            else { buf = buf_backspace(buf); }
                            dirty = 1;
                        } elif k == gui_key_delete() {
                            buf = buf_delete(buf); dirty = 1;
                        } elif k == gui_key_return() {
                            let cur_off2 = buf_cursor_offset(buf);
                            let slo = if sel_anchor < 0 { -1 } elif sel_anchor < cur_off2 { sel_anchor } else { cur_off2 };
                            let shi = if sel_anchor < 0 { -1 } elif sel_anchor > cur_off2 { sel_anchor } else { cur_off2 };
                            if slo >= 0 && shi > slo { buf = buf_delete_selection(buf, slo, shi); sel_anchor = -1; }
                            buf = buf_newline_indent(buf); dirty = 1;
                        } elif k == gui_key_up() {
                            if shift == 1 && sel_anchor < 0 { sel_anchor = buf_cursor_offset(buf); }
                            buf = buf_up(buf);
                            if shift == 0 { sel_anchor = -1; }
                        } elif k == gui_key_down() {
                            if shift == 1 && sel_anchor < 0 { sel_anchor = buf_cursor_offset(buf); }
                            buf = buf_down(buf);
                            if shift == 0 { sel_anchor = -1; }
                        } elif k == gui_key_left() {
                            if shift == 1 && sel_anchor < 0 { sel_anchor = buf_cursor_offset(buf); }
                            buf = buf_left(buf);
                            if shift == 0 { sel_anchor = -1; }
                        } elif k == gui_key_right() {
                            if shift == 1 && sel_anchor < 0 { sel_anchor = buf_cursor_offset(buf); }
                            buf = buf_right(buf);
                            if shift == 0 { sel_anchor = -1; }
                        } elif k == gui_key_home() {
                            if shift == 1 && sel_anchor < 0 { sel_anchor = buf_cursor_offset(buf); }
                            buf = buf_home(buf);
                            if shift == 0 { sel_anchor = -1; }
                        } elif k == gui_key_end() {
                            if shift == 1 && sel_anchor < 0 { sel_anchor = buf_cursor_offset(buf); }
                            buf = buf_end(buf);
                            if shift == 0 { sel_anchor = -1; }
                        } elif k == gui_key_pageup() {
                            let vis = (wh - L_TITLEBAR() - L_TABBAR() - L_EDTAB() - L_BREADCRUMB() - L_STATUSBAR()) / L_LINE();
                            ed_scroll = int_max(0, ed_scroll - vis);
                        } elif k == gui_key_pagedown() {
                            let vis = (wh - L_TITLEBAR() - L_TABBAR() - L_EDTAB() - L_BREADCRUMB() - L_STATUSBAR()) / L_LINE();
                            ed_scroll = int_min(int_max(0, buf_line_count(buf) - vis), ed_scroll + vis);
                        } elif k == gui_key_f5() {
                            // Save
                            if str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(buf)); dirty = 0; }
                        }
                    }

                    // Push undo snapshot if text changed
                    if buf_text(buf) != old_text { undo_stack = undo_push(undo_stack, str_concat(old_text, "")); }

                    // Auto-scroll cursor into view
                    let cur_ln3 = buf_line(buf);
                    let vis3    = (wh - L_TITLEBAR() - L_TABBAR() - L_EDTAB() - L_BREADCRUMB() - L_STATUSBAR()) / L_LINE();
                    if cur_ln3 < ed_scroll { ed_scroll = cur_ln3; }
                    if cur_ln3 >= ed_scroll + vis3 { ed_scroll = cur_ln3 - vis3 + 1; }

                // ── Browser keys ─────────────────────────────────────────────
                } elif active_tab == TAB_BROWSER() {
                    if k == gui_key_return() && br_addr_focus == 1 {
                        if str_len(br_url) > 0 {
                            if !str::starts_with(br_url, "http://") && !str::starts_with(br_url, "https://") {
                                br_url = str_concat("https://", br_url);
                            }
                            br_status = str_concat("Loading: ", br_url);
                            let raw = net_http_get(br_url);
                            br_content = collapse_blanks(strip_html(raw));
                            br_total   = text_line_count(br_content);
                            br_hist    = hist_push(br_hist, br_url);
                            br_hist_pos = 0;
                            br_status  = str_concat("Loaded ", str::from_int(br_total));
                            br_status  = str_concat(br_status, " lines  —  ");
                            br_status  = str_concat(br_status, br_url);
                            br_scroll  = 0; br_addr_focus = 0;
                        }
                    } elif k == gui_key_backspace() && br_addr_focus == 1 {
                        let n = str_len(br_url);
                        if n > 0 { br_url = str_slice(br_url, 0, n - 1); }
                    } elif k == gui_key_up() {
                        if br_addr_focus == 0 && br_scroll > 0 { br_scroll = br_scroll - 1; }
                    } elif k == gui_key_down() {
                        if br_addr_focus == 0 { br_scroll = int_min(br_total - 1, br_scroll + 1); }
                    } elif k == gui_key_pageup() {
                        if br_addr_focus == 0 { br_scroll = int_max(0, br_scroll - 20); }
                    } elif k == gui_key_pagedown() {
                        if br_addr_focus == 0 { br_scroll = int_min(br_total - 1, br_scroll + 20); }
                    } elif k == gui_key_left() && ctrl == 0 {
                        // Back
                        let back_url = hist_back_url(br_hist, br_hist_pos);
                        if str_len(back_url) > 0 {
                            br_hist_pos = br_hist_pos + 1;
                            br_url = str_concat(back_url, "");
                            br_status = str_concat("Loading: ", br_url);
                            let raw = net_http_get(br_url);
                            br_content = collapse_blanks(strip_html(raw));
                            br_total = text_line_count(br_content);
                            br_scroll = 0;
                            br_status = str_concat("Loaded — ", br_url);
                        }
                    }

                // ── Explorer keys ────────────────────────────────────────────
                } elif active_tab == TAB_EXPLORER() {
                    if ex_dlg_vis == 7 {
                        if k == gui_key_return() {
                            if str_len(ex_dlg_input) > 0 {
                                let base_cwd = if ex_pane == 0 { str_concat(ex_cwd_l, "") } else { str_concat(ex_cwd_r, "") };
                                fs_mkdir(path_join(base_cwd, ex_dlg_input));
                            }
                            ex_dlg_vis = 0; ex_dlg_input = "";
                        } elif k == gui_key_escape() { ex_dlg_vis = 0; ex_dlg_input = ""; }
                        elif k == gui_key_backspace() {
                            let n = str_len(ex_dlg_input);
                            if n > 0 { ex_dlg_input = str_slice(ex_dlg_input, 0, n - 1); }
                        }
                    } elif ex_dlg_vis == 8 {
                        if k == gui_key_return() {
                            let del_path = ex_selected_path(ex_cwd_l, ex_cwd_r, ex_sel_l, ex_sel_r, ex_pane);
                            if str_len(del_path) > 0 { fs_delete(del_path); }
                            ex_dlg_vis = 0;
                        } elif k == gui_key_escape() { ex_dlg_vis = 0; }
                    } else {
                        if ex_pane == 0 {
                            if k == gui_key_up()   && ex_sel_l > 0 { ex_sel_l = ex_sel_l - 1; }
                            if k == gui_key_down() { ex_sel_l = ex_sel_l + 1; }
                            if k == gui_key_return() {
                                let name_l = fs_list_dir_entry(ex_sel_l);
                                let full_l = path_join(ex_cwd_l, name_l);
                                if fs_is_dir(full_l) == 1 { ex_cwd_l = str_concat(full_l, ""); ex_sel_l = 0; ex_scroll_l = 0; }
                                else {
                                    if dirty == 1 && str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(buf)); dirty = 0; }
                                    open_files = ed_open_tab(open_files, str_concat(full_l, ""));
                                    active_ed_tab = ed_find_tab(open_files, str_concat(full_l, ""));
                                    buf = buf_new(fs_read_file(full_l)); ed_scroll = 0; dirty = 0;
                                    active_tab = TAB_EDITOR();
                                }
                            }
                            if k == gui_key_backspace() { ex_cwd_l = path_parent(ex_cwd_l); ex_sel_l = 0; }
                            if k == gui_key_tab() { ex_pane = 1; }
                        } else {
                            if k == gui_key_up()   && ex_sel_r > 0 { ex_sel_r = ex_sel_r - 1; }
                            if k == gui_key_down() { ex_sel_r = ex_sel_r + 1; }
                            if k == gui_key_return() {
                                let name_r = fs_list_dir_entry(ex_sel_r);
                                let full_r = path_join(ex_cwd_r, name_r);
                                if fs_is_dir(full_r) == 1 { ex_cwd_r = str_concat(full_r, ""); ex_sel_r = 0; ex_scroll_r = 0; }
                                else {
                                    if dirty == 1 && str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(buf)); dirty = 0; }
                                    open_files = ed_open_tab(open_files, str_concat(full_r, ""));
                                    active_ed_tab = ed_find_tab(open_files, str_concat(full_r, ""));
                                    buf = buf_new(fs_read_file(full_r)); ed_scroll = 0; dirty = 0;
                                    active_tab = TAB_EDITOR();
                                }
                            }
                            if k == gui_key_backspace() { ex_cwd_r = path_parent(ex_cwd_r); ex_sel_r = 0; }
                            if k == gui_key_tab() { ex_pane = 0; }
                        }
                        // F5/F6/F7/F8
                        if k == gui_key_f5() {
                            let src = ex_selected_path(ex_cwd_l, ex_cwd_r, ex_sel_l, ex_sel_r, ex_pane);
                            let dst_dir = if ex_pane == 0 { str_concat(ex_cwd_r, "") } else { str_concat(ex_cwd_l, "") };
                            if str_len(src) > 0 { fs_copy(str_concat(src, ""), path_join(dst_dir, path_basename(src))); }
                        } elif k == gui_key_f6() {
                            let src = ex_selected_path(ex_cwd_l, ex_cwd_r, ex_sel_l, ex_sel_r, ex_pane);
                            let dst_dir = if ex_pane == 0 { str_concat(ex_cwd_r, "") } else { str_concat(ex_cwd_l, "") };
                            if str_len(src) > 0 { fs_move(str_concat(src, ""), path_join(dst_dir, path_basename(src))); }
                        } elif k == gui_key_f7() {
                            ex_dlg_vis = 7; ex_dlg_input = "";
                        } elif k == gui_key_f8() {
                            ex_dlg_vis = 8;
                        }
                    }

                // ── Terminal keys ────────────────────────────────────────────
                } elif active_tab == TAB_TERMINAL() {
                    if k == gui_key_return() {
                        let full_cmd  = str_concat("$ ", str_concat(term_cmd, "\n"));
                        term_output   = str_concat(term_output, full_cmd);
                        if str_len(term_cmd) > 0 {
                            let result = shell_exec(term_cmd);
                            term_hist     = term_hist_push(term_hist, term_cmd);
                            term_hist_idx = -1;
                            term_output   = str_concat(term_output, str_concat(result, "\n$ "));
                        } else {
                            term_output = str_concat(term_output, "$ ");
                        }
                        term_cmd    = "";
                        term_scroll = text_line_count(term_output) - 1;
                    } elif k == gui_key_backspace() {
                        let n = str_len(term_cmd);
                        if n > 0 { term_cmd = str_slice(term_cmd, 0, n - 1); }
                    } elif k == gui_key_up() {
                        // History navigation
                        term_hist_idx = term_hist_idx + 1;
                        let hcmd = term_hist_get(term_hist, term_hist_idx);
                        if str_len(hcmd) > 0 { term_cmd = str_concat(hcmd, ""); }
                        else { term_hist_idx = term_hist_idx - 1; }
                    } elif k == gui_key_down() {
                        if term_hist_idx > 0 {
                            term_hist_idx = term_hist_idx - 1;
                            term_cmd = term_hist_get(term_hist, term_hist_idx);
                        } elif term_hist_idx == 0 {
                            term_hist_idx = -1; term_cmd = "";
                        }
                    } elif k == gui_key_pageup() {
                        term_scroll = int_max(0, term_scroll - 10);
                    } elif k == gui_key_pagedown() {
                        term_scroll = int_min(text_line_count(term_output) - 1, term_scroll + 10);
                    } elif k == gui_key_c() && ctrl == 1 {
                        // Ctrl+C: interrupt (clear current line, add ^C marker)
                        term_output = str_concat(term_output, "^C\n$ ");
                        term_cmd = "";
                    }

                // ── Email keys ───────────────────────────────────────────────
                } elif active_tab == TAB_EMAIL() {
                    if em_compose == 1 {
                        if k == gui_key_tab()       { em_field = (em_field + 1) % 3; }
                        elif k == gui_key_escape()  { em_compose = 0; }
                        elif k == gui_key_backspace() {
                            if em_field == 0      { let n = str_len(em_to);   if n > 0 { em_to   = str_slice(em_to,   0, n - 1); } }
                            elif em_field == 1    { let n = str_len(em_sub);  if n > 0 { em_sub  = str_slice(em_sub,  0, n - 1); } }
                            else                  { let n = str_len(em_body); if n > 0 { em_body = str_slice(em_body, 0, n - 1); } }
                        }
                        elif k == gui_key_return() && em_field == 2 {
                            em_body = str_concat(em_body, "\n");
                        }
                    } else {
                        if k == gui_key_up()   && em_sel > 0 { em_sel = em_sel - 1; em_show_body = 1; }
                        if k == gui_key_down() { em_sel = em_sel + 1; em_show_body = 1; }
                        if k == gui_key_return() { em_show_body = if em_show_body == 0 { 1 } else { 0 }; }
                        if k == gui_key_f2()   { em_compose = 1; em_to = ""; em_sub = ""; em_body = ""; em_field = 0; }
                    }
                }
            }   // end key handling

            // ── Main tab switch via tab key ──────────────────────────────────
            if k == gui_key_tab() && ctrl == 1 {
                active_tab = (active_tab + 1) % 5;
            }

        } elif ev == 6 {
            // SDL_TEXTINPUT — typed character
            let ch = gui_event_text_str();

            if dlg_vis == 1 {
                dlg_value = str_concat(dlg_value, ch);
            } elif dlg_vis == 0 && ex_dlg_vis == 7 {
                ex_dlg_input = str_concat(ex_dlg_input, ch);
            } elif palette_vis == 1 {
                palette_q = str_concat(palette_q, ch); palette_sel = 0;
            } elif active_tab == TAB_EDITOR() && find_vis > 0 {
                if find_vis == 2 && find_focus == 1 {
                    replace_q = str_concat(replace_q, ch);
                } else {
                    find_q = str_concat(find_q, ch);
                }
            } elif active_tab == TAB_EDITOR() {
                buf = buf_insert(buf, ch); dirty = 1;
                let cur_ln4 = buf_line(buf);
                let vis4    = (wh - L_TITLEBAR() - L_TABBAR() - L_EDTAB() - L_BREADCRUMB() - L_STATUSBAR()) / L_LINE();
                if cur_ln4 >= ed_scroll + vis4 { ed_scroll = cur_ln4 - vis4 + 1; }
                sel_anchor = -1;
            } elif active_tab == TAB_BROWSER() && br_addr_focus == 1 {
                br_url = str_concat(br_url, ch);
            } elif active_tab == TAB_TERMINAL() {
                term_cmd = str_concat(term_cmd, ch);
            } elif active_tab == TAB_EMAIL() && em_compose == 1 {
                if em_field == 0      { em_to   = str_concat(em_to,   ch); }
                elif em_field == 1    { em_sub  = str_concat(em_sub,  ch); }
                else                  { em_body = str_concat(em_body, ch); }
            }

        } elif ev == 4 {
            // SDL_MOUSEBUTTONDOWN
            let cx2 = gui_mouse_x();
            let cy2 = gui_mouse_y();
            let btn = gui_mouse_btn();

            // Context menu click — handle BEFORE dismissing
            if ctx_row >= 0 {
                let ctx_mw = 152;
                let ctx_rh = 26;
                let ctx_mh = 5 * ctx_rh + 4;
                let ctx_rx = if ctx_x + ctx_mw > ww { ww - ctx_mw - 4 } else { ctx_x };
                let ctx_ry = if ctx_y + ctx_mh > wh { wh - ctx_mh - 4 } else { ctx_y };
                let mut cmi = 0;
                while cmi < 5 {
                    let cmy = ctx_ry + 2 + cmi * ctx_rh;
                    if in_rect(cx2, cy2, ctx_rx, cmy, ctx_mw, ctx_rh) == 1 {
                        if cmi == 0 {
                            dlg_vis = 1; dlg_title = "New File"; dlg_prompt = "File name:"; dlg_value = ""; dlg_action = 2;
                        } elif cmi == 1 {
                            dlg_vis = 1; dlg_title = "New Folder"; dlg_prompt = "Folder name:"; dlg_value = ""; dlg_action = 7;
                        } elif cmi == 2 {
                            if str_len(cur_file) > 0 { dlg_vis = 1; dlg_title = "Rename"; dlg_prompt = "New name:"; dlg_value = path_basename(cur_file); dlg_action = 3; }
                        } elif cmi == 3 {
                            ex_dlg_vis = 8;
                        } elif cmi == 4 {
                            if str_len(cur_file) > 0 { gui_clipboard_set(cur_file); }
                        }
                    }
                    cmi = cmi + 1;
                }
            }
            ctx_row = -1;

            // Main tab bar clicks
            let tby2  = L_TITLEBAR();
            let tab_w = 110;
            let mut ti2 = 0;
            while ti2 < 5 {
                let tx2 = L_MARGIN() + ti2 * tab_w;
                if in_rect(cx2, cy2, tx2, tby2, tab_w, L_TABBAR()) == 1 { active_tab = ti2; }
                ti2 = ti2 + 1;
            }

            if active_tab == TAB_EDITOR() && sidebar_vis == 1 {
                // Sidebar: ".." parent row
                let par_y2  = top_bar + 52;
                if in_rect(cx2, cy2, 0, par_y2, L_SIDEBAR(), 22) == 1 {
                    cwd = path_parent(cwd); ft_sel = 0; ft_scroll = 0;
                    git_out = shell_exec(str_concat("git -C ", str_concat(cwd, " status --short 2>/dev/null")));
                }
                // Sidebar: file/dir rows
                let list_top2 = par_y2 + 22 + 2;
                let row_h2    = 22;
                if in_rect(cx2, cy2, 0, list_top2, L_SIDEBAR(), bot_bar - list_top2) == 1 {
                    let row2 = (cy2 - list_top2) / row_h2;
                    let idx2 = ft_scroll + row2;
                    let count2 = fs_list_dir_open(cwd);
                    if idx2 < count2 {
                        if btn == 3 {
                            // Right-click: show context menu
                            ft_sel = idx2;
                            ctx_row = idx2; ctx_x = cx2; ctx_y = cy2;
                        } else {
                            let name2 = fs_list_dir_entry(idx2);
                            let full2 = path_join(str_concat(cwd, ""), name2);
                            if fs_is_dir(full2) == 1 {
                                if ft_sel == idx2 {
                                    cwd = str_concat(full2, ""); ft_sel = 0; ft_scroll = 0;
                                    git_out = shell_exec(str_concat("git -C ", str_concat(cwd, " status --short 2>/dev/null")));
                                } else { ft_sel = idx2; }
                            } else {
                                ft_sel = idx2;
                                if dirty == 1 && str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(buf)); dirty = 0; }
                                open_files = ed_open_tab(open_files, str_concat(full2, ""));
                                active_ed_tab = ed_find_tab(open_files, str_concat(full2, ""));
                                buf = buf_new(fs_read_file(full2)); ed_scroll = 0; dirty = 0; sel_anchor = -1;
                            }
                        }
                    }
                }

                // Editor file tab bar clicks
                let ntabs2 = ed_tab_count(open_files);
                if ntabs2 > 0 {
                    let et_top = top_bar;
                    let et_w   = 160;
                    let mut eti = 0;
                    while eti < ntabs2 {
                        let etx = eti * et_w;
                        if in_rect(cx2, cy2, etx, et_top, et_w, L_EDTAB()) == 1 {
                            // Check close button
                            let close_x = etx + et_w - 18;
                            if in_rect(cx2, cy2, close_x - 2, et_top + 4, 16, L_EDTAB() - 8) == 1 {
                                // Close tab
                                if dirty == 1 && eti == active_ed_tab && str_len(cur_file) > 0 {
                                    fs_write_file(cur_file, buf_text(buf)); dirty = 0;
                                }
                                open_files = ed_close_tab(open_files, eti);
                                let ntabs3 = ed_tab_count(open_files);
                                if ntabs3 == 0 { buf = buf_empty(); active_ed_tab = 0; }
                                else {
                                    active_ed_tab = int_max(0, int_min(active_ed_tab, ntabs3 - 1));
                                    let nf2 = ed_tab_file(open_files, active_ed_tab);
                                    buf = buf_new(fs_read_file(nf2)); ed_scroll = 0; dirty = 0;
                                }
                            } else {
                                // Switch to tab
                                if eti != active_ed_tab {
                                    if dirty == 1 && str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(buf)); dirty = 0; }
                                    active_ed_tab = eti;
                                    let nf3 = ed_tab_file(open_files, active_ed_tab);
                                    buf = buf_new(fs_read_file(nf3)); ed_scroll = 0; dirty = 0; sel_anchor = -1;
                                }
                            }
                        }
                        eti = eti + 1;
                    }
                }
            }

            // Browser toolbar clicks
            if active_tab == TAB_BROWSER() {
                let btn_y2 = top_bar + 4;
                let btn_h2 = 28;
                let go_x2  = ww - L_MARGIN() - 48;
                if in_rect(cx2, cy2, L_MARGIN(), btn_y2, 32, btn_h2) == 1 {
                    // Back button
                    let back_url2 = hist_back_url(br_hist, br_hist_pos);
                    if str_len(back_url2) > 0 {
                        br_hist_pos = br_hist_pos + 1;
                        br_url = str_concat(back_url2, "");
                        br_status = str_concat("Loading: ", br_url);
                        let raw2 = net_http_get(str_concat(br_url, ""));
                        br_content = collapse_blanks(strip_html(raw2));
                        br_total = text_line_count(br_content); br_scroll = 0;
                        br_status = str_concat("Loaded — ", br_url);
                    }
                } elif in_rect(cx2, cy2, L_MARGIN() + 32, btn_y2, 32, btn_h2) == 1 {
                    // Forward button
                    let fwd_url2 = hist_fwd_url(br_hist, br_hist_pos);
                    if str_len(fwd_url2) > 0 {
                        br_hist_pos = br_hist_pos - 1;
                        br_url = str_concat(fwd_url2, "");
                        br_status = str_concat("Loading: ", br_url);
                        let raw3 = net_http_get(str_concat(br_url, ""));
                        br_content = collapse_blanks(strip_html(raw3));
                        br_total = text_line_count(br_content); br_scroll = 0;
                        br_status = str_concat("Loaded — ", br_url);
                    }
                } elif in_rect(cx2, cy2, L_MARGIN() + 64, btn_y2, 32, btn_h2) == 1 {
                    // Refresh button
                    if str_len(br_url) > 0 {
                        br_status = str_concat("Loading: ", br_url);
                        let raw4 = net_http_get(str_concat(br_url, ""));
                        br_content = collapse_blanks(strip_html(raw4));
                        br_total = text_line_count(br_content); br_scroll = 0;
                        br_status = str_concat("Loaded — ", br_url);
                    }
                } elif in_rect(cx2, cy2, go_x2, btn_y2, 48, btn_h2) == 1 {
                    // Go button
                    if str_len(br_url) > 0 {
                        if !str::starts_with(br_url, "http://") && !str::starts_with(br_url, "https://") {
                            br_url = str_concat("https://", br_url);
                        }
                        br_status = str_concat("Loading: ", br_url);
                        let raw5 = net_http_get(str_concat(br_url, ""));
                        br_content = collapse_blanks(strip_html(raw5));
                        br_total = text_line_count(br_content);
                        br_hist = hist_push(br_hist, str_concat(br_url, ""));
                        br_hist_pos = 0; br_scroll = 0; br_addr_focus = 0;
                        br_status = str_concat("Loaded ", str::from_int(br_total));
                        br_status = str_concat(br_status, " lines  —  ");
                        br_status = str_concat(br_status, br_url);
                    }
                } else {
                    br_addr_focus = 1;
                }
            }

            // Email: Send/Cancel in compose mode
            if active_tab == TAB_EMAIL() && em_compose == 1 {
                let em_btn_y  = bot_bar - 56;
                let em_send_x = ww - 202;
                let em_can_x  = ww - 132;
                if in_rect(cx2, cy2, em_send_x, em_btn_y, 70, 28) == 1 {
                    // Send — clear compose (SMTP not yet connected)
                    em_compose = 0; em_to = ""; em_sub = ""; em_body = "";
                    dlg_vis = 3; dlg_title = "Email"; dlg_prompt = "Message queued (SMTP coming soon).";
                } elif in_rect(cx2, cy2, em_can_x, em_btn_y, 82, 28) == 1 {
                    em_compose = 0;
                }
            }

            // Email: compose button, folder, mail row
            if active_tab == TAB_EMAIL() && em_compose == 0 {
                let fp_w2    = 160;
                let cy_comp  = top_bar + 32 + 5 * 28 + 10;
                if in_rect(cx2, cy2, L_MARGIN(), cy_comp, fp_w2 - L_MARGIN() * 2, 30) == 1 {
                    em_compose = 1; em_to = ""; em_sub = ""; em_body = ""; em_field = 0;
                }
                // Mail row click
                let ml_x2  = fp_w2;
                let ml_w2  = ww - fp_w2;
                let mrow_h = 36;
                if in_rect(cx2, cy2, ml_x2, top_bar + 28, ml_w2, bot_bar - top_bar - 28) == 1 {
                    let mrow = (cy2 - top_bar - 28) / mrow_h;
                    em_sel = em_scroll + mrow;
                    em_show_body = 1;
                }
            }

        } elif ev == 7 {
            // SDL_MOUSEWHEEL
            let wy = gui_wheel_dy();
            if active_tab == TAB_EDITOR() {
                if wy > 0 { ed_scroll = int_max(0, ed_scroll - 3); }
                else { ed_scroll = int_min(int_max(0, buf_line_count(buf) - 1), ed_scroll + 3); }
            } elif active_tab == TAB_BROWSER() {
                if wy > 0 { br_scroll = int_max(0, br_scroll - 3); }
                else { br_scroll = int_min(int_max(0, br_total - 1), br_scroll + 3); }
            } elif active_tab == TAB_TERMINAL() {
                if wy > 0 { term_scroll = int_max(0, term_scroll - 3); }
                else { term_scroll = int_min(text_line_count(term_output) - 1, term_scroll + 3); }
            } elif active_tab == TAB_EMAIL() && em_show_body == 1 {
                // scroll body (not implemented per-mail yet)
            }
        }
    }

    gui_quit();
}
