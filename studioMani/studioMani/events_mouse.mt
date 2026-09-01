// events_mouse.mt — SDL_MOUSEBUTTONDOWN
// Author: Manish Jagdish Thatte
// © Manish Jagdish Thatte
//
// Split out of main.mt on 30 August 2026 (ENHANCEMENT_PLAN §5.6). PURE CODE
// MOTION: the statements below are what main() ran, with every state name
// qualified through `app` and the per-frame locals re-derived from `View` at
// the top. No condition, no ordering and no value was changed.

fn handle_mouse(app: App, v: View, ww: int, wh: int, cur_file: str) {
    let top_bar = v.top_y;
    let bot_bar = v.bot_y;

    // SDL_MOUSEBUTTONDOWN
    let cx2 = gui_mouse_x();
    let cy2 = gui_mouse_y();
    let btn = gui_mouse_btn();

    // Context menu click — handle BEFORE dismissing
    if app.ed.ctx_row >= 0 {
        let ctx_mw = 152;
        let ctx_rh = 26;
        let ctx_mh = 5 * ctx_rh + 4;
        let ctx_rx = if app.ed.ctx_x + ctx_mw > ww { ww - ctx_mw - 4 } else { app.ed.ctx_x };
        let ctx_ry = if app.ed.ctx_y + ctx_mh > wh { wh - ctx_mh - 4 } else { app.ed.ctx_y };
        let mut cmi = 0;
        while cmi < 5 {
            let cmy = ctx_ry + 2 + cmi * ctx_rh;
            if in_rect(cx2, cy2, ctx_rx, cmy, ctx_mw, ctx_rh) == 1 {
                if cmi == 0 {
                    app.ui.dlg_vis = 1; app.ui.dlg_title = "New File"; app.ui.dlg_prompt = "File name:"; app.ui.dlg_value = ""; app.ui.dlg_action = 2;
                } elif cmi == 1 {
                    app.ui.dlg_vis = 1; app.ui.dlg_title = "New Folder"; app.ui.dlg_prompt = "Folder name:"; app.ui.dlg_value = ""; app.ui.dlg_action = 7;
                } elif cmi == 2 {
                    if str_len(cur_file) > 0 { app.ui.dlg_vis = 1; app.ui.dlg_title = "Rename"; app.ui.dlg_prompt = "New name:"; app.ui.dlg_value = path_basename(cur_file); app.ui.dlg_action = 3; }
                } elif cmi == 3 {
                    app.ex.ex_dlg_vis = 8;
                } elif cmi == 4 {
                    if str_len(cur_file) > 0 { gui_clipboard_set(cur_file); }
                }
            }
            cmi = cmi + 1;
        }
    }
    app.ed.ctx_row = -1;

    // Main tab bar clicks
    let tby2  = L_TITLEBAR();
    let tab_w = 110;
    let mut ti2 = 0;
    while ti2 < 5 {
        let tx2 = L_MARGIN() + ti2 * tab_w;
        if in_rect(cx2, cy2, tx2, tby2, tab_w, L_TABBAR()) == 1 { app.ui.active_tab = ti2; }
        ti2 = ti2 + 1;
    }

    if app.ui.active_tab == TAB_EDITOR() && app.ed.sidebar_vis == 1 {
        // Sidebar: ".." parent row
        let par_y2  = top_bar + 52;
        if in_rect(cx2, cy2, 0, par_y2, L_SIDEBAR(), 22) == 1 {
            app.ed.cwd = path_parent(app.ed.cwd); app.ed.ft_sel = 0; app.ed.ft_scroll = 0;
            app.ed.git_out = shell_exec(str_concat("git -C ", str_concat(app.ed.cwd, " status --short 2>/dev/null")));
        }
        // Sidebar: file/dir rows
        let list_top2 = par_y2 + 22 + 2;
        let row_h2    = 22;
        if in_rect(cx2, cy2, 0, list_top2, L_SIDEBAR(), bot_bar - list_top2) == 1 {
            let row2 = (cy2 - list_top2) / row_h2;
            let idx2 = app.ed.ft_scroll + row2;
            let count2 = fs_list_dir_open(app.ed.cwd);
            if idx2 < count2 {
                if btn == 3 {
                    // Right-click: show context menu
                    app.ed.ft_sel = idx2;
                    app.ed.ctx_row = idx2; app.ed.ctx_x = cx2; app.ed.ctx_y = cy2;
                } else {
                    let name2 = fs_list_dir_entry(idx2);
                    let full2 = path_join(str_concat(app.ed.cwd, ""), name2);
                    if fs_is_dir(full2) == 1 {
                        if app.ed.ft_sel == idx2 {
                            app.ed.cwd = str_concat(full2, ""); app.ed.ft_sel = 0; app.ed.ft_scroll = 0;
                            app.ed.git_out = shell_exec(str_concat("git -C ", str_concat(app.ed.cwd, " status --short 2>/dev/null")));
                        } else { app.ed.ft_sel = idx2; }
                    } else {
                        app.ed.ft_sel = idx2;
                        if app.ed.dirty == 1 && str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(app.ed.buf)); app.ed.dirty = 0; }
                        app.ed.open_files = ed_open_tab(app.ed.open_files, str_concat(full2, ""));
                        app.ed.active_ed_tab = ed_find_tab(app.ed.open_files, str_concat(full2, ""));
                        app.ed.buf = buf_new(fs_read_file(full2)); app.ed.ed_scroll = 0; app.ed.dirty = 0; app.ed.sel_anchor = -1;
                    }
                }
            }
        }

        // Editor file tab bar clicks
        let ntabs2 = ed_tab_count(app.ed.open_files);
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
                        if app.ed.dirty == 1 && eti == app.ed.active_ed_tab && str_len(cur_file) > 0 {
                            fs_write_file(cur_file, buf_text(app.ed.buf)); app.ed.dirty = 0;
                        }
                        app.ed.open_files = ed_close_tab(app.ed.open_files, eti);
                        let ntabs3 = ed_tab_count(app.ed.open_files);
                        if ntabs3 == 0 { app.ed.buf = buf_empty(); app.ed.active_ed_tab = 0; }
                        else {
                            app.ed.active_ed_tab = int_max(0, int_min(app.ed.active_ed_tab, ntabs3 - 1));
                            let nf2 = ed_tab_file(app.ed.open_files, app.ed.active_ed_tab);
                            app.ed.buf = buf_new(fs_read_file(nf2)); app.ed.ed_scroll = 0; app.ed.dirty = 0;
                        }
                    } else {
                        // Switch to tab
                        if eti != app.ed.active_ed_tab {
                            if app.ed.dirty == 1 && str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(app.ed.buf)); app.ed.dirty = 0; }
                            app.ed.active_ed_tab = eti;
                            let nf3 = ed_tab_file(app.ed.open_files, app.ed.active_ed_tab);
                            app.ed.buf = buf_new(fs_read_file(nf3)); app.ed.ed_scroll = 0; app.ed.dirty = 0; app.ed.sel_anchor = -1;
                        }
                    }
                }
                eti = eti + 1;
            }
        }
    }

    // Browser toolbar clicks
    if app.ui.active_tab == TAB_BROWSER() {
        let btn_y2 = top_bar + 4;
        let btn_h2 = 28;
        let go_x2  = ww - L_MARGIN() - 48;
        if in_rect(cx2, cy2, L_MARGIN(), btn_y2, 32, btn_h2) == 1 {
            // Back button
            let back_url2 = hist_back_url(app.br.br_hist, app.br.br_hist_pos);
            if str_len(back_url2) > 0 {
                app.br.br_hist_pos = app.br.br_hist_pos + 1;
                app.br.br_url = str_concat(back_url2, "");
                app.br.br_status = str_concat("Loading: ", app.br.br_url);
                let raw2 = net_http_get(str_concat(app.br.br_url, ""));
                app.br.br_content = collapse_blanks(strip_html(raw2));
                app.br.br_total = text_line_count(app.br.br_content); app.br.br_scroll = 0;
                app.br.br_status = str_concat("Loaded — ", app.br.br_url);
            }
        } elif in_rect(cx2, cy2, L_MARGIN() + 32, btn_y2, 32, btn_h2) == 1 {
            // Forward button
            let fwd_url2 = hist_fwd_url(app.br.br_hist, app.br.br_hist_pos);
            if str_len(fwd_url2) > 0 {
                app.br.br_hist_pos = app.br.br_hist_pos - 1;
                app.br.br_url = str_concat(fwd_url2, "");
                app.br.br_status = str_concat("Loading: ", app.br.br_url);
                let raw3 = net_http_get(str_concat(app.br.br_url, ""));
                app.br.br_content = collapse_blanks(strip_html(raw3));
                app.br.br_total = text_line_count(app.br.br_content); app.br.br_scroll = 0;
                app.br.br_status = str_concat("Loaded — ", app.br.br_url);
            }
        } elif in_rect(cx2, cy2, L_MARGIN() + 64, btn_y2, 32, btn_h2) == 1 {
            // Refresh button
            if str_len(app.br.br_url) > 0 {
                app.br.br_status = str_concat("Loading: ", app.br.br_url);
                let raw4 = net_http_get(str_concat(app.br.br_url, ""));
                app.br.br_content = collapse_blanks(strip_html(raw4));
                app.br.br_total = text_line_count(app.br.br_content); app.br.br_scroll = 0;
                app.br.br_status = str_concat("Loaded — ", app.br.br_url);
            }
        } elif in_rect(cx2, cy2, go_x2, btn_y2, 48, btn_h2) == 1 {
            // Go button
            if str_len(app.br.br_url) > 0 {
                if !str::starts_with(app.br.br_url, "http://") && !str::starts_with(app.br.br_url, "https://") {
                    app.br.br_url = str_concat("https://", app.br.br_url);
                }
                app.br.br_status = str_concat("Loading: ", app.br.br_url);
                let raw5 = net_http_get(str_concat(app.br.br_url, ""));
                app.br.br_content = collapse_blanks(strip_html(raw5));
                app.br.br_total = text_line_count(app.br.br_content);
                app.br.br_hist = hist_push(app.br.br_hist, str_concat(app.br.br_url, ""));
                app.br.br_hist_pos = 0; app.br.br_scroll = 0; app.br.br_addr_focus = 0;
                app.br.br_status = str_concat("Loaded ", str::from_int(app.br.br_total));
                app.br.br_status = str_concat(app.br.br_status, " lines  —  ");
                app.br.br_status = str_concat(app.br.br_status, app.br.br_url);
            }
        } else {
            app.br.br_addr_focus = 1;
        }
    }

    // Email: Send/Cancel in compose mode
    if app.ui.active_tab == TAB_EMAIL() && app.em.em_compose == 1 {
        let em_btn_y  = bot_bar - 56;
        let em_send_x = ww - 202;
        let em_can_x  = ww - 132;
        if in_rect(cx2, cy2, em_send_x, em_btn_y, 70, 28) == 1 {
            // Send — clear compose (SMTP not yet connected)
            app.em.em_compose = 0; app.em.em_to = ""; app.em.em_sub = ""; app.em.em_body = "";
            app.ui.dlg_vis = 3; app.ui.dlg_title = "Email"; app.ui.dlg_prompt = "Message queued (SMTP coming soon).";
        } elif in_rect(cx2, cy2, em_can_x, em_btn_y, 82, 28) == 1 {
            app.em.em_compose = 0;
        }
    }

    // Email: compose button, folder, mail row
    if app.ui.active_tab == TAB_EMAIL() && app.em.em_compose == 0 {
        let fp_w2    = 160;
        let cy_comp  = top_bar + 32 + 5 * 28 + 10;
        if in_rect(cx2, cy2, L_MARGIN(), cy_comp, fp_w2 - L_MARGIN() * 2, 30) == 1 {
            app.em.em_compose = 1; app.em.em_to = ""; app.em.em_sub = ""; app.em.em_body = ""; app.em.em_field = 0;
        }
        // Mail row click
        let ml_x2  = fp_w2;
        let ml_w2  = ww - fp_w2;
        let mrow_h = 36;
        if in_rect(cx2, cy2, ml_x2, top_bar + 28, ml_w2, bot_bar - top_bar - 28) == 1 {
            let mrow = (cy2 - top_bar - 28) / mrow_h;
            app.em.em_sel = app.em.em_scroll + mrow;
            app.em.em_show_body = 1;
        }
    }

}
