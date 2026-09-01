// events_text.mt — SDL_TEXTINPUT
// Author: Manish Jagdish Thatte
// © Manish Jagdish Thatte
//
// Split out of main.mt on 30 August 2026 (ENHANCEMENT_PLAN §5.6). PURE CODE
// MOTION: the statements below are what main() ran, with every state name
// qualified through `app` and the per-frame locals re-derived from `View` at
// the top. No condition, no ordering and no value was changed.

fn handle_text(app: App, wh: int) {

    // SDL_TEXTINPUT — typed character
    let ch = gui_event_text_str();

    if app.ui.dlg_vis == 1 {
        app.ui.dlg_value = str_concat(app.ui.dlg_value, ch);
    } elif app.ui.dlg_vis == 0 && app.ex.ex_dlg_vis == 7 {
        app.ex.ex_dlg_input = str_concat(app.ex.ex_dlg_input, ch);
    } elif app.ui.palette_vis == 1 {
        app.ui.palette_q = str_concat(app.ui.palette_q, ch); app.ui.palette_sel = 0;
    } elif app.ui.active_tab == TAB_EDITOR() && app.ed.find_vis > 0 {
        if app.ed.find_vis == 2 && app.ed.find_focus == 1 {
            app.ed.replace_q = str_concat(app.ed.replace_q, ch);
        } else {
            app.ed.find_q = str_concat(app.ed.find_q, ch);
        }
    } elif app.ui.active_tab == TAB_EDITOR() {
        app.ed.buf = buf_insert(app.ed.buf, ch); app.ed.dirty = 1;
        let cur_ln4 = buf_line(app.ed.buf);
        let vis4    = (wh - L_TITLEBAR() - L_TABBAR() - L_EDTAB() - L_BREADCRUMB() - L_STATUSBAR()) / L_LINE();
        if cur_ln4 >= app.ed.ed_scroll + vis4 { app.ed.ed_scroll = cur_ln4 - vis4 + 1; }
        app.ed.sel_anchor = -1;
    } elif app.ui.active_tab == TAB_BROWSER() && app.br.br_addr_focus == 1 {
        app.br.br_url = str_concat(app.br.br_url, ch);
    } elif app.ui.active_tab == TAB_TERMINAL() {
        app.tm.term_cmd = str_concat(app.tm.term_cmd, ch);
    } elif app.ui.active_tab == TAB_EMAIL() && app.em.em_compose == 1 {
        if app.em.em_field == 0      { app.em.em_to   = str_concat(app.em.em_to,   ch); }
        elif app.em.em_field == 1    { app.em.em_sub  = str_concat(app.em.em_sub,  ch); }
        else                  { app.em.em_body = str_concat(app.em.em_body, ch); }
    }

}
