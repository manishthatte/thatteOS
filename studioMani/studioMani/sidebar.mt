// studioMani/studioMani/sidebar.mt — file-tree sidebar
// Shows workspace dir, entries with git-status badges, right-click context menu.
// Depends on: theme.mt, layout.mt, dialogs.mt (draw_context_menu)
// Author: Manish Jagdish Thatte

// Parse git status output (from `git status --short`) for a given filename.
// Returns "M" modified, "A" added, "D" deleted, "?" untracked, " " clean/unknown.
fn sidebar_git_char(git_out: str, filename: str) -> str {
    if str_len(git_out) == 0 { return " "; }
    let pos = find_first(git_out, filename);
    if pos < 3 { return " "; }
    // git --short format: "XY path\n"  — X and Y are at pos-3 and pos-2
    let c1 = str_slice(git_out, pos - 3, pos - 2);
    let c2 = str_slice(git_out, pos - 2, pos - 1);
    if c1 == "?" { return "?"; }
    if c1 == "D" || c2 == "D" { return "D"; }
    if c1 == "A" || c2 == "A" { return "A"; }
    if c1 == "M" || c2 == "M" { return "M"; }
    return " ";
}

// Draw one git badge at (bx, by): colored dot + status char.
fn draw_git_badge(ch: str, bx: int, by: int) {
    if ch == "M" { c_git_m(); }
    elif ch == "A" { c_git_a(); }
    elif ch == "D" { c_git_d(); }
    elif ch == "?" { c_git_u(); }
    else { return; }
    gui_draw_text(ch, bx, by);
}

// Draw the sidebar file tree.
// ctx_row: -1 = no context menu visible. If >= 0, draw context menu at (ctx_x, ctx_y).
// Returns the row index the cursor is hovering over (for hit testing in event loop).
fn draw_sidebar(cwd: str, open_file: str, ft_sel: int, ft_scroll: int,
                git_out: str, ctx: CtxMenu, v: View) {
    let fh   = gui_font_height();
    let sw   = L_SIDEBAR();
    let row_h = 22;

    // Background
    c_sidebar();
    gui_fill_rect(0, v.top_y, sw, v.bot_y - v.top_y);

    // Header
    c_titlebar();
    gui_fill_rect(0, v.top_y, sw, 24);
    c_dim();
    gui_draw_text("EXPLORER", L_MARGIN(), v.top_y + (24 - fh) / 2);

    // Workspace label (cwd basename) with mini git dirty indicator
    let workspace = path_basename(cwd);
    c_white();
    gui_draw_text(workspace, L_MARGIN(), v.top_y + 28);
    // Show git dirty marker
    let is_dirty_ws = if str_len(git_out) > 0 { 1 } else { 0 };
    if is_dirty_ws == 1 {
        c_git_m();
        gui_draw_text("*", L_MARGIN() + gui_text_width(workspace) + 4, v.top_y + 28);
    }

    // ".." parent dir entry
    let parent_y = v.top_y + 52;
    let par_hot  = in_rect(v.mx, v.my, 0, parent_y, sw, row_h);
    if par_hot == 1 { c_hover(); gui_fill_rect(0, parent_y, sw, row_h); }
    c_dim();
    gui_draw_text("↑ ..", L_MARGIN() + 8, parent_y + (row_h - fh) / 2);

    // File list
    let list_top = parent_y + row_h + 2;
    let visible  = (v.bot_y - list_top) / row_h;
    let count    = fs_list_dir_open(cwd);

    let mut i = 0;
    while i < visible {
        let idx  = ft_scroll + i;
        if idx >= count { i = visible; } else {
        let name  = fs_list_dir_entry(idx);
        let full  = path_join(cwd, name);
        let is_d  = fs_is_dir(full);
        let row_y = list_top + i * row_h;
        let is_sel = if ft_sel == idx { 1 } else { 0 };
        let is_hot = in_rect(v.mx, v.my, 0, row_y, sw, row_h);
        let is_open = if full == open_file { 1 } else { 0 };

        if is_sel == 1 || is_open == 1 {
            c_selection();
            gui_fill_rect(0, row_y, sw, row_h);
        } elif is_hot == 1 {
            c_hover();
            gui_fill_rect(0, row_y, sw, row_h);
        }

        // Icon + name
        if is_d == 1 {
            c_ft_dir();
            gui_draw_text(str_concat("▸ ", name), L_MARGIN() + 8, row_y + (row_h - fh) / 2);
        } else {
            ft_ext_color(name);
            gui_draw_text(str_concat("  ", name), L_MARGIN() + 8, row_y + (row_h - fh) / 2);
        }

        // Git badge (right side)
        let gc = sidebar_git_char(git_out, name);
        if gc != " " {
            draw_git_badge(gc, sw - 16, row_y + (row_h - fh) / 2);
        }

        i = i + 1;
        }
    }

    // Scrollbar
    draw_scrollbar(sw - 11, list_top, v.bot_y - list_top, count + 1, visible, ft_scroll);

    // Right border
    c_border();
    gui_draw_line(sw, v.top_y, sw, v.bot_y);

    // Context menu (if visible)
    let ctx_items = "New File\nNew Folder\nRename\nDelete\nCopy Path";
    if ctx.row >= 0 {
        draw_context_menu(ctx.x, ctx.y, ctx_items, 5, v.mx, v.my);
    }
}

// Hit-test: returns row index (0-based) of list entry at cy, accounting for
// the ".." row (idx -1) and entry rows. Returns -2 if outside sidebar.
fn sidebar_hit_row(cy: int, ft_scroll: int, top_y: int) -> int {
    let parent_y = top_y + 52;
    let list_top = parent_y + 22 + 2;
    let row_h    = 22;
    if in_rect(0, cy, 0, parent_y, L_SIDEBAR(), 22) == 1 { return -1; }  // ".." row
    if cy < list_top { return -2; }
    return ft_scroll + (cy - list_top) / row_h;
}
