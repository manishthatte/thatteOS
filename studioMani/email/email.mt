// email/email.mt — studioMani standalone email client
// IMAP/SMTP client UI for thatteOS.
// net_imap_* functions are planned for the ManiT stdlib (see TODO below).
// Until then, the inbox is seeded with demo data to exercise the full UI.
//
// Keys:
//   ↑↓       navigate mail list
//   Enter    open selected mail
//   C        compose new message
//   R        reply
//   D        delete
//   Tab      switch folder
//   Esc/q    quit
//
// TODO (requires net_imap_* stdlib additions to manitc):
//   net_imap_connect(host, port, user, pass) -> int  (handle)
//   net_imap_list(handle, folder) -> str             (newline-sep mail headers)
//   net_imap_fetch(handle, uid) -> str               (full mail body)
//   net_smtp_send(host, port, user, pass, to, sub, body) -> int
//
// Author: Manish Jagdish Thatte

use std::io;

// ── Colors — Solarized Light ──────────────────────────────────────────────────

fn c_bg()      -> int { return gui_set_color(253, 246, 227, 255); }   // base3
fn c_panel()   -> int { return gui_set_color(238, 232, 213, 255); }   // base2
fn c_sel()     -> int { return gui_set_color(196, 223, 245, 255); }   // blue tint
fn c_hover()   -> int { return gui_set_color(245, 239, 220, 255); }   // base3 tinted
fn c_border()  -> int { return gui_set_color(147, 161, 161, 255); }   // base1
fn c_accent()  -> int { return gui_set_color(38,  139, 210, 255); }   // blue
fn c_status()  -> int { return gui_set_color(38,  139, 210, 255); }   // blue
fn c_white()   -> int { return gui_set_color(7,   54,  66,  255); }   // base02
fn c_text()    -> int { return gui_set_color(101, 123, 131, 255); }   // base00
fn c_dim()     -> int { return gui_set_color(147, 161, 161, 255); }   // base1
fn c_unread()  -> int { return gui_set_color(38,  139, 210, 255); }   // blue
fn c_read()    -> int { return gui_set_color(147, 161, 161, 255); }   // base1
fn c_tag_imp() -> int { return gui_set_color(220,  50,  47, 255); }   // red

fn STATUS_H() -> int { return 22; }
fn FOLDER_W() -> int { return 170; }
fn HEADER_H() -> int { return 30; }
fn ROW_H()    -> int { return 38; }
fn MARGIN()   -> int { return 10; }

// ── Helpers ───────────────────────────────────────────────────────────────────

fn in_rect(mx: int, my: int, bx: int, by: int, bw: int, bh: int) -> int {
    if mx < bx || my < by || mx >= bx + bw || my >= by + bh { return 0; }
    return 1;
}

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

// ── Main ──────────────────────────────────────────────────────────────────────

fn main() {
    gui_init(1100, 750, "studioMani email");

    let folders       = ["INBOX", "SENT", "DRAFTS", "ARCHIVE", "TRASH"];
    let folder_counts = [5,        2,       1,         3,         1];

    // Demo inbox data (replace with net_imap_list when available)
    let from_s    = ["Manish Thatte",       "IPOS Delhi",
                     "GitHub Actions",      "arXiv Submissions",
                     "GitLab CI"];
    let subject_s = ["studioMani roadmap",  "Application 202641011111 - Receipt",
                     "Build passed: main",  "New submission: 2408.12345",
                     "Pipeline #42 passed"];
    let date_s    = ["Today 09:14",         "Yesterday 16:02",
                     "2 Aug 11:33",         "1 Aug 08:50",
                     "31 Jul 23:12"];
    let unread    = [1, 0, 1, 1, 0];
    let total_mails = 5;

    let mut active_folder = 0;
    let mut sel_mail      = 0;
    let mail_scroll       = 0;   // never scrolled: no IMAP backend yet
    let mut view_mode     = 0;   // 0=list  1=read  2=compose
    let mut compose_to    = "";
    let mut compose_sub   = "";
    let mut compose_body  = "";
    let mut compose_field = 0;
    let status_msg        = "studioMani email — IMAP client";  // never updated: no IMAP backend yet
    let mut running       = 1;

    while running == 1 {
        let ww  = gui_window_width();
        let wh  = gui_window_height();
        let mx  = gui_mouse_x();
        let my  = gui_mouse_y();
        let fh  = gui_font_height();

        // ── Draw ──────────────────────────────────────────────────────────────
        c_bg();
        gui_fill_rect(0, 0, ww, wh);

        // Title
        c_panel();
        gui_fill_rect(0, 0, ww, HEADER_H());
        c_accent();
        gui_draw_text_lg("studioMani mail", MARGIN(), 4);
        c_border();
        gui_draw_line(0, HEADER_H(), ww, HEADER_H());

        // Status bar
        let sb_y = wh - STATUS_H();
        c_status();
        gui_fill_rect(0, sb_y, ww, STATUS_H());
        c_white();
        gui_draw_text(status_msg, MARGIN(), sb_y + (STATUS_H() - fh) / 2);

        let content_top = HEADER_H() + 2;
        let content_bot = sb_y - 2;

        if view_mode == 2 {
            // ── Compose ───────────────────────────────────────────────────────
            let pw = ww - 80; let ph = content_bot - content_top - 20;
            let px = 40;      let py = content_top + 10;

            c_panel();
            gui_fill_rect(px, py, pw, ph);
            c_accent();
            gui_draw_rect(px, py, pw, ph);
            c_white();
            gui_draw_text_lg("New Message", px + MARGIN(), py + 8);
            c_border();
            gui_draw_line(px, py + 32, px + pw, py + 32);

            let field_x = px + 70;
            let field_w = pw - 90;
            // maniTC B7 D-3, 2 September 2026: an array literal now CONSUMES a
            // plain variable element, like a tuple or struct literal always
            // has. `[compose_to, compose_sub]` built a container of two
            // aliases inside the redraw loop, and `compose_to` is mutated
            // later in the same loop (key handling, below) — so the table was
            // correct only because nothing read it after the mutation.
            // Selecting the field directly removes the container rather than
            // working around the rule. `labels` is untouched: its elements are
            // string LITERALS, and D-3 bites only on a plain variable.
            let labels  = ["To:", "Subject:"];
            let mut fi  = 0;
            while fi < 2 {
                let fy  = py + 38 + fi * 30;
                let cur = if fi == 0 { compose_to } else { compose_sub };
                c_dim();
                gui_draw_text(labels[fi], px + MARGIN(), fy + (22 - fh) / 2);
                if compose_field == fi { c_accent(); } else { c_border(); }
                gui_fill_rect(field_x, fy, field_w, 22);
                gui_draw_rect(field_x, fy, field_w, 22);
                c_white();
                gui_draw_text(cur, field_x + 4, fy + (22 - fh) / 2);
                if compose_field == fi {
                    let cw = gui_text_width(cur);
                    c_accent();
                    gui_draw_line(field_x + 4 + cw, fy + 2, field_x + 4 + cw, fy + 20);
                }
                fi = fi + 1;
            }

            c_border();
            gui_draw_line(px, py + 100, px + pw, py + 100);
            if compose_field == 2 { c_accent(); } else { c_dim(); }
            c_text();
            gui_draw_text(compose_body, field_x, py + 108);
            if compose_field == 2 {
                let cw = gui_text_width(compose_body);
                c_accent();
                gui_draw_line(field_x + cw, py + 106, field_x + cw, py + 126);
            }

            let mut bx = px + pw - 180;
            bx = draw_btn("[Send]",   bx, py + ph - 36, 70, 28, mx, my);
            draw_btn("[Discard]", bx, py + ph - 36, 86, 28, mx, my);

        } elif view_mode == 1 {
            // ── Mail reader ───────────────────────────────────────────────────
            let msg_x = FOLDER_W() + 8;
            let msg_w = ww - FOLDER_W() - 16;

            // Left: folder panel still shown
            c_panel();
            gui_fill_rect(0, content_top, FOLDER_W(), content_bot - content_top);

            // Mail header bar
            gui_set_color(44, 44, 44, 255);
            gui_fill_rect(msg_x, content_top, msg_w, 60);
            c_white();
            gui_draw_text(subject_s[sel_mail], msg_x + 8, content_top + 8);
            c_dim();
            let from_line = str_concat("From: ", str_concat(from_s[sel_mail],
                           str_concat("     ", date_s[sel_mail])));
            gui_draw_text(from_line, msg_x + 8, content_top + 30);
            c_border();
            gui_draw_line(msg_x, content_top + 60, msg_x + msg_w, content_top + 60);

            // Message body (placeholder — fetch via net_imap_fetch when available)
            let body_y = content_top + 68;
            c_text();
            gui_draw_text("(Message body — IMAP fetch pending net_imap_fetch stdlib support)", msg_x + 8, body_y);
            gui_draw_text("When the ManiT stdlib gains net_imap_connect and net_imap_fetch,", msg_x + 8, body_y + 24);
            gui_draw_text("this pane will display the full message content.", msg_x + 8, body_y + 48);

            // Toolbar
            let tool_y = content_bot - 36;
            c_panel();
            gui_fill_rect(msg_x, tool_y, msg_w, 36);
            c_border();
            gui_draw_line(msg_x, tool_y, msg_x + msg_w, tool_y);
            let mut bx = msg_x + 8;
            bx = draw_btn("[Reply]",   bx, tool_y + 4, 68, 26, mx, my);
            bx = draw_btn("[Forward]", bx, tool_y + 4, 80, 26, mx, my);
            bx = draw_btn("[Delete]",  bx, tool_y + 4, 72, 26, mx, my);
            draw_btn("[Archive]", bx, tool_y + 4, 78, 26, mx, my);

        } else {
            // ── Mail list ─────────────────────────────────────────────────────

            // Folder panel
            c_panel();
            gui_fill_rect(0, content_top, FOLDER_W(), content_bot - content_top);
            c_border();
            gui_draw_line(FOLDER_W(), content_top, FOLDER_W(), content_bot);

            c_dim();
            gui_draw_text("FOLDERS", MARGIN(), content_top + 8);

            let mut fi = 0;
            while fi < 5 {
                let fy  = content_top + 30 + fi * 30;
                let hot = in_rect(mx, my, 0, fy, FOLDER_W(), 30);
                let sel = if active_folder == fi { 1 } else { 0 };
                if sel == 1 { c_sel(); gui_fill_rect(0, fy, FOLDER_W(), 30); }
                elif hot == 1 { c_hover(); gui_fill_rect(0, fy, FOLDER_W(), 30); }
                if sel == 1 { c_white(); } else { c_dim(); }
                gui_draw_text(folders[fi], MARGIN(), fy + (30 - fh) / 2);
                c_dim();
                let cnt_s = str::from_int(folder_counts[fi]);
                let cnt_w = gui_text_width(cnt_s);
                gui_draw_text(cnt_s, FOLDER_W() - cnt_w - MARGIN(), fy + (30 - fh) / 2);
                fi = fi + 1;
            }

            // Compose button
            c_accent();
            let comp_y = content_top + 30 + 5 * 30 + 10;
            gui_fill_rect(MARGIN(), comp_y, FOLDER_W() - MARGIN() * 2, 32);
            c_white();
            let cl = "+ Compose";
            let cw = gui_text_width(cl);
            gui_draw_text(cl, (FOLDER_W() - cw) / 2, comp_y + (32 - fh) / 2);

            // Mail list
            let ml_x = FOLDER_W();
            let ml_w = ww - FOLDER_W();

            // Column headers
            gui_set_color(44, 44, 44, 255);
            gui_fill_rect(ml_x, content_top, ml_w, 28);
            c_border();
            gui_draw_line(ml_x, content_top + 28, ml_x + ml_w, content_top + 28);
            c_dim();
            gui_draw_text("FROM",    ml_x + 8,        content_top + (28 - fh) / 2);
            gui_draw_text("SUBJECT", ml_x + 230,      content_top + (28 - fh) / 2);
            gui_draw_text("DATE",    ml_x + ml_w - 130, content_top + (28 - fh) / 2);

            let list_top = content_top + 28;
            let vis      = (content_bot - list_top) / ROW_H();
            let mut mi   = 0;
            while mi < vis {
                let idx  = mail_scroll + mi;
                if idx >= total_mails { mi = vis; } else {
                let ry   = list_top + mi * ROW_H();
                let hot  = in_rect(mx, my, ml_x, ry, ml_w, ROW_H());
                let issel = if sel_mail == idx { 1 } else { 0 };
                if issel == 1 { c_sel();   gui_fill_rect(ml_x, ry, ml_w, ROW_H()); }
                elif hot == 1 { c_hover(); gui_fill_rect(ml_x, ry, ml_w, ROW_H()); }

                if unread[idx] == 1 {
                    c_unread();
                    gui_fill_rect(ml_x + 2, ry + ROW_H() / 2 - 4, 6, 6);
                    c_white();
                } else { c_read(); }

                gui_draw_text(from_s[idx],    ml_x + 14,        ry + (ROW_H() - fh) / 2);
                if unread[idx] == 1 { c_white(); } else { c_dim(); }
                gui_draw_text(subject_s[idx], ml_x + 230,       ry + (ROW_H() - fh) / 2);
                c_dim();
                gui_draw_text(date_s[idx],    ml_x + ml_w - 130, ry + (ROW_H() - fh) / 2);
                c_border();
                gui_draw_line(ml_x, ry + ROW_H(), ml_x + ml_w, ry + ROW_H());
                mi = mi + 1;
                }
            }
        }

        gui_present();

        // ── Events ────────────────────────────────────────────────────────────
        gui_wait_event(16);
        let ev = gui_event_type();

        if ev == 1 { running = 0; }
        elif ev == 2 {
            let k = gui_event_key();
            if k == gui_key_escape() || k == 113 {
                if view_mode > 0 { view_mode = 0; } else { running = 0; }
            } elif k == gui_key_up() {
                if view_mode == 0 && sel_mail > 0 { sel_mail = sel_mail - 1; }
            } elif k == gui_key_down() {
                if view_mode == 0 && sel_mail < total_mails - 1 { sel_mail = sel_mail + 1; }
            } elif k == gui_key_return() {
                if view_mode == 0 { view_mode = 1; }
            } elif k == gui_key_tab() {
                if view_mode == 2 {
                    compose_field = (compose_field + 1) % 3;
                } else {
                    active_folder = (active_folder + 1) % 5;
                }
            } elif k == gui_key_backspace() {
                if view_mode == 2 {
                    if compose_field == 0 { let n = str_len(compose_to);   if n > 0 { compose_to   = str_slice(compose_to,   0, n - 1); } }
                    elif compose_field == 1 { let n = str_len(compose_sub); if n > 0 { compose_sub  = str_slice(compose_sub,  0, n - 1); } }
                    else { let n = str_len(compose_body); if n > 0 { compose_body = str_slice(compose_body, 0, n - 1); } }
                }
            } elif k == 99 {   // 'c' = compose
                view_mode     = 2;
                compose_to    = "";
                compose_sub   = "";
                compose_body  = "";
                compose_field = 0;
            } elif k == 114 {  // 'r' = reply
                if view_mode == 1 {
                    view_mode     = 2;
                    compose_to    = from_s[sel_mail];
                    compose_sub   = str_concat("Re: ", subject_s[sel_mail]);
                    compose_body  = "";
                    compose_field = 2;
                }
            }
        } elif ev == 6 {
            if view_mode == 2 {
                let ch = gui_event_text_str();
                if compose_field == 0 { compose_to   = str_concat(compose_to,   ch); }
                elif compose_field == 1 { compose_sub = str_concat(compose_sub,  ch); }
                else { compose_body = str_concat(compose_body, ch); }
            }
        } elif ev == 4 {
            let cx = gui_mouse_x();
            let cy = gui_mouse_y();
            let content_top2 = HEADER_H() + 2;
            let comp_y2 = content_top2 + 30 + 5 * 30 + 10;
            if in_rect(cx, cy, MARGIN(), comp_y2, FOLDER_W() - MARGIN() * 2, 32) == 1 {
                view_mode = 2; compose_to = ""; compose_sub = ""; compose_body = ""; compose_field = 0;
            }
            let mut fi = 0;
            while fi < 5 {
                let fy = content_top2 + 30 + fi * 30;
                if in_rect(cx, cy, 0, fy, FOLDER_W(), 30) == 1 { active_folder = fi; view_mode = 0; }
                fi = fi + 1;
            }
        }
    }

    gui_quit();
}
