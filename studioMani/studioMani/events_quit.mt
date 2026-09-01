// events_quit.mt — SDL_QUIT
// Author: Manish Jagdish Thatte
// © Manish Jagdish Thatte
//
// Split out of main.mt on 30 August 2026 (ENHANCEMENT_PLAN §5.6). PURE CODE
// MOTION: the statements below are what main() ran, with every state name
// qualified through `app` and the per-frame locals re-derived from `View` at
// the top. No condition, no ordering and no value was changed.

fn handle_quit(app: App, cur_file: str) {

    // SDL_QUIT — save if dirty then exit
    if app.ed.dirty == 1 && str_len(cur_file) > 0 {
        fs_write_file(cur_file, buf_text(app.ed.buf));
    }
    app.ui.running = 0;

}
