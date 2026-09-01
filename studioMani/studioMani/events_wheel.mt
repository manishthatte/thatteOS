// events_wheel.mt — SDL_MOUSEWHEEL
// Author: Manish Jagdish Thatte
// © Manish Jagdish Thatte
//
// Split out of main.mt on 30 August 2026 (ENHANCEMENT_PLAN §5.6). PURE CODE
// MOTION: the statements below are what main() ran, with every state name
// qualified through `app` and the per-frame locals re-derived from `View` at
// the top. No condition, no ordering and no value was changed.

fn handle_wheel(app: App) {

    // SDL_MOUSEWHEEL
    let wy = gui_wheel_dy();
    if app.ui.active_tab == TAB_EDITOR() {
        if wy > 0 { app.ed.ed_scroll = int_max(0, app.ed.ed_scroll - 3); }
        else { app.ed.ed_scroll = int_min(int_max(0, buf_line_count(app.ed.buf) - 1), app.ed.ed_scroll + 3); }
    } elif app.ui.active_tab == TAB_BROWSER() {
        if wy > 0 { app.br.br_scroll = int_max(0, app.br.br_scroll - 3); }
        else { app.br.br_scroll = int_min(int_max(0, app.br.br_total - 1), app.br.br_scroll + 3); }
    } elif app.ui.active_tab == TAB_TERMINAL() {
        if wy > 0 { app.tm.term_scroll = int_max(0, app.tm.term_scroll - 3); }
        else { app.tm.term_scroll = int_min(text_line_count(app.tm.term_output) - 1, app.tm.term_scroll + 3); }
    } elif app.ui.active_tab == TAB_EMAIL() && app.em.em_show_body == 1 {
        // scroll body (not implemented per-mail yet)
    }
}
