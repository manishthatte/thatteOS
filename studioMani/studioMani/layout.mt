// studioMani/layout.mt — layout constants, shared draw helpers, and path/string utils
// Author: Manish Jagdish Thatte

// ── Layout dimensions ─────────────────────────────────────────────────────────
fn L_TITLEBAR()   -> int { return 35; }
fn L_TABBAR()     -> int { return 35; }
fn L_STATUSBAR()  -> int { return 22; }
fn L_SIDEBAR()    -> int { return 220; }
fn L_LINENR()     -> int { return 52; }
fn L_MINIMAP()    -> int { return 80; }
fn L_BREADCRUMB() -> int { return 26; }
fn L_FINDBAR()    -> int { return 34; }
fn L_LINE()       -> int { return 20; }
fn L_MARGIN()     -> int { return 8; }
fn L_EDTAB()      -> int { return 28; }   // editor open-file tab bar height

// ── Tab indices ───────────────────────────────────────────────────────────────
fn TAB_EDITOR()   -> int { return 0; }
fn TAB_EXPLORER() -> int { return 1; }
fn TAB_BROWSER()  -> int { return 2; }
fn TAB_EMAIL()    -> int { return 3; }
fn TAB_TERMINAL() -> int { return 4; }

// ── Math helpers ──────────────────────────────────────────────────────────────
fn int_max(a: int, b: int) -> int { if a > b { return a; } return b; }
fn int_min(a: int, b: int) -> int { if a < b { return a; } return b; }
fn int_clamp(v: int, lo: int, hi: int) -> int {
    if v < lo { return lo; }
    if v > hi { return hi; }
    return v;
}

// ── String helpers ────────────────────────────────────────────────────────────
fn ch_repeat(ch: str, n: int) -> str {
    let mut out = "";
    let mut i   = 0;
    while i < n { out = str_concat(out, ch); i = i + 1; }
    return out;
}

fn file_ext(name: str) -> str {
    let len = str_len(name);
    let mut i = len - 1;
    while i > 0 {
        if str_slice(name, i, i + 1) == "." { return str_slice(name, i + 1, len); }
        i = i - 1;
    }
    return "";
}

fn path_basename(p: str) -> str {
    let len = str_len(p);
    let mut i = len - 1;
    while i > 0 {
        if str_slice(p, i, i + 1) == "/" { return str_slice(p, i + 1, len); }
        i = i - 1;
    }
    return p;
}

fn path_dirname(p: str) -> str {
    let len = str_len(p);
    let mut i = len - 1;
    while i > 0 {
        if str_slice(p, i, i + 1) == "/" { return str_slice(p, 0, i); }
        i = i - 1;
    }
    return ".";
}

// Count occurrences of needle in haystack
// RENAMED from `str_count` (was: a name collision the compiler does not
// diagnose). `str::count` is ManiT source in maniTC's stdlib and mangles to the
// symbol `@str_count`, so a top-level user function of that name emits a second
// definition of it: `manitc check` says OK, T3ISA assembles and runs, and clang
// refuses the module with "invalid redefinition of function 'str_count'".
// Same family as report.txt P62, from the free-function side.
fn sm_str_count(hay: str, needle: str) -> int {
    let hlen = str_len(hay);
    let nlen = str_len(needle);
    if nlen == 0 { return 0; }
    let mut count = 0;
    let mut i = 0;
    while i <= hlen - nlen {
        if str_slice(hay, i, i + nlen) == needle { count = count + 1; i = i + nlen; }
        else { i = i + 1; }
    }
    return count;
}

fn ft_ext_color(name: str) {
    let ext = file_ext(name);
    if ext == "mt"   { c_ft_mt();   return; }
    if ext == "rs"   { c_ft_rs();   return; }
    if ext == "md"   { c_ft_md();   return; }
    if ext == "sh"   { c_ft_sh();   return; }
    if ext == "toml" { c_ft_rs();   return; }
    if ext == "json" { c_num();     return; }
    if ext == "py"   { c_ft_sh();   return; }
    if ext == "c"    { c_ft_rs();   return; }
    if ext == "h"    { c_ft_rs();   return; }
    c_ft_other();
}

// ── Plain-text line helpers ───────────────────────────────────────────────
// Get the nth line (0-indexed) from a '\n'-delimited plain text string.
fn text_get_line(text: str, n: int) -> str {
    let len = str_len(text);
    let mut cur = 0;
    let mut i   = 0;
    let mut out = "";
    while i < len {
        let ch = str_slice(text, i, i + 1);
        if ch == "\n" {
            if cur == n { return out; }
            cur = cur + 1;
            out = "";
        } else {
            if cur == n { out = str_concat(out, ch); }
        }
        i = i + 1;
    }
    if cur == n { return out; }
    return "";
}

// Count lines in a '\n'-delimited plain text string (0 if empty).
fn text_line_count(text: str) -> int {
    let len = str_len(text);
    if len == 0 { return 0; }
    let mut n = 1;
    let mut i = 0;
    while i < len {
        if str_slice(text, i, i + 1) == "\n" { n = n + 1; }
        i = i + 1;
    }
    return n;
}

// ── Hit-test ──────────────────────────────────────────────────────────────────
fn in_rect(mx: int, my: int, bx: int, by: int, bw: int, bh: int) -> int {
    if mx < bx       { return 0; }
    if my < by       { return 0; }
    if mx >= bx + bw { return 0; }
    if my >= by + bh { return 0; }
    return 1;
}

// ── Button widget ─────────────────────────────────────────────────────────────
fn draw_btn(label: str, bx: int, by: int, bw: int, bh: int, mx: int, my: int) -> int {
    let hot = in_rect(mx, my, bx, by, bw, bh);
    if hot == 1 { gui_set_color(70, 70, 70, 255); } else { gui_set_color(55, 55, 55, 255); }
    gui_fill_rect(bx, by, bw, bh);
    c_border();
    gui_draw_rect(bx, by, bw, bh);
    c_white();
    let tw = gui_text_width(label);
    let fh = gui_font_height();
    gui_draw_text(label, bx + (bw - tw) / 2, by + (bh - fh) / 2);
    return bx + bw + 4;
}

fn draw_btn_accent(label: str, bx: int, by: int, bw: int, bh: int, mx: int, my: int) -> int {
    let hot = in_rect(mx, my, bx, by, bw, bh);
    if hot == 1 { gui_set_color(50, 160, 230, 255); } else { c_accent(); }
    gui_fill_rect(bx, by, bw, bh);
    gui_set_color(255, 255, 255, 255);
    let tw = gui_text_width(label);
    let fh = gui_font_height();
    gui_draw_text(label, bx + (bw - tw) / 2, by + (bh - fh) / 2);
    return bx + bw + 4;
}

// ── Scrollbar widget ──────────────────────────────────────────────────────────
fn draw_scrollbar(x: int, y: int, h: int, total: int, visible: int, scroll: int) {
    if total <= visible { return; }
    c_border();
    gui_fill_rect(x, y, 10, h);
    let thumb_h = if total > 0 { int_max(16, h * visible / total) } else { h };
    let thumb_y = if total > 0 { y + (h - thumb_h) * scroll / int_max(1, total - visible) } else { y };
    gui_set_color(100, 100, 100, 255);
    gui_fill_rect(x + 1, thumb_y, 8, thumb_h);
}

// ── Status bar ────────────────────────────────────────────────────────────────
fn draw_statusbar(open_file: str, ln: int, col: int, mode: str, dirty: int) {
    let ww = gui_window_width();
    let wh = gui_window_height();
    let fh = gui_font_height();
    let y  = wh - L_STATUSBAR();

    c_statusbar();
    gui_fill_rect(0, y, ww, L_STATUSBAR());
    c_statusbar_txt();

    let mode_w = gui_text_width(mode) + 16;
    gui_set_color(7, 54, 66, 255);
    gui_fill_rect(0, y, mode_w, L_STATUSBAR());
    c_statusbar_txt();
    gui_draw_text(mode, 8, y + (L_STATUSBAR() - fh) / 2);

    let base = path_basename(open_file);
    let fname = if str_len(open_file) > 0 {
        if dirty == 1 { str_concat("● ", base) } else { base }
    } else {
        if dirty == 1 { "● untitled" } else { "untitled" }
    };
    gui_draw_text(fname, mode_w + 12, y + (L_STATUSBAR() - fh) / 2);

    let pos_s = str_concat("Ln ", str_concat(str::from_int(ln + 1),
                str_concat(", Col ", str::from_int(col + 1))));
    let pw = gui_text_width(pos_s);
    gui_draw_text(pos_s, ww - pw - 60, y + (L_STATUSBAR() - fh) / 2);
    gui_draw_text("UTF-8", ww - 52, y + (L_STATUSBAR() - fh) / 2);
}
