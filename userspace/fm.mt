// userspace/fm.mt — THATTEOS File Manager
//
// Full-screen terminal file manager.
// Uses ANSI escape codes for rendering; raw-mode keyboard for navigation.
//
// Keys:
//   ↑ / ↓       move selection
//   Enter        open directory / run binary
//   Backspace    go to parent directory
//   r            run selected file as a process
//   d            delete selected file
//   c            copy selected file (prompts for destination)
//   m            move / rename selected file (prompts for destination)
//   q            quit
//
// Author: Manish Jagdish Thatte

use std::io;

fn KEY_UP()   -> int { return 1000; }
fn KEY_DOWN() -> int { return 1001; }
fn KEY_PGUP() -> int { return 1004; }
fn KEY_PGDN() -> int { return 1005; }
fn KEY_HOME() -> int { return 1006; }
fn KEY_END()  -> int { return 1007; }

fn pad_right(s: str, w: int) -> str {
    let mut r = s;
    while str_len(r) < w { r = str_concat(r, " "); }
    return r;
}

fn pad_left_s(s: str, w: int) -> str {
    let mut r = s;
    while str_len(r) < w { r = str_concat(" ", r); }
    return r;
}

fn trunc(s: str, w: int) -> str {
    if str_len(s) <= w { return s; }
    return str_concat(str_slice(s, 0, w - 1), "~");
}

fn size_str(n: int) -> str {
    if n < 0       { return "   ?"; }
    if n < 1024    { return str_concat(pad_left_s(str_from_int(n), 4), "B"); }
    if n < 1048576 { return str_concat(pad_left_s(str_from_int(n / 1024), 4), "K"); }
    return str_concat(pad_left_s(str_from_int(n / 1048576), 4), "M");
}

fn fm_join(base: str, name: str) -> str {
    if str_ends_with(base, "/") {
        return str_concat(base, name);
    }
    return str_concat(str_concat(base, "/"), name);
}

fn fm_parent(p: str) -> str {
    let len = str_len(p);
    if len <= 1 { return "/"; }
    let mut end = len;
    if str_slice(p, len - 1, len) == "/" { end = len - 1; }
    let mut i = end - 1;
    while i > 0 {
        if str_slice(p, i, i + 1) == "/" { return str_slice(p, 0, i); }
        i = i - 1;
    }
    return "/";
}

fn raw_print(s: str) { io::print(s); }

// Draw one row of the listing.
// Note: we compute fm_join(path, name) twice to avoid move-in-loop errors.
fn draw_entry_row(path: str, name: str, row: int, cols: int, is_selected: int) {
    io_move_cursor(row, 1);

    // check type — compute fresh each call (avoids str move issue)
    let is_d = fs_is_dir(fm_join(path, name));

    let mut disp = if is_selected == 1 {
        io_set_reverse();
        str_concat(" ▶ ", "")
    } else {
        str_concat("   ", "")
    };

    if is_d == 1 {
        disp = str_concat(disp, str_concat("[", str_concat(name, "]")));
        raw_print(trunc(pad_right(disp, cols - 7), cols - 7));
        raw_print("  [dir]");
    } else {
        let sz = fs_file_size(fm_join(path, name));
        disp = str_concat(disp, name);
        raw_print(trunc(pad_right(disp, cols - 7), cols - 7));
        raw_print("  ");
        raw_print(size_str(sz));
    }
    io_reset_attr();
}

fn draw_screen(path: str, count: int, selected: int,
               rows: int, cols: int, offset: int, msg: str) {
    io_clear_screen();

    // title bar
    io_move_cursor(1, 1);
    io_set_bold();
    raw_print(trunc(pad_right(str_concat(" THATTEOS fm  ", path), cols), cols));
    io_reset_attr();

    // file listing rows
    let list_rows = rows - 4;
    let mut row = 2;
    let mut i   = offset;
    while row <= list_rows + 1 {
        if i < count {
            let name = fs_list_dir_entry(i);
            let sel  = if selected == i { 1 } else { 0 };
            draw_entry_row(path, name, row, cols, sel);
        } else {
            io_move_cursor(row, 1);
            raw_print(pad_right("", cols));
        }
        row = row + 1;
        i   = i + 1;
    }

    // status row
    io_move_cursor(rows - 1, 1);
    let status = if count > 0 {
        str_concat("  ", str_concat(str_from_int(selected + 1),
                   str_concat("/", str_concat(str_from_int(count), " entries"))))
    } else {
        str_concat("  0 entries in ", path)
    };
    let status_msg = if str_len(msg) > 0 {
        str_concat(str_concat(status, "   "), msg)
    } else {
        status
    };
    raw_print(trunc(pad_right(status_msg, cols), cols));

    // key help
    io_move_cursor(rows, 1);
    raw_print(trunc(pad_right(
        " ↑↓:nav  Enter:open  Bksp:parent  r:run  d:del  c:copy  m:move  q:quit",
        cols), cols));
}

fn prompt(label: str) -> str {
    terminal_set_cooked();
    io_clear_screen();
    io::print(label);
    let result = io::read_line();
    terminal_set_raw();
    return str_trim(result);
}

fn confirm(label: str) -> int {
    terminal_set_cooked();
    io_clear_screen();
    io::print(label);
    io::print(" [y/N] ");
    let r = str_trim(io::read_line());
    terminal_set_raw();
    if r == "y" || r == "Y" { return 1; }
    return 0;
}

fn run_and_wait(binary: str) {
    terminal_set_cooked();
    io_clear_screen();
    let exit_code = process_spawn(binary);
    io::print("  [exit ");
    io::print_int(exit_code);
    io::println("]   press Enter");
    let _ = io::read_line();
    terminal_set_raw();
}

fn main() {
    let mut cwd      = ".";
    let mut running  = 1;
    let mut selected = 0;
    let mut offset   = 0;
    let mut msg      = "";

    terminal_set_raw();
    io_clear_screen();

    while running == 1 {
        let rows      = terminal_get_rows();
        let cols      = terminal_get_cols();
        let list_rows = rows - 4;

        let count = fs_list_dir_open(cwd);
        if count < 0 {
            msg = str_concat("cannot open: ", cwd);
            cwd = ".";
        }

        if selected >= count && count > 0 { selected = count - 1; }
        if selected < 0 { selected = 0; }
        if selected < offset { offset = selected; }
        if selected >= offset + list_rows { offset = selected - list_rows + 1; }

        draw_screen(cwd, count, selected, rows, cols, offset, msg);
        msg = "";
        io_move_cursor(rows, cols);

        let key = io_read_key();

        if key == 113 {                                     // q
            running = 0;

        } elif key == KEY_UP() || key == 107 {              // up / k
            if selected > 0 { selected = selected - 1; }

        } elif key == KEY_DOWN() || key == 106 {            // down / j
            if selected < count - 1 { selected = selected + 1; }

        } elif key == KEY_HOME() || key == 103 {            // Home / g
            selected = 0;
            offset   = 0;

        } elif key == KEY_END() || key == 71 {              // End / G
            if count > 0 { selected = count - 1; }

        } elif key == KEY_PGUP() {
            selected = selected - list_rows;
            if selected < 0 { selected = 0; }

        } elif key == KEY_PGDN() {
            selected = selected + list_rows;
            if selected >= count { selected = count - 1; }

        } elif key == 13 || key == 10 {                     // Enter
            if count > 0 {
                let name = fs_list_dir_entry(selected);
                // compute path fresh — avoid move-in-loop
                if fs_is_dir(fm_join(cwd, name)) == 1 {
                    cwd      = fm_join(cwd, name);
                    selected = 0;
                    offset   = 0;
                } else {
                    run_and_wait(fm_join(cwd, name));
                }
            }

        } elif key == 127 || key == 8 {                     // Backspace
            cwd      = fm_parent(cwd);
            selected = 0;
            offset   = 0;

        } elif key == 114 {                                  // r — run
            if count > 0 {
                let name = fs_list_dir_entry(selected);
                run_and_wait(fm_join(cwd, name));
            }

        } elif key == 100 {                                  // d — delete
            if count > 0 {
                let name = fs_list_dir_entry(selected);
                let ask  = str_concat("delete ", fm_join(cwd, name));
                let ok   = confirm(ask);
                if ok == 1 {
                    fs_remove_file(fm_join(cwd, name));
                    msg = str_concat("deleted: ", name);
                    if selected > 0 { selected = selected - 1; }
                }
            }

        } elif key == 99 {                                   // c — copy
            if count > 0 {
                let name = fs_list_dir_entry(selected);
                let src  = fm_join(cwd, name);
                let dst  = prompt(str_concat("copy destination: ", ""));
                if str_len(dst) > 0 {
                    let rc = fs_copy(src, dst);
                    if rc == 1 { msg = str_concat("copied → ", dst); }
                    else       { msg = "copy failed"; }
                }
            }

        } elif key == 109 {                                  // m — move
            if count > 0 {
                let name = fs_list_dir_entry(selected);
                let src  = fm_join(cwd, name);
                let dst  = prompt(str_concat("move destination: ", ""));
                if str_len(dst) > 0 {
                    let rc = fs_move(src, dst);
                    if rc == 1 {
                        msg = str_concat("moved → ", dst);
                        if selected > 0 { selected = selected - 1; }
                    } else {
                        msg = "move failed";
                    }
                }
            }
        }
        // ignore other keys
    }

    terminal_set_cooked();
    io_clear_screen();
    io::println("  fm: goodbye.");
}
