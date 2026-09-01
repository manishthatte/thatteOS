// main.mt — studioMani: init, the frame loop, and nothing else
// Author: Manish Jagdish Thatte
// © Manish Jagdish Thatte
//
// THIS FILE WAS 1,028 LINES IN TWO FUNCTIONS (ENHANCEMENT_PLAN §5.6). The
// title bar went to titlebar.mt, the state to state.mt and the five structs
// that were already in the tree, the drawing to frame.mt, and each SDL event
// type to its own events_*.mt. What is left is the loop: derive the frame,
// draw it, wait, dispatch.
//
// THE SPLIT IS PURE CODE MOTION, and the one thing that could quietly have
// changed behaviour is `cur_file`. It is computed ONCE per frame, BEFORE the
// event is read, and every handler that saves or renames uses that snapshot.
// Deriving it inside the handlers instead would re-evaluate it after one had
// already changed `active_ed_tab` or `open_files` — a different program. So
// it is computed here and passed as a `str`.
//
// The dispatch arms are `elif` because SDL delivers one event, exactly as the
// original chain had them, and in the original order.

fn main() {
    gui_init(1280, 800, "studioMani — thatteOS IDE");

    let app = app_init(".");

    while app.ui.running == 1 {
        let ww       = gui_window_width();
        let wh       = gui_window_height();
        let mx       = gui_mouse_x();
        let my       = gui_mouse_y();
        let top_bar  = L_TITLEBAR() + L_TABBAR();
        let bot_bar  = wh - L_STATUSBAR();
        let v        = make_view(top_bar, bot_bar, mx, my);

        // The file this frame is about, snapshotted before any event runs.
        let cur_file = if str_len(app.ed.open_files) > 0 {
            ed_tab_file(app.ed.open_files, app.ed.active_ed_tab)
        } else { "" };

        draw_frame(app, v, ww, wh, cur_file);

        gui_wait_event(16);
        let ev = gui_event_type();

        if ev == 1   { handle_quit(app, cur_file); }
        elif ev == 2 { handle_key(app, wh, cur_file); }
        elif ev == 6 { handle_text(app, wh); }
        elif ev == 4 { handle_mouse(app, v, ww, wh, cur_file); }
        elif ev == 7 { handle_wheel(app); }
    }

    gui_quit();
}
