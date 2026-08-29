// studioMani/studioMani/email.mt — email client UI
// Folder panel, mail list, mail body view, compose dialog.
// IMAP/SMTP integration pending net_imap_* stdlib additions.
// Depends on: theme.mt, layout.mt
// Author: Manish Jagdish Thatte

// Sample data placeholders (replaced by real IMAP data once stdlib supports it)
fn em_sample_from(idx: int) -> str {
    if idx == 0 { return "Manish Thatte"; }
    if idx == 1 { return "IPOS"; }
    if idx == 2 { return "GitHub CI"; }
    if idx == 3 { return "arXiv"; }
    if idx == 4 { return "GitLab"; }
    return "";
}
fn em_sample_subject(idx: int) -> str {
    if idx == 0 { return "studioMani feature plans"; }
    if idx == 1 { return "Filing confirmation — Thatte7"; }
    if idx == 2 { return "Build passed: studioMani"; }
    if idx == 3 { return "New preprint: balanced ternary CNT"; }
    if idx == 4 { return "Pipeline OK — simulations branch"; }
    return "";
}
fn em_sample_date(idx: int) -> str {
    if idx == 0 { return "Today 09:14"; }
    if idx == 1 { return "Yesterday"; }
    if idx == 2 { return "2 Aug"; }
    if idx == 3 { return "1 Aug"; }
    if idx == 4 { return "31 Jul"; }
    return "";
}
fn em_sample_unread(idx: int) -> int {
    if idx == 0 { return 1; }
    if idx == 2 { return 1; }
    if idx == 3 { return 1; }
    return 0;
}
fn em_sample_body(idx: int) -> str {
    if idx == 0 { return "Hi Manish,\n\nHere are the planned features for studioMani:\n\n- Multi-file tabs\n- Syntax highlight\n- Find+replace\n- Terminal integration\n- Git badges\n\nBest,\nManish"; }
    if idx == 1 { return "Dear Applicant,\n\nYour application for Thatte7 has been received.\nApplication number will be assigned within 3 working days.\n\nRegards,\nIPOS"; }
    if idx == 2 { return "Build #42 passed.\n\nBranch: main\nCommit: b02e6ac8\nDuration: 2m 14s\n\n-- GitHub CI"; }
    return "No preview available.";
}

fn draw_email(folder: str, sel_mail: int, mail_scroll: int,
              show_body: int,
              compose_mode: int, compose_to: str, compose_sub: str,
              compose_body: str, compose_field: int,
              top_y: int, bot_y: int, mx: int, my: int) {
    let ww = gui_window_width();
    let fh = gui_font_height();

    c_editor();
    gui_fill_rect(0, top_y, ww, bot_y - top_y);

    // ── Compose overlay ────────────────────────────────────────────────────
    if compose_mode == 1 {
        let cw3  = ww - 80;
        let ch3  = bot_y - top_y - 40;
        let cx3  = 40;
        let cy3  = top_y + 20;

        gui_set_color(245, 238, 220, 255);
        gui_fill_rect(cx3, cy3, cw3, ch3);
        c_accent();
        gui_draw_rect(cx3, cy3, cw3, ch3);

        c_accent();
        gui_fill_rect(cx3, cy3, cw3, 28);
        c_statusbar_txt();
        gui_draw_text("New Message", cx3 + 10, cy3 + (28 - fh) / 2);
        c_border();
        gui_draw_line(cx3, cy3 + 28, cx3 + cw3, cy3 + 28);

        let fld_x = cx3 + 70;
        let fld_w = cw3 - 80;

        // To:
        c_dim();
        gui_draw_text("To:", cx3 + 10, cy3 + 38);
        let to_foc = if compose_field == 0 { 1 } else { 0 };
        if to_foc == 1 { c_accent(); } else { c_border(); }
        gui_set_color(253, 246, 227, 255);
        gui_fill_rect(fld_x, cy3 + 34, fld_w, 24);
        if to_foc == 1 { c_accent(); } else { c_border(); }
        gui_draw_rect(fld_x, cy3 + 34, fld_w, 24);
        c_white();
        gui_draw_text(compose_to, fld_x + 5, cy3 + 34 + (24 - fh) / 2);
        if to_foc == 1 { let tcw = gui_text_width(compose_to); c_cursor(); gui_draw_line(fld_x + 5 + tcw, cy3 + 37, fld_x + 5 + tcw, cy3 + 55); }

        // Subject:
        c_dim();
        gui_draw_text("Subject:", cx3 + 10, cy3 + 70);
        let sub_foc = if compose_field == 1 { 1 } else { 0 };
        gui_set_color(253, 246, 227, 255);
        gui_fill_rect(fld_x, cy3 + 66, fld_w, 24);
        if sub_foc == 1 { c_accent(); } else { c_border(); }
        gui_draw_rect(fld_x, cy3 + 66, fld_w, 24);
        c_white();
        gui_draw_text(compose_sub, fld_x + 5, cy3 + 66 + (24 - fh) / 2);
        if sub_foc == 1 { let scw = gui_text_width(compose_sub); c_cursor(); gui_draw_line(fld_x + 5 + scw, cy3 + 69, fld_x + 5 + scw, cy3 + 87); }

        // Body
        c_border();
        gui_draw_line(cx3, cy3 + 98, cx3 + cw3, cy3 + 98);
        let body_foc = if compose_field == 2 { 1 } else { 0 };
        let body_y   = cy3 + 104;
        c_text();
        // Render body lines
        let blines = text_line_count(compose_body);
        let bvis   = int_min(blines, (ch3 - 108) / L_LINE());
        let mut bi = 0;
        while bi < bvis {
            let bline = text_get_line(compose_body, bi);
            gui_draw_text(bline, fld_x, body_y + bi * L_LINE());
            bi = bi + 1;
        }
        if body_foc == 1 {
            let last_line = if blines > 0 { text_get_line(compose_body, blines - 1) } else { "" };
            let bx3 = fld_x + gui_text_width(last_line);
            let by3 = body_y + int_max(0, blines - 1) * L_LINE();
            c_cursor();
            gui_draw_line(bx3, by3, bx3, by3 + fh);
        }

        // Send / Cancel buttons
        let ok3  = draw_btn_accent("Send",   cx3 + cw3 - 162, cy3 + ch3 - 36, 70, 28, mx, my);
        draw_btn("Cancel", ok3, cy3 + ch3 - 36, 82, 28, mx, my);
        return;
    }

    // ── Folder panel (left 160px) ──────────────────────────────────────────
    let fp_w = 160;
    gui_set_color(238, 232, 213, 255);
    gui_fill_rect(0, top_y, fp_w, bot_y - top_y);
    c_border();
    gui_draw_line(fp_w, top_y, fp_w, bot_y);
    c_dim();
    gui_draw_text("FOLDERS", L_MARGIN(), top_y + 8);

    let folders = ["INBOX", "SENT", "DRAFTS", "ARCHIVE", "TRASH"];
    let mut fi  = 0;
    while fi < 5 {
        let fy  = top_y + 32 + fi * 28;
        let hot = in_rect(mx, my, 0, fy, fp_w, 28);
        let sel = if folders[fi] == folder { 1 } else { 0 };
        if sel == 1 { c_selection(); gui_fill_rect(0, fy, fp_w, 28); c_white(); }
        elif hot == 1 { c_hover(); gui_fill_rect(0, fy, fp_w, 28); c_dim(); }
        else { c_dim(); }
        gui_draw_text(folders[fi], L_MARGIN(), fy + (28 - fh) / 2);
        fi = fi + 1;
    }

    // Compose button
    c_accent();
    gui_fill_rect(L_MARGIN(), top_y + 32 + 5 * 28 + 10, fp_w - L_MARGIN() * 2, 30);
    c_statusbar_txt();
    let cbtw = gui_text_width("+ Compose");
    gui_draw_text("+ Compose", (fp_w - cbtw) / 2, top_y + 32 + 5 * 28 + 10 + (30 - fh) / 2);

    // ── Mail list + body split ──────────────────────────────────────────────
    let ml_x   = fp_w;
    let body_w = if show_body == 1 { ww / 2 } else { 0 };
    let ml_w   = ww - fp_w - body_w;

    // Column headers
    gui_set_color(238, 232, 213, 255);
    gui_fill_rect(ml_x, top_y, ml_w, 28);
    c_border();
    gui_draw_line(ml_x, top_y + 28, ml_x + ml_w, top_y + 28);
    c_dim();
    gui_draw_text("FROM",    ml_x + 8,         top_y + (28 - fh) / 2);
    gui_draw_text("SUBJECT", ml_x + 210,       top_y + (28 - fh) / 2);
    gui_draw_text("DATE",    ml_x + ml_w - 110, top_y + (28 - fh) / 2);

    let row_h = 36;
    let vis   = (bot_y - top_y - 28) / row_h;
    let total = 5;
    let mut mi = 0;
    while mi < vis {
        let idx   = mail_scroll + mi;
        if idx >= total { mi = vis; } else {
        let ry    = top_y + 28 + mi * row_h;
        let hot   = in_rect(mx, my, ml_x, ry, ml_w, row_h);
        let issel = if sel_mail == idx { 1 } else { 0 };

        if issel == 1 { c_selection(); gui_fill_rect(ml_x, ry, ml_w, row_h); }
        elif hot == 1 { c_hover();     gui_fill_rect(ml_x, ry, ml_w, row_h); }

        // Unread dot
        if em_sample_unread(idx) == 1 {
            c_accent();
            gui_fill_rect(ml_x + 2, ry + row_h / 2 - 3, 6, 6);
        }

        if em_sample_unread(idx) == 1 { c_white(); } else { c_dim(); }
        gui_draw_text(em_sample_from(idx),    ml_x + 12,        ry + (row_h - fh) / 2);
        gui_draw_text(em_sample_subject(idx), ml_x + 210,       ry + (row_h - fh) / 2);
        gui_draw_text(em_sample_date(idx),    ml_x + ml_w - 110, ry + (row_h - fh) / 2);

        c_border();
        gui_draw_line(ml_x, ry + row_h, ml_x + ml_w, ry + row_h);
        mi = mi + 1;
        }
    }

    // ── Body panel (right half when show_body == 1) ────────────────────────
    if show_body == 1 {
        let bpx = ml_x + ml_w;
        gui_set_color(253, 246, 227, 255);
        gui_fill_rect(bpx, top_y, body_w, bot_y - top_y);
        c_border();
        gui_draw_line(bpx, top_y, bpx, bot_y);

        // Body header
        gui_set_color(238, 232, 213, 255);
        gui_fill_rect(bpx, top_y, body_w, 48);
        c_border();
        gui_draw_line(bpx, top_y + 48, bpx + body_w, top_y + 48);
        c_white();
        gui_draw_text(em_sample_subject(sel_mail), bpx + 10, top_y + 8);
        c_dim();
        let from_line = str_concat("From: ", em_sample_from(sel_mail));
        gui_draw_text(from_line, bpx + 10, top_y + 28);

        // Body text
        let body_txt  = em_sample_body(sel_mail);
        let body_lines = text_line_count(body_txt);
        let bvis       = (bot_y - top_y - 52) / L_LINE();
        c_text();
        let mut bli = 0;
        while bli < bvis {
            if bli < body_lines {
                gui_draw_text(text_get_line(body_txt, bli),
                              bpx + 10, top_y + 52 + bli * L_LINE());
            }
            bli = bli + 1;
        }
    }
}

// ── EmailState ────────────────────────────────────────────────────────────────
struct EmailState {
    pub em_folder:    str,
    pub em_sel:       int,
    pub em_scroll:    int,
    pub em_show_body: int,
    pub em_compose:   int,
    pub em_to:        str,
    pub em_sub:       str,
    pub em_body:      str,
    pub em_field:     int,  // 0=To 1=Subject 2=Body
}

fn email_state_init() -> EmailState {
    return EmailState {
        em_folder: "INBOX", em_sel: 0, em_scroll: 0,
        em_show_body: 0, em_compose: 0,
        em_to: "", em_sub: "", em_body: "", em_field: 0,
    };
}
