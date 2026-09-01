// state.mt — the parts of the IDE's state nothing had grouped, and the App
// Author: Manish Jagdish Thatte
// © Manish Jagdish Thatte
//
// `main()` held 62 mutable locals and every tab's mouse and keyboard logic
// inline: 1,028 lines in two functions (ENHANCEMENT_PLAN §5.6). ManiT has no
// closures, so extracting a handler means PASSING the state it touches, and
// the T3 convention passes arguments in R1-R8 — a handler cannot take 62
// things, nor even six groups plus a viewport.
//
// TWO MEASURED LANGUAGE FACTS MAKE THIS SHAPE WORK, neither of them obvious:
//   * a struct PARAMETER is a mutable reference, so a handler taking `App`
//     writes straight through to main's state — nothing is returned;
//   * and that propagates through NESTED fields, so `app.ed.buf = x` inside a
//     callee is visible to `main`. Verified on BOTH backends BEFORE the design
//     was settled on it, rather than inferred from the first fact.
// So every handler takes ONE `App` and the parameter budget stops binding.
//
// A SCALAR CANNOT BE THREADED THIS WAY, and that is the whole reason for the
// structs: `fn f(n: int) { n = 1; }` does not write back, so any state left as
// a bare `int`/`str` parameter would silently lose its mutation. Every mutable
// value therefore lives in a struct field, and forgetting one is a COMPILE
// ERROR (`unknown identifier`) rather than a wrong answer — which is what
// makes a 900-line code motion reviewable.
//
// FIVE OF THE SIX GROUPS WERE ALREADY IN THE TREE AND NOTHING HAD EVER USED
// THEM: EditorState (editor.mt), ExplorerState (explorer.mt), BrowserState
// (browser.mt), EmailState (email.mt), TerminalState (terminal.mt) — the
// grouping was designed, given constructors and abandoned, and editor.mt's own
// TODO said it was waiting on a compiler feature that already existed. They
// are used now, with their field names and initial values unchanged. Only
// UiState below is new: the chrome that belongs to no tab.

struct UiState {
    pub palette_vis:  int,
    pub palette_q:    str,
    pub palette_sel:  int,
    pub dlg_vis:      int,   // 0=none 1=input 2=confirm 3=msg
    pub dlg_title:    str,
    pub dlg_prompt:   str,
    pub dlg_value:    str,
    pub dlg_action:   int,   // 1=goto_line 2=new_file 3=rename 7=mkdir
    pub active_tab:   int,
    pub running:      int,
}

fn ui_state_init() -> UiState {
    return UiState {
        palette_vis: 0, palette_q: "", palette_sel: 0,
        dlg_vis: 0, dlg_title: "", dlg_prompt: "", dlg_value: "", dlg_action: 0,
        active_tab: TAB_EDITOR(), running: 1,
    };
}

// The whole of it: six groups, one parameter.
struct App {
    pub ed: EditorState,
    pub ex: ExplorerState,
    pub br: BrowserState,
    pub em: EmailState,
    pub tm: TerminalState,
    pub ui: UiState,
}

fn app_init(cwd: str) -> App {
    // `cwd` reaches two constructors, and that is legal precisely because
    // PASSING a value to a function does not move it in this language — only
    // assignment, a tuple element and a struct-literal field do (report.txt
    // P51). explorer_state_init makes its own second copy for the same reason.
    return App {
        ed: editor_state_init(cwd),
        ex: explorer_state_init(cwd),
        br: browser_state_init(),
        em: email_state_init(),
        tm: terminal_state_init(),
        ui: ui_state_init(),
    };
}
