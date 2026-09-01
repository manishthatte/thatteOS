// events_key.mt — SDL_KEYDOWN
// Author: Manish Jagdish Thatte
// © Manish Jagdish Thatte
//
// Split out of main.mt on 30 August 2026 (ENHANCEMENT_PLAN §5.6). PURE CODE
// MOTION: the statements below are what main() ran, with every state name
// qualified through `app` and the per-frame locals re-derived from `View` at
// the top. No condition, no ordering and no value was changed.

fn handle_key(app: App, wh: int, cur_file: str) {

    // SDL_KEYDOWN
    let k     = gui_event_key();
    let ctrl  = gui_key_mod_ctrl();
    let shift = gui_key_mod_shift();

    // ── Context menu dismiss ────────────────────────────────────────
    if app.ed.ctx_row >= 0 { app.ed.ctx_row = -1; }

    // ── Dialog key handling ─────────────────────────────────────────
    if app.ui.dlg_vis == 1 {
        if k == gui_key_return() {
            // Execute action
            if app.ui.dlg_action == 0 {
                // Open file by path
                if str_len(app.ui.dlg_value) > 0 {
                    if app.ed.dirty == 1 && str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(app.ed.buf)); app.ed.dirty = 0; }
                    app.ed.open_files = ed_open_tab(app.ed.open_files, str_concat(app.ui.dlg_value, ""));
                    app.ed.active_ed_tab = ed_find_tab(app.ed.open_files, app.ui.dlg_value);
                    app.ed.buf = buf_new(fs_read_file(app.ui.dlg_value)); app.ed.ed_scroll = 0; app.ed.dirty = 0; app.ed.sel_anchor = -1;
                    app.ui.active_tab = TAB_EDITOR();
                }
            } elif app.ui.dlg_action == 1 {
                // Go to line
                let target = str::parse_int(app.ui.dlg_value) - 1;
                app.ed.buf = buf_goto_line(app.ed.buf, target);
                app.ed.ed_scroll = int_max(0, target - 10);
            } elif app.ui.dlg_action == 2 {
                // New file — create and open
                let new_path = path_join(str_concat(app.ed.cwd, ""), app.ui.dlg_value);
                fs_write_file(str_concat(new_path, ""), "");
                if app.ed.dirty == 1 && str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(app.ed.buf)); app.ed.dirty = 0; }
                app.ed.open_files = ed_open_tab(app.ed.open_files, str_concat(new_path, ""));
                app.ed.active_ed_tab = ed_find_tab(app.ed.open_files, new_path);
                app.ed.buf = buf_empty(); app.ed.ed_scroll = 0; app.ed.dirty = 0;
            } elif app.ui.dlg_action == 3 {
                // Rename current file
                if str_len(cur_file) > 0 {
                    let new_name = path_join(path_dirname(cur_file), app.ui.dlg_value);
                    fs_rename(str_concat(cur_file, ""), str_concat(new_name, ""));
                    app.ed.open_files = ed_close_tab(app.ed.open_files, app.ed.active_ed_tab);
                    app.ed.open_files = ed_open_tab(app.ed.open_files, str_concat(new_name, ""));
                    app.ed.active_ed_tab = ed_find_tab(app.ed.open_files, new_name);
                }
            } elif app.ui.dlg_action == 7 {
                // New folder (from sidebar context menu)
                if str_len(app.ui.dlg_value) > 0 { fs_mkdir(path_join(str_concat(app.ed.cwd, ""), app.ui.dlg_value)); }
            }
            app.ui.dlg_vis = 0;
        } elif k == gui_key_escape() {
            app.ui.dlg_vis = 0;
        } elif k == gui_key_backspace() {
            let n = str_len(app.ui.dlg_value);
            if n > 0 { app.ui.dlg_value = str_slice(app.ui.dlg_value, 0, n - 1); }
        }

    } elif app.ui.dlg_vis == 2 {
        if k == gui_key_return() || k == gui_key_f5() {
            app.ui.dlg_vis = 0;   // Confirmed action handled on click
        } elif k == gui_key_escape() {
            app.ui.dlg_vis = 0;
        }

    } elif app.ui.dlg_vis == 3 {
        if k == gui_key_escape() || k == gui_key_return() { app.ui.dlg_vis = 0; }

    } elif app.ui.palette_vis == 1 {
        // ── Palette keys ─────────────────────────────────────────────
        if k == gui_key_escape() { app.ui.palette_vis = 0; }
        elif k == gui_key_return() {
            let action = palette_action(app.ui.palette_q, app.ui.palette_sel);
            app.ui.palette_vis = 0;
            // Execute palette action
            if action == 0 { app.ui.dlg_vis = 1; app.ui.dlg_title = "Open File"; app.ui.dlg_prompt = "File path:"; app.ui.dlg_value = str_concat(app.ed.cwd, ""); app.ui.dlg_action = 0; }
            elif action == 1 { app.ui.dlg_vis = 1; app.ui.dlg_title = "New File"; app.ui.dlg_prompt = "File name:"; app.ui.dlg_value = ""; app.ui.dlg_action = 2; }
            elif action == 2 {
                if str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(app.ed.buf)); app.ed.dirty = 0; }
            }
            elif action == 3 {
                if str_len(app.ed.open_files) > 0 {
                    if app.ed.dirty == 1 && str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(app.ed.buf)); app.ed.dirty = 0; }
                    app.ed.open_files = ed_close_tab(app.ed.open_files, app.ed.active_ed_tab);
                    if ed_tab_count(app.ed.open_files) == 0 { app.ed.buf = buf_empty(); app.ed.active_ed_tab = 0; }
                    else { app.ed.active_ed_tab = int_max(0, app.ed.active_ed_tab - 1); let nf = ed_tab_file(app.ed.open_files, app.ed.active_ed_tab); app.ed.buf = buf_new(fs_read_file(nf)); app.ed.ed_scroll = 0; app.ed.dirty = 0; }
                }
            }
            elif action == 4 { app.ui.dlg_vis = 1; app.ui.dlg_title = "Go to Line"; app.ui.dlg_prompt = "Line number:"; app.ui.dlg_value = ""; app.ui.dlg_action = 1; }
            elif action == 5 { app.ed.find_vis = 1; app.ui.palette_vis = 0; }
            elif action == 6 { app.ed.find_vis = 2; app.ui.palette_vis = 0; }
            elif action == 7 { app.ed.sidebar_vis = if app.ed.sidebar_vis == 0 { 1 } else { 0 }; }
            elif action ==  9 { app.ui.active_tab = TAB_EDITOR(); }
            elif action == 10 { app.ui.active_tab = TAB_EXPLORER(); }
            elif action == 11 { app.ui.active_tab = TAB_BROWSER(); }
            elif action == 12 { // Undo — no-op in palette (use Ctrl+Z in editor)
            }
        }
        elif k == gui_key_up() {
            if app.ui.palette_sel > 0 { app.ui.palette_sel = app.ui.palette_sel - 1; }
        }
        elif k == gui_key_down() {
            let mc = palette_match_count(app.ui.palette_q);
            if app.ui.palette_sel < mc - 1 { app.ui.palette_sel = app.ui.palette_sel + 1; }
        }
        elif k == gui_key_backspace() {
            let n = str_len(app.ui.palette_q);
            if n > 0 { app.ui.palette_q = str_slice(app.ui.palette_q, 0, n - 1); app.ui.palette_sel = 0; }
        }

    } else {

        // ── Global shortcuts (no dialog/palette) ─────────────────────
        if k == gui_key_f1() {
            app.ui.palette_vis = if app.ui.palette_vis == 0 { 1 } else { 0 };
            app.ui.palette_q = ""; app.ui.palette_sel = 0;

        } elif k == gui_key_escape() {
            if app.ed.find_vis > 0 { app.ed.find_vis = 0; }
            elif app.em.em_compose == 1 { app.em.em_compose = 0; }
            elif app.ex.ex_dlg_vis > 0 { app.ex.ex_dlg_vis = 0; }

        } elif k == gui_key_tab() && ctrl == 0 && app.ui.active_tab == TAB_EDITOR() && app.ed.find_vis == 0 {
            // Tab in editor = indent.
            //
            // THE UNDO PUSH IS EXPLICIT HERE AND IT IS NOT REDUNDANT.
            // The general "push a snapshot if the text changed" lives
            // in the `active_tab == TAB_EDITOR()` arm below, and this
            // arm is a SIBLING of it in the same if/elif chain -- only
            // one arm of a chain runs, so an indent never reached it
            // and Ctrl+Z could not undo a Tab. Found 30 August 2026 by
            // the `unused variable `old`` warning, which named the
            // snapshot someone took here and then discarded: the fix
            // had been started and not finished.
            app.ed.undo_stack = undo_push(app.ed.undo_stack, buf_text(app.ed.buf));
            app.ed.redo_stack = "";        // a new edit invalidates the future
            app.ed.buf = buf_insert(app.ed.buf, "    ");
            app.ed.dirty = 1;

        } elif k == gui_key_f3() || (k == gui_key_f() && ctrl == 1) {
            app.ed.find_vis = if app.ed.find_vis > 0 { 0 } else { 1 };
            app.ed.find_q = ""; app.ed.find_focus = 0;

        } elif k == gui_key_h() && ctrl == 1 {
            app.ed.find_vis = if app.ed.find_vis == 2 { 0 } else { 2 };
            app.ed.find_q = ""; app.ed.replace_q = ""; app.ed.find_focus = 0;

        } elif k == gui_key_f4() {
            app.ed.sidebar_vis = if app.ed.sidebar_vis == 0 { 1 } else { 0 };

        } elif k == gui_key_f10() { app.ui.active_tab = TAB_EDITOR();   }
        elif k == gui_key_f11()  { app.ui.active_tab = TAB_EXPLORER(); }
        elif k == gui_key_f12()  { app.ui.active_tab = TAB_BROWSER();  }

        // ── Find bar keys ────────────────────────────────────────────
        elif app.ui.active_tab == TAB_EDITOR() && app.ed.find_vis > 0 {
            if k == gui_key_backspace() {
                if app.ed.find_focus == 0 {
                    let n = str_len(app.ed.find_q);
                    if n > 0 { app.ed.find_q = str_slice(app.ed.find_q, 0, n - 1); }
                } else {
                    let n = str_len(app.ed.replace_q);
                    if n > 0 { app.ed.replace_q = str_slice(app.ed.replace_q, 0, n - 1); }
                }
            } elif k == gui_key_return() {
                if app.ed.find_vis == 1 || app.ed.find_focus == 0 {
                    // Find next
                    let text = buf_text(app.ed.buf);
                    let start = if app.ed.find_result >= 0 { app.ed.find_result + 1 } else { 0 };
                    let res = find_next(text, app.ed.find_q, start);
                    if res >= 0 {
                        app.ed.find_result = res;
                        app.ed.buf = buf_goto_line(app.ed.buf, 0);  // reset, then jump
                        // Place cursor at result offset
                        let full = buf_text(app.ed.buf);
                        app.ed.buf = buf_pack(str_slice(full, 0, res), str_slice(full, res, str_len(full)));
                        let cur_ln2 = buf_line(app.ed.buf);
                        app.ed.ed_scroll = int_max(0, cur_ln2 - 5);
                    }
                } elif app.ed.find_vis == 2 && app.ed.find_focus == 1 {
                    // Replace all.
                    //
                    // Same sibling-arm problem as the Tab indent above
                    // and a worse one to have: this arm rewrites every
                    // match in the file and it was not undoable. The
                    // general snapshot lives in the NEXT arm of this
                    // chain, which a find-bar keystroke never reaches.
                    // Nothing named this one -- it was found by
                    // grepping the SHAPE after the Tab arm, not the
                    // symbol (maniTC report.txt P56).
                    app.ed.undo_stack = undo_push(app.ed.undo_stack, buf_text(app.ed.buf));
                    app.ed.redo_stack = "";
                    app.ed.buf = buf_replace_all(app.ed.buf, app.ed.find_q, app.ed.replace_q); app.ed.dirty = 1;
                }
            } elif k == gui_key_tab() {
                // Toggle focus between find / replace inputs
                if app.ed.find_vis == 2 { app.ed.find_focus = if app.ed.find_focus == 0 { 1 } else { 0 }; }
            }

        // ── Editor keys ──────────────────────────────────────────────
        } elif app.ui.active_tab == TAB_EDITOR() {
            let old_text = buf_text(app.ed.buf);

            // Ctrl shortcuts
            if ctrl == 1 {
                if k == gui_key_s() {
                    if str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(app.ed.buf)); app.ed.dirty = 0; }
                } elif k == gui_key_z() {
                    // Undo: pop the last snapshot from the undo stack,
                    // pushing what is on screen onto the redo stack
                    // FIRST -- otherwise the text being replaced is
                    // gone and Ctrl+Y has nothing to restore.
                    let prev = undo_pop(app.ed.undo_stack);
                    if str_len(prev) > 0 {
                        app.ed.redo_stack = undo_push(app.ed.redo_stack, buf_text(app.ed.buf));
                        app.ed.undo_stack = undo_stack_without_last(app.ed.undo_stack);
                        app.ed.buf = buf_new(str_concat(prev, ""));
                        app.ed.dirty = 1;
                    }
                } elif k == gui_key_y() {
                    // Redo: the mirror image. What comes off the redo
                    // stack goes on screen, and what was on screen goes
                    // back onto the undo stack, so alternating Ctrl+Z
                    // and Ctrl+Y walks the history in both directions.
                    let nxt = undo_pop(app.ed.redo_stack);
                    if str_len(nxt) > 0 {
                        app.ed.undo_stack = undo_push(app.ed.undo_stack, buf_text(app.ed.buf));
                        app.ed.redo_stack = undo_stack_without_last(app.ed.redo_stack);
                        app.ed.buf = buf_new(str_concat(nxt, ""));
                        app.ed.dirty = 1;
                    }
                } elif k == gui_key_c() {
                    // Copy selection
                    let cur_off2 = buf_cursor_offset(app.ed.buf);
                    let slo = if app.ed.sel_anchor < 0 { -1 } elif app.ed.sel_anchor < cur_off2 { app.ed.sel_anchor } else { cur_off2 };
                    let shi = if app.ed.sel_anchor < 0 { -1 } elif app.ed.sel_anchor > cur_off2 { app.ed.sel_anchor } else { cur_off2 };
                    if slo >= 0 && shi > slo { gui_clipboard_set(sel_text(app.ed.buf, slo, shi)); }
                } elif k == gui_key_x() {
                    // Cut selection
                    let cur_off2 = buf_cursor_offset(app.ed.buf);
                    let slo = if app.ed.sel_anchor < 0 { -1 } elif app.ed.sel_anchor < cur_off2 { app.ed.sel_anchor } else { cur_off2 };
                    let shi = if app.ed.sel_anchor < 0 { -1 } elif app.ed.sel_anchor > cur_off2 { app.ed.sel_anchor } else { cur_off2 };
                    if slo >= 0 && shi > slo {
                        gui_clipboard_set(sel_text(app.ed.buf, slo, shi));
                        app.ed.buf = buf_delete_selection(app.ed.buf, slo, shi);
                        app.ed.sel_anchor = -1; app.ed.dirty = 1;
                    }
                } elif k == gui_key_v() {
                    // Paste
                    let clip = gui_clipboard_get();
                    let cur_off2 = buf_cursor_offset(app.ed.buf);
                    let slo = if app.ed.sel_anchor < 0 { -1 } elif app.ed.sel_anchor < cur_off2 { app.ed.sel_anchor } else { cur_off2 };
                    let shi = if app.ed.sel_anchor < 0 { -1 } elif app.ed.sel_anchor > cur_off2 { app.ed.sel_anchor } else { cur_off2 };
                    if slo >= 0 && shi > slo { app.ed.buf = buf_delete_selection(app.ed.buf, slo, shi); app.ed.sel_anchor = -1; }
                    app.ed.buf = buf_insert(app.ed.buf, clip); app.ed.dirty = 1;
                } elif k == gui_key_a() {
                    // Select all
                    let full = buf_text(app.ed.buf);
                    app.ed.sel_anchor = 0;
                    app.ed.buf = buf_pack(full, "");
                } elif k == gui_key_left() {
                    app.ed.buf = buf_word_left(app.ed.buf);
                    if shift == 0 { app.ed.sel_anchor = -1; }
                } elif k == gui_key_right() {
                    app.ed.buf = buf_word_right(app.ed.buf);
                    if shift == 0 { app.ed.sel_anchor = -1; }
                } elif k == gui_key_delete() {
                    app.ed.buf = buf_delete_word_right(app.ed.buf); app.ed.dirty = 1;
                }
            } else {
                // Non-ctrl editor navigation / editing
                if k == gui_key_backspace() {
                    let cur_off2 = buf_cursor_offset(app.ed.buf);
                    let slo = if app.ed.sel_anchor < 0 { -1 } elif app.ed.sel_anchor < cur_off2 { app.ed.sel_anchor } else { cur_off2 };
                    let shi = if app.ed.sel_anchor < 0 { -1 } elif app.ed.sel_anchor > cur_off2 { app.ed.sel_anchor } else { cur_off2 };
                    if slo >= 0 && shi > slo { app.ed.buf = buf_delete_selection(app.ed.buf, slo, shi); app.ed.sel_anchor = -1; }
                    else { app.ed.buf = buf_backspace(app.ed.buf); }
                    app.ed.dirty = 1;
                } elif k == gui_key_delete() {
                    app.ed.buf = buf_delete(app.ed.buf); app.ed.dirty = 1;
                } elif k == gui_key_return() {
                    let cur_off2 = buf_cursor_offset(app.ed.buf);
                    let slo = if app.ed.sel_anchor < 0 { -1 } elif app.ed.sel_anchor < cur_off2 { app.ed.sel_anchor } else { cur_off2 };
                    let shi = if app.ed.sel_anchor < 0 { -1 } elif app.ed.sel_anchor > cur_off2 { app.ed.sel_anchor } else { cur_off2 };
                    if slo >= 0 && shi > slo { app.ed.buf = buf_delete_selection(app.ed.buf, slo, shi); app.ed.sel_anchor = -1; }
                    app.ed.buf = buf_newline_indent(app.ed.buf); app.ed.dirty = 1;
                } elif k == gui_key_up() {
                    if shift == 1 && app.ed.sel_anchor < 0 { app.ed.sel_anchor = buf_cursor_offset(app.ed.buf); }
                    app.ed.buf = buf_up(app.ed.buf);
                    if shift == 0 { app.ed.sel_anchor = -1; }
                } elif k == gui_key_down() {
                    if shift == 1 && app.ed.sel_anchor < 0 { app.ed.sel_anchor = buf_cursor_offset(app.ed.buf); }
                    app.ed.buf = buf_down(app.ed.buf);
                    if shift == 0 { app.ed.sel_anchor = -1; }
                } elif k == gui_key_left() {
                    if shift == 1 && app.ed.sel_anchor < 0 { app.ed.sel_anchor = buf_cursor_offset(app.ed.buf); }
                    app.ed.buf = buf_left(app.ed.buf);
                    if shift == 0 { app.ed.sel_anchor = -1; }
                } elif k == gui_key_right() {
                    if shift == 1 && app.ed.sel_anchor < 0 { app.ed.sel_anchor = buf_cursor_offset(app.ed.buf); }
                    app.ed.buf = buf_right(app.ed.buf);
                    if shift == 0 { app.ed.sel_anchor = -1; }
                } elif k == gui_key_home() {
                    if shift == 1 && app.ed.sel_anchor < 0 { app.ed.sel_anchor = buf_cursor_offset(app.ed.buf); }
                    app.ed.buf = buf_home(app.ed.buf);
                    if shift == 0 { app.ed.sel_anchor = -1; }
                } elif k == gui_key_end() {
                    if shift == 1 && app.ed.sel_anchor < 0 { app.ed.sel_anchor = buf_cursor_offset(app.ed.buf); }
                    app.ed.buf = buf_end(app.ed.buf);
                    if shift == 0 { app.ed.sel_anchor = -1; }
                } elif k == gui_key_pageup() {
                    let vis = (wh - L_TITLEBAR() - L_TABBAR() - L_EDTAB() - L_BREADCRUMB() - L_STATUSBAR()) / L_LINE();
                    app.ed.ed_scroll = int_max(0, app.ed.ed_scroll - vis);
                } elif k == gui_key_pagedown() {
                    let vis = (wh - L_TITLEBAR() - L_TABBAR() - L_EDTAB() - L_BREADCRUMB() - L_STATUSBAR()) / L_LINE();
                    app.ed.ed_scroll = int_min(int_max(0, buf_line_count(app.ed.buf) - vis), app.ed.ed_scroll + vis);
                } elif k == gui_key_f5() {
                    // Save
                    if str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(app.ed.buf)); app.ed.dirty = 0; }
                }
            }

            // Push undo snapshot if text changed
            if buf_text(app.ed.buf) != old_text {
                app.ed.undo_stack = undo_push(app.ed.undo_stack, str_concat(old_text, ""));
                // A NEW EDIT INVALIDATES THE REDO HISTORY. Without
                // this, Ctrl+Z, then a keystroke, then Ctrl+Y restores
                // a future that the keystroke replaced -- the text
                // would jump to a state the user never returned to.
                app.ed.redo_stack = "";
            }

            // Auto-scroll cursor into view
            let cur_ln3 = buf_line(app.ed.buf);
            let vis3    = (wh - L_TITLEBAR() - L_TABBAR() - L_EDTAB() - L_BREADCRUMB() - L_STATUSBAR()) / L_LINE();
            if cur_ln3 < app.ed.ed_scroll { app.ed.ed_scroll = cur_ln3; }
            if cur_ln3 >= app.ed.ed_scroll + vis3 { app.ed.ed_scroll = cur_ln3 - vis3 + 1; }

        // ── Browser keys ─────────────────────────────────────────────
        } elif app.ui.active_tab == TAB_BROWSER() {
            if k == gui_key_return() && app.br.br_addr_focus == 1 {
                if str_len(app.br.br_url) > 0 {
                    if !str::starts_with(app.br.br_url, "http://") && !str::starts_with(app.br.br_url, "https://") {
                        app.br.br_url = str_concat("https://", app.br.br_url);
                    }
                    app.br.br_status = str_concat("Loading: ", app.br.br_url);
                    let raw = net_http_get(app.br.br_url);
                    app.br.br_content = collapse_blanks(strip_html(raw));
                    app.br.br_total   = text_line_count(app.br.br_content);
                    app.br.br_hist    = hist_push(app.br.br_hist, app.br.br_url);
                    app.br.br_hist_pos = 0;
                    app.br.br_status  = str_concat("Loaded ", str::from_int(app.br.br_total));
                    app.br.br_status  = str_concat(app.br.br_status, " lines  —  ");
                    app.br.br_status  = str_concat(app.br.br_status, app.br.br_url);
                    app.br.br_scroll  = 0; app.br.br_addr_focus = 0;
                }
            } elif k == gui_key_backspace() && app.br.br_addr_focus == 1 {
                let n = str_len(app.br.br_url);
                if n > 0 { app.br.br_url = str_slice(app.br.br_url, 0, n - 1); }
            } elif k == gui_key_up() {
                if app.br.br_addr_focus == 0 && app.br.br_scroll > 0 { app.br.br_scroll = app.br.br_scroll - 1; }
            } elif k == gui_key_down() {
                if app.br.br_addr_focus == 0 { app.br.br_scroll = int_min(app.br.br_total - 1, app.br.br_scroll + 1); }
            } elif k == gui_key_pageup() {
                if app.br.br_addr_focus == 0 { app.br.br_scroll = int_max(0, app.br.br_scroll - 20); }
            } elif k == gui_key_pagedown() {
                if app.br.br_addr_focus == 0 { app.br.br_scroll = int_min(app.br.br_total - 1, app.br.br_scroll + 20); }
            } elif k == gui_key_left() && ctrl == 0 {
                // Back
                let back_url = hist_back_url(app.br.br_hist, app.br.br_hist_pos);
                if str_len(back_url) > 0 {
                    app.br.br_hist_pos = app.br.br_hist_pos + 1;
                    app.br.br_url = str_concat(back_url, "");
                    app.br.br_status = str_concat("Loading: ", app.br.br_url);
                    let raw = net_http_get(app.br.br_url);
                    app.br.br_content = collapse_blanks(strip_html(raw));
                    app.br.br_total = text_line_count(app.br.br_content);
                    app.br.br_scroll = 0;
                    app.br.br_status = str_concat("Loaded — ", app.br.br_url);
                }
            }

        // ── Explorer keys ────────────────────────────────────────────
        } elif app.ui.active_tab == TAB_EXPLORER() {
            if app.ex.ex_dlg_vis == 7 {
                if k == gui_key_return() {
                    if str_len(app.ex.ex_dlg_input) > 0 {
                        let base_cwd = if app.ex.ex_pane == 0 { str_concat(app.ex.ex_cwd_l, "") } else { str_concat(app.ex.ex_cwd_r, "") };
                        fs_mkdir(path_join(base_cwd, app.ex.ex_dlg_input));
                    }
                    app.ex.ex_dlg_vis = 0; app.ex.ex_dlg_input = "";
                } elif k == gui_key_escape() { app.ex.ex_dlg_vis = 0; app.ex.ex_dlg_input = ""; }
                elif k == gui_key_backspace() {
                    let n = str_len(app.ex.ex_dlg_input);
                    if n > 0 { app.ex.ex_dlg_input = str_slice(app.ex.ex_dlg_input, 0, n - 1); }
                }
            } elif app.ex.ex_dlg_vis == 8 {
                if k == gui_key_return() {
                    let del_path = ex_selected_path(app.ex.ex_cwd_l, app.ex.ex_cwd_r, app.ex.ex_sel_l, app.ex.ex_sel_r, app.ex.ex_pane);
                    if str_len(del_path) > 0 { fs_delete(del_path); }
                    app.ex.ex_dlg_vis = 0;
                } elif k == gui_key_escape() { app.ex.ex_dlg_vis = 0; }
            } else {
                if app.ex.ex_pane == 0 {
                    if k == gui_key_up()   && app.ex.ex_sel_l > 0 { app.ex.ex_sel_l = app.ex.ex_sel_l - 1; }
                    if k == gui_key_down() { app.ex.ex_sel_l = app.ex.ex_sel_l + 1; }
                    if k == gui_key_return() {
                        let name_l = fs_list_dir_entry(app.ex.ex_sel_l);
                        let full_l = path_join(app.ex.ex_cwd_l, name_l);
                        if fs_is_dir(full_l) == 1 { app.ex.ex_cwd_l = str_concat(full_l, ""); app.ex.ex_sel_l = 0; app.ex.ex_scroll_l = 0; }
                        else {
                            if app.ed.dirty == 1 && str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(app.ed.buf)); app.ed.dirty = 0; }
                            app.ed.open_files = ed_open_tab(app.ed.open_files, str_concat(full_l, ""));
                            app.ed.active_ed_tab = ed_find_tab(app.ed.open_files, str_concat(full_l, ""));
                            app.ed.buf = buf_new(fs_read_file(full_l)); app.ed.ed_scroll = 0; app.ed.dirty = 0;
                            app.ui.active_tab = TAB_EDITOR();
                        }
                    }
                    if k == gui_key_backspace() { app.ex.ex_cwd_l = path_parent(app.ex.ex_cwd_l); app.ex.ex_sel_l = 0; }
                    if k == gui_key_tab() { app.ex.ex_pane = 1; }
                } else {
                    if k == gui_key_up()   && app.ex.ex_sel_r > 0 { app.ex.ex_sel_r = app.ex.ex_sel_r - 1; }
                    if k == gui_key_down() { app.ex.ex_sel_r = app.ex.ex_sel_r + 1; }
                    if k == gui_key_return() {
                        let name_r = fs_list_dir_entry(app.ex.ex_sel_r);
                        let full_r = path_join(app.ex.ex_cwd_r, name_r);
                        if fs_is_dir(full_r) == 1 { app.ex.ex_cwd_r = str_concat(full_r, ""); app.ex.ex_sel_r = 0; app.ex.ex_scroll_r = 0; }
                        else {
                            if app.ed.dirty == 1 && str_len(cur_file) > 0 { fs_write_file(cur_file, buf_text(app.ed.buf)); app.ed.dirty = 0; }
                            app.ed.open_files = ed_open_tab(app.ed.open_files, str_concat(full_r, ""));
                            app.ed.active_ed_tab = ed_find_tab(app.ed.open_files, str_concat(full_r, ""));
                            app.ed.buf = buf_new(fs_read_file(full_r)); app.ed.ed_scroll = 0; app.ed.dirty = 0;
                            app.ui.active_tab = TAB_EDITOR();
                        }
                    }
                    if k == gui_key_backspace() { app.ex.ex_cwd_r = path_parent(app.ex.ex_cwd_r); app.ex.ex_sel_r = 0; }
                    if k == gui_key_tab() { app.ex.ex_pane = 0; }
                }
                // F5/F6/F7/F8
                if k == gui_key_f5() {
                    let src = ex_selected_path(app.ex.ex_cwd_l, app.ex.ex_cwd_r, app.ex.ex_sel_l, app.ex.ex_sel_r, app.ex.ex_pane);
                    let dst_dir = if app.ex.ex_pane == 0 { str_concat(app.ex.ex_cwd_r, "") } else { str_concat(app.ex.ex_cwd_l, "") };
                    if str_len(src) > 0 { fs_copy(str_concat(src, ""), path_join(dst_dir, path_basename(src))); }
                } elif k == gui_key_f6() {
                    let src = ex_selected_path(app.ex.ex_cwd_l, app.ex.ex_cwd_r, app.ex.ex_sel_l, app.ex.ex_sel_r, app.ex.ex_pane);
                    let dst_dir = if app.ex.ex_pane == 0 { str_concat(app.ex.ex_cwd_r, "") } else { str_concat(app.ex.ex_cwd_l, "") };
                    if str_len(src) > 0 { fs_move(str_concat(src, ""), path_join(dst_dir, path_basename(src))); }
                } elif k == gui_key_f7() {
                    app.ex.ex_dlg_vis = 7; app.ex.ex_dlg_input = "";
                } elif k == gui_key_f8() {
                    app.ex.ex_dlg_vis = 8;
                }
            }

        // ── Terminal keys ────────────────────────────────────────────
        } elif app.ui.active_tab == TAB_TERMINAL() {
            if k == gui_key_return() {
                let full_cmd  = str_concat("$ ", str_concat(app.tm.term_cmd, "\n"));
                app.tm.term_output   = str_concat(app.tm.term_output, full_cmd);
                if str_len(app.tm.term_cmd) > 0 {
                    let result = shell_exec(app.tm.term_cmd);
                    app.tm.term_hist     = term_hist_push(app.tm.term_hist, app.tm.term_cmd);
                    app.tm.term_hist_idx = -1;
                    app.tm.term_output   = str_concat(app.tm.term_output, str_concat(result, "\n$ "));
                } else {
                    app.tm.term_output = str_concat(app.tm.term_output, "$ ");
                }
                app.tm.term_cmd    = "";
                app.tm.term_scroll = text_line_count(app.tm.term_output) - 1;
            } elif k == gui_key_backspace() {
                let n = str_len(app.tm.term_cmd);
                if n > 0 { app.tm.term_cmd = str_slice(app.tm.term_cmd, 0, n - 1); }
            } elif k == gui_key_up() {
                // History navigation
                app.tm.term_hist_idx = app.tm.term_hist_idx + 1;
                let hcmd = term_hist_get(app.tm.term_hist, app.tm.term_hist_idx);
                if str_len(hcmd) > 0 { app.tm.term_cmd = str_concat(hcmd, ""); }
                else { app.tm.term_hist_idx = app.tm.term_hist_idx - 1; }
            } elif k == gui_key_down() {
                if app.tm.term_hist_idx > 0 {
                    app.tm.term_hist_idx = app.tm.term_hist_idx - 1;
                    app.tm.term_cmd = term_hist_get(app.tm.term_hist, app.tm.term_hist_idx);
                } elif app.tm.term_hist_idx == 0 {
                    app.tm.term_hist_idx = -1; app.tm.term_cmd = "";
                }
            } elif k == gui_key_pageup() {
                app.tm.term_scroll = int_max(0, app.tm.term_scroll - 10);
            } elif k == gui_key_pagedown() {
                app.tm.term_scroll = int_min(text_line_count(app.tm.term_output) - 1, app.tm.term_scroll + 10);
            } elif k == gui_key_c() && ctrl == 1 {
                // Ctrl+C: interrupt (clear current line, add ^C marker)
                app.tm.term_output = str_concat(app.tm.term_output, "^C\n$ ");
                app.tm.term_cmd = "";
            }

        // ── Email keys ───────────────────────────────────────────────
        } elif app.ui.active_tab == TAB_EMAIL() {
            if app.em.em_compose == 1 {
                if k == gui_key_tab()       { app.em.em_field = (app.em.em_field + 1) % 3; }
                elif k == gui_key_escape()  { app.em.em_compose = 0; }
                elif k == gui_key_backspace() {
                    if app.em.em_field == 0      { let n = str_len(app.em.em_to);   if n > 0 { app.em.em_to   = str_slice(app.em.em_to,   0, n - 1); } }
                    elif app.em.em_field == 1    { let n = str_len(app.em.em_sub);  if n > 0 { app.em.em_sub  = str_slice(app.em.em_sub,  0, n - 1); } }
                    else                  { let n = str_len(app.em.em_body); if n > 0 { app.em.em_body = str_slice(app.em.em_body, 0, n - 1); } }
                }
                elif k == gui_key_return() && app.em.em_field == 2 {
                    app.em.em_body = str_concat(app.em.em_body, "\n");
                }
            } else {
                if k == gui_key_up()   && app.em.em_sel > 0 { app.em.em_sel = app.em.em_sel - 1; app.em.em_show_body = 1; }
                if k == gui_key_down() { app.em.em_sel = app.em.em_sel + 1; app.em.em_show_body = 1; }
                if k == gui_key_return() { app.em.em_show_body = if app.em.em_show_body == 0 { 1 } else { 0 }; }
                if k == gui_key_f2()   { app.em.em_compose = 1; app.em.em_to = ""; app.em.em_sub = ""; app.em.em_body = ""; app.em.em_field = 0; }
            }
        }
    }   // end key handling

    // ── Main tab switch via tab key ──────────────────────────────────
    if k == gui_key_tab() && ctrl == 1 {
        app.ui.active_tab = (app.ui.active_tab + 1) % 5;
    }

}
