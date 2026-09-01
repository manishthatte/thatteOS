// studioMani/studioMani/editor.mt — editor viewport, open-file tab bar, breadcrumb
// Full editor rendering with selection highlight, find+replace bar, minimap.
// Depends on: theme.mt, layout.mt, buffer.mt, highlight.mt
// Author: Manish Jagdish Thatte

// ── Open-file tab list helpers ────────────────────────────────────────────────
// open_files is a "\n"-delimited list of open file paths (max 8).

fn ed_tab_count(open_files: str) -> int {
    if str_len(open_files) == 0 { return 0; }
    return text_line_count(open_files);
}

fn ed_tab_file(open_files: str, idx: int) -> str {
    return text_get_line(open_files, idx);
}

// Returns the tab index of `path`, or -1 if not open.
fn ed_find_tab(open_files: str, path: str) -> int {
    let n = ed_tab_count(open_files);
    let mut i = 0;
    while i < n {
        if ed_tab_file(open_files, i) == path { return i; }
        i = i + 1;
    }
    return -1;
}

// Add path to open_files (if not already present, max 8 tabs). Returns new string.
fn ed_open_tab(open_files: str, path: str) -> str {
    if ed_find_tab(open_files, path) >= 0 { return open_files; }
    let n = ed_tab_count(open_files);
    if n >= 8 { return open_files; }     // max 8 tabs
    if str_len(open_files) == 0 { return path; }
    return str_concat(open_files, str_concat("\n", path));
}

// Remove the tab at idx. Returns new open_files string.
fn ed_close_tab(open_files: str, idx: int) -> str {
    let n = ed_tab_count(open_files);
    if n == 0 { return ""; }
    let mut out = "";
    let mut i   = 0;
    while i < n {
        if i != idx {
            let f = ed_tab_file(open_files, i);
            if str_len(out) == 0 { out = str_concat(f, ""); }
            else { out = str_concat(out, str_concat("\n", f)); }
        }
        i = i + 1;
    }
    return out;
}

// ── Open-file tab bar ─────────────────────────────────────────────────────────
// Draws the per-editor tab bar (below the main tab bar) when EDITOR is active.
// Returns the index of the tab whose close [x] was hovered (-1 if none).
fn draw_editor_file_tabs(open_files: str, active_idx: int, dirty: int,
                         top_y: int, mx: int, my: int) -> int {
    let ww     = gui_window_width();
    let fh     = gui_font_height();
    let tab_h  = L_EDTAB();
    let tab_w  = 160;
    let n      = ed_tab_count(open_files);

    c_tabbar();
    gui_fill_rect(0, top_y, ww, tab_h);
    c_border();
    gui_draw_line(0, top_y + tab_h, ww, top_y + tab_h);

    let mut close_hovered = -1;
    let mut tx = 0;
    let mut i  = 0;
    while i < n {
        let fname = path_basename(ed_tab_file(open_files, i));
        let label = if i == active_idx && dirty == 1 { str_concat("● ", fname) } else { fname };
        let is_active = if i == active_idx { 1 } else { 0 };
        let hot       = in_rect(mx, my, tx, top_y, tab_w, tab_h);

        if is_active == 1 {
            c_tab_active();
            gui_fill_rect(tx, top_y, tab_w, tab_h);
            c_tab_border();
            gui_draw_line(tx, top_y + tab_h - 2, tx + tab_w, top_y + tab_h - 2);
            c_white();
        } elif hot == 1 {
            c_tab_hover();
            gui_fill_rect(tx, top_y, tab_w, tab_h);
            c_dim();
        } else {
            c_tab_inactive();
            gui_fill_rect(tx, top_y, tab_w, tab_h);
            c_dim();
        }

        // Label (clipped to tab width minus close button area)
        let lw   = gui_text_width(label);
        let lx   = tx + (tab_w - lw - 18) / 2;
        gui_draw_text(label, lx, top_y + (tab_h - fh) / 2);

        // Close button [×]
        let cx2  = tx + tab_w - 18;
        let cy2  = top_y + (tab_h - fh) / 2;
        let x_hot = in_rect(mx, my, cx2 - 2, top_y + 4, 16, tab_h - 8);
        if x_hot == 1 {
            c_error();
            close_hovered = i;
        } else {
            c_dim();
        }
        gui_draw_text("×", cx2, cy2);

        // Separator
        c_border();
        gui_draw_line(tx + tab_w, top_y, tx + tab_w, top_y + tab_h);
        tx = tx + tab_w;
        i  = i + 1;
    }

    // "New tab" button after last tab
    let new_hot = in_rect(mx, my, tx, top_y, 28, tab_h);
    if new_hot == 1 { c_tab_hover(); } else { c_dim(); }
    gui_draw_text("+", tx + 8, top_y + (tab_h - fh) / 2);

    return close_hovered;
}

// ── Breadcrumb ────────────────────────────────────────────────────────────────
fn draw_breadcrumb(open_file: str, dirty: int, top_y: int) {
    let ww = gui_window_width();
    let fh = gui_font_height();
    let bx = if 1 == 1 { L_SIDEBAR() } else { 0 };   // sidebar always present in editor tab

    c_breadcrumb();
    gui_fill_rect(bx, top_y, ww - bx, L_BREADCRUMB());
    c_border();
    gui_draw_line(bx, top_y + L_BREADCRUMB(), ww, top_y + L_BREADCRUMB());

    if str_len(open_file) == 0 {
        c_dim();
        gui_draw_text("no file open", bx + L_MARGIN(), top_y + (L_BREADCRUMB() - fh) / 2);
        return;
    }

    let dir  = path_dirname(open_file);
    let base = path_basename(open_file);
    let dname = path_basename(dir);
    let mut cx2 = bx + L_MARGIN();
    c_dim();
    gui_draw_text(dname, cx2, top_y + (L_BREADCRUMB() - fh) / 2);
    cx2 = cx2 + gui_text_width(dname) + 4;
    gui_draw_text(">", cx2, top_y + (L_BREADCRUMB() - fh) / 2);
    cx2 = cx2 + 14;
    if dirty == 1 { c_warning(); } else { c_white(); }
    gui_draw_text(base, cx2, top_y + (L_BREADCRUMB() - fh) / 2);
}

// ── Editor viewport ───────────────────────────────────────────────────────────
// sel_anchor: -1 = no selection. When >= 0, selection is [min(sel_anchor, cur_off), max(sel_anchor, cur_off)).
// find_vis: 0=hidden, 1=find only, 2=find+replace
fn draw_editor(buf: str, ed_scroll: int,
               sel_anchor: int,
               find_q: str, find_vis: int, replace_q: str,
               top_y: int, bot_y: int) {
    let ww      = gui_window_width();
    let fh      = gui_font_height();
    let ed_x    = L_SIDEBAR() + L_LINENR();
    let ed_w    = ww - L_SIDEBAR() - L_LINENR() - L_MINIMAP() - 12;
    let ln_x    = L_SIDEBAR();
    let mm_x    = ww - L_MINIMAP() - 10;
    let cur_ln  = buf_line(buf);
    let cur_col = buf_col(buf);
    let cur_off = buf_cursor_offset(buf);

    // Selection extents
    let sel_lo = if sel_anchor < 0 { -1 } elif sel_anchor < cur_off { sel_anchor } else { cur_off };
    let sel_hi = if sel_anchor < 0 { -1 } elif sel_anchor > cur_off { sel_anchor } else { cur_off };

    // Backgrounds
    c_editor();
    gui_fill_rect(L_SIDEBAR(), top_y, ww - L_SIDEBAR(), bot_y - top_y);
    gui_set_color(240, 234, 216, 255);
    gui_fill_rect(ln_x, top_y, L_LINENR(), bot_y - top_y);
    c_minimap();
    gui_fill_rect(mm_x, top_y, L_MINIMAP() + 10, bot_y - top_y);

    let total_lines = buf_line_count(buf);

    // Find/replace bars at bottom of editor area
    let find_bar_h    = if find_vis == 2 { L_FINDBAR() * 2 + 4 } else { L_FINDBAR() };
    let find_top      = bot_y - find_bar_h - 4;
    let draw_bot      = if find_vis > 0 { find_top } else { bot_y };
    let vis           = (draw_bot - top_y) / L_LINE();

    if find_vis > 0 {
        c_findbar();
        gui_fill_rect(L_SIDEBAR(), find_top, ww - L_SIDEBAR() - L_MINIMAP() - 10, find_bar_h);
        c_border();
        gui_draw_line(L_SIDEBAR(), find_top, ww - L_MINIMAP() - 10, find_top);

        // Find row
        let qx = L_SIDEBAR() + 56;
        let qw = 260;
        c_dim();
        gui_draw_text("Find:", L_SIDEBAR() + 8, find_top + (L_FINDBAR() - fh) / 2);
        gui_set_color(253, 246, 227, 255);
        gui_fill_rect(qx, find_top + 4, qw, L_FINDBAR() - 8);
        c_accent();
        gui_draw_rect(qx, find_top + 4, qw, L_FINDBAR() - 8);
        c_white();
        gui_draw_text(find_q, qx + 6, find_top + (L_FINDBAR() - fh) / 2);
        let fcw = gui_text_width(find_q);
        c_cursor();
        gui_draw_line(qx + 6 + fcw, find_top + 6, qx + 6 + fcw, find_top + L_FINDBAR() - 6);

        // Replace row (if find_vis == 2)
        if find_vis == 2 {
            let rrow_y = find_top + L_FINDBAR() + 2;
            let rx2    = L_SIDEBAR() + 56;
            c_dim();
            gui_draw_text("Replace:", L_SIDEBAR() + 8, rrow_y + (L_FINDBAR() - fh) / 2);
            gui_set_color(253, 246, 227, 255);
            gui_fill_rect(rx2, rrow_y + 4, qw, L_FINDBAR() - 8);
            c_border();
            gui_draw_rect(rx2, rrow_y + 4, qw, L_FINDBAR() - 8);
            c_white();
            gui_draw_text(replace_q, rx2 + 6, rrow_y + (L_FINDBAR() - fh) / 2);
        }
    }

    // Visible lines
    let mut row = 0;
    while row < vis {
        let ln = ed_scroll + row;
        if ln >= total_lines { row = vis; } else {
        let ry   = top_y + row * L_LINE();
        let line = buf_get_line(buf, ln);

        // Compute line start offset in buf_text
        let text     = buf_text(buf);
        let tlen     = str_len(text);
        let mut loff = 0;
        let mut lcur = 0;
        let mut li   = 0;
        while li < tlen && lcur < ln {
            if str_slice(text, li, li + 1) == "\n" { lcur = lcur + 1; loff = li + 1; }
            li = li + 1;
        }
        if ln > 0 { loff = loff; }   // loff is correct

        // Cursor line highlight
        if ln == cur_ln {
            c_cursorline();
            gui_fill_rect(L_SIDEBAR() + L_LINENR(), ry, ed_w, L_LINE());
        }

        // Selection background
        if sel_lo >= 0 && sel_hi > sel_lo {
            hl_draw_sel_bg(line, ed_x, ry, loff, sel_lo, sel_hi);
        }

        // Line number
        if ln == cur_ln { c_linenr_cur(); } else { c_linenr(); }
        let ln_s = str::from_int(ln + 1);
        let ln_w = gui_text_width(ln_s);
        gui_draw_text(ln_s, ln_x + L_LINENR() - ln_w - 6, ry + (L_LINE() - fh) / 2);

        // Syntax-highlighted text
        hl_draw_line(line, ed_x, ry + (L_LINE() - fh) / 2);

        // Cursor
        if ln == cur_ln {
            let cur_text = str_slice(line, 0, cur_col);
            let cx3 = ed_x + gui_text_width(cur_text);
            c_cursor();
            gui_draw_line(cx3, ry + 2, cx3, ry + L_LINE() - 2);
        }

        // Minimap density dot
        let ll = str_len(line);
        if ll > 0 {
            let mm_y  = top_y + (bot_y - top_y) * ln / int_max(total_lines, 1);
            let depth = int_min(ll / 4, L_MINIMAP() - 4);
            gui_set_color(80, 100, 120, 200);
            gui_fill_rect(mm_x + 2, mm_y, depth, 1);
        }

        row = row + 1;
        }
    }

    // Minimap viewport indicator
    if total_lines > 0 {
        let vp_y = top_y + (bot_y - top_y) * ed_scroll / total_lines;
        let vp_h = int_max(8, (bot_y - top_y) * vis / total_lines);
        gui_set_color(38, 139, 210, 60);
        gui_fill_rect(mm_x + 1, vp_y, L_MINIMAP() - 2, vp_h);
    }

    // Scrollbar
    draw_scrollbar(mm_x - 12, top_y, draw_bot - top_y, total_lines, vis, ed_scroll);
}

// ── EditorState ───────────────────────────────────────────────────────────────
// All mutable state owned by the Editor tab, and the sidebar beside it.
//
// THE TODO THAT USED TO SIT HERE SAID THE REFACTOR WAS BLOCKED, AND IT WAS
// NOT. It read: "when struct update syntax (#8) is added, main.mt event loop
// can be refactored to pass/return EditorState and move handler logic into
// this file." Struct update syntax exists (`T { ..p, f: v }`) -- and the
// refactor never needed it, because a struct PARAMETER is a mutable reference
// in this language: a handler taking `EditorState` writes straight through to
// the caller's copy, with nothing to return and nothing to update. The event
// loop was split on 30 August 2026 (ENHANCEMENT_PLAN §5.6) and this struct is
// what it passes. Another "still blocked" that was a claim with a date on it.
//
// `buf` WAS DECLARED `Buffer`, A TYPE THIS REPOSITORY HAS NEVER DEFINED, and
// `manitc check` accepted it -- an undeclared type name resolves to `Unknown`,
// which is compatible with everything, so the field silently held the `str`
// that `buf_empty()` returns. maniTC report.txt P95. It is `str` now, which is
// what a gap buffer is here: text, a separator, more text.
struct EditorState {
    pub open_files:    str,
    pub active_ed_tab: int,
    pub buf:           str,
    pub ed_scroll:     int,
    pub dirty:         int,
    pub sel_anchor:    int,
    pub find_vis:      int,
    pub find_focus:    int,
    pub find_q:        str,
    pub replace_q:     str,
    pub find_result:   int,
    pub undo_stack:    str,
    pub redo_stack:    str,   // added with Ctrl+Y, §5.2
    pub sidebar_vis:   int,
    pub cwd:           str,
    pub ft_sel:        int,
    pub ft_scroll:     int,
    pub git_out:       str,
    pub ctx_row:       int,
    pub ctx_x:         int,
    pub ctx_y:         int,
}

fn editor_state_init(cwd: str) -> EditorState {
    return EditorState {
        open_files: "", active_ed_tab: 0,
        buf: buf_empty(), ed_scroll: 0,
        dirty: 0, sel_anchor: -1,
        find_vis: 0, find_focus: 0,
        find_q: "", replace_q: "", find_result: -1,
        undo_stack: "", redo_stack: "", sidebar_vis: 1,
        cwd: cwd, ft_sel: 0, ft_scroll: 0,
        git_out: "", ctx_row: -1, ctx_x: 0, ctx_y: 0,
    };
}
