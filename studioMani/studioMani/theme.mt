// studioMani/theme.mt — Solarized Light color theme
// All functions return 0 (side effect: sets SDL2 draw color).
// Author: Manish Jagdish Thatte

// ── Base palette ──────────────────────────────────────────────────────────────
fn c_bg()            -> int { return gui_set_color(253, 246, 227, 255); }  // base3
fn c_sidebar()       -> int { return gui_set_color(238, 232, 213, 255); }  // base2
fn c_titlebar()      -> int { return gui_set_color(238, 232, 213, 255); }  // base2
fn c_tabbar()        -> int { return gui_set_color(238, 232, 213, 255); }  // base2
fn c_tab_active()    -> int { return gui_set_color(253, 246, 227, 255); }  // base3
fn c_tab_inactive()  -> int { return gui_set_color(225, 220, 203, 255); }  // base2 darker
fn c_tab_hover()     -> int { return gui_set_color(245, 239, 220, 255); }  // base3 tinted
fn c_tab_border()    -> int { return gui_set_color(38,  139, 210, 255); }  // blue
fn c_statusbar()     -> int { return gui_set_color(38,  139, 210, 255); }  // blue
fn c_statusbar_txt() -> int { return gui_set_color(255, 255, 255, 255); }  // white
fn c_editor()        -> int { return gui_set_color(253, 246, 227, 255); }  // base3
fn c_cursorline()    -> int { return gui_set_color(245, 239, 220, 255); }  // base3 tinted
fn c_selection()     -> int { return gui_set_color(196, 223, 245, 255); }  // blue tint
fn c_linenr()        -> int { return gui_set_color(147, 161, 161, 255); }  // base1
fn c_linenr_cur()    -> int { return gui_set_color(88,  110, 117, 255); }  // base01
fn c_cursor()        -> int { return gui_set_color(7,   54,  66,  255); }  // base02
fn c_border()        -> int { return gui_set_color(147, 161, 161, 255); }  // base1
fn c_text()          -> int { return gui_set_color(101, 123, 131, 255); }  // base00
fn c_dim()           -> int { return gui_set_color(147, 161, 161, 255); }  // base1
fn c_white()         -> int { return gui_set_color(7,   54,  66,  255); }  // base02 (dark on light)
fn c_accent()        -> int { return gui_set_color(38,  139, 210, 255); }  // blue
fn c_hover()         -> int { return gui_set_color(238, 232, 213, 255); }  // base2
fn c_minimap()       -> int { return gui_set_color(238, 232, 213, 255); }  // base2
fn c_findbar()       -> int { return gui_set_color(238, 232, 213, 255); }  // base2
fn c_breadcrumb()    -> int { return gui_set_color(238, 232, 213, 255); }  // base2
fn c_error()         -> int { return gui_set_color(220, 50,  47,  255); }  // red
fn c_warning()       -> int { return gui_set_color(181, 137,  0,  255); }  // yellow
fn c_success()       -> int { return gui_set_color(133, 153,  0,  255); }  // green

// ── Syntax highlight ──────────────────────────────────────────────────────────
fn c_kw()   -> int { return gui_set_color(38,  139, 210, 255); }  // blue    keywords
fn c_fn_()  -> int { return gui_set_color(181, 137,   0, 255); }  // yellow  function names
fn c_ty()   -> int { return gui_set_color(42,  161, 152, 255); }  // cyan    types
fn c_str_() -> int { return gui_set_color(203,  75,  22, 255); }  // orange  string literals
fn c_num()  -> int { return gui_set_color(133, 153,   0, 255); }  // green   numbers
fn c_cmt()  -> int { return gui_set_color(147, 161, 161, 255); }  // base1   comments
fn c_trit() -> int { return gui_set_color(211,  54, 130, 255); }  // magenta trit/ternary
fn c_op()   -> int { return gui_set_color(101, 123, 131, 255); }  // base00  operators

// ── File tree ─────────────────────────────────────────────────────────────────
fn c_ft_dir()   -> int { return gui_set_color(181, 137,   0, 255); }  // yellow
fn c_ft_mt()    -> int { return gui_set_color(42,  161, 152, 255); }  // cyan
fn c_ft_rs()    -> int { return gui_set_color(203,  75,  22, 255); }  // orange
fn c_ft_md()    -> int { return gui_set_color(38,  139, 210, 255); }  // blue
fn c_ft_sh()    -> int { return gui_set_color(133, 153,   0, 255); }  // green
fn c_ft_other() -> int { return gui_set_color(101, 123, 131, 255); }  // base00

// ── Git status badge colors ────────────────────────────────────────────────────
fn c_git_m()  -> int { return gui_set_color(181, 137,   0, 255); }  // yellow  modified
fn c_git_a()  -> int { return gui_set_color(133, 153,   0, 255); }  // green   added
fn c_git_d()  -> int { return gui_set_color(220,  50,  47, 255); }  // red     deleted
fn c_git_u()  -> int { return gui_set_color(108, 113, 196, 255); }  // violet  untracked
