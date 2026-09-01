# thatteOS — Deep Study, GOD Files, Bugs, Improvements, Enhancements

© Manish Jagdish Thatte — 2026-08-02

---

## 1. Codebase Overview

**Total ManiT source:** ~13,059 lines across 47 .mt files

### Kernel (`src/`) — 20 files, ~5,100 lines

| File                       | Lines | Responsibility                                |
| -------------------------- | ----- | --------------------------------------------- |
| `boot.mt`                | 327   | Entry point, boot sequence orchestration      |
| `kernel/scheduler.mt`    | 321   | Priority scheduler, TBRANCH dispatch          |
| `kernel/process.mt`      | 178   | PCB, sys_fork/exec/exit                       |
| `kernel/interrupt.mt`    | 367   | 27-vector IDT, priority nesting               |
| `kernel/privilege.mt`    | 221   | 3-level privilege, priv transitions           |
| `kernel/timer.mt`        | 236   | System tick, sleep queue, quantum             |
| `kernel/signal.mt`       | 334   | 9 signals, disposition, delivery              |
| `kernel/panic.mt`        | 259   | Fault handler, severity trit                  |
| `kernel/klog.mt`         | 353   | Ring-buffer kernel log                        |
| `kernel/guard.mt`        | 367   | Input validation / bounds checking            |
| `mm/vmem.mt`             | 179   | Virtual memory map, MST enforcement           |
| `mm/pgtable.mt`          | 243   | Page table, CoW/demand-zero/JIT               |
| `syscall/syscall.mt`     | 296   | TBRANCH dispatcher, 16 syscalls               |
| `drivers/tty.mt`         | 295   | TTY driver at SERVICE privilege               |
| `ipc/messages.mt`        | 242   | SYS_SEND/RECV, checksum, MSG_WAIT             |
| `fs/tritfs.mt`           | 528   | TritFS: inodes, FD table, sys_open/read/write |
| `security/capability.mt` | 340   | 9-trit CapWord, attenuation, enforcement      |
| `userspace/shell.mt`     | 404   | Interactive shell, 13 commands                |
| `userspace/init.mt`      | 178   | init process                                  |
| `userspace/login.mt`     | 336   | Login manager                                 |

### Userspace Apps (`userspace/`) — 11 files, ~2,700 lines

calc, fib, tritdump, fm (TUI file manager), editor (TUI), browser (TUI), gui_browser (SDL2), gui_fm (SDL2), caps_demo, ipc_demo, thatteos (hosted shell)

### studioMani IDE (`studioMani/`) — 14 files, ~3,700 lines

main.mt (974L, GOD), buffer.mt, editor.mt, layout.mt, highlight.mt, explorer.mt, sidebar.mt, terminal.mt, palette.mt, theme.mt, dialogs.mt, browser.mt, email.mt + standalone apps

---

## 2. GOD Files

### 2.1 `studioMani/studioMani/main.mt` — 974 lines ⚠️ GOD FILE

> **DONE 30 August 2026, and the split below is NOT the one that was taken.**
> `main.mt` is 53 lines. The plan here splits by TAB (`events_editor.mt`,
> `events_browser.mt`, …); the loop actually dispatches on the SDL **event
> type** first and on the tab second, so a per-tab split cuts across all five
> arms and rewrites them, while a per-event split is pure code motion. The
> files are `frame.mt` and `events_{quit,key,text,mouse,wheel}.mt`, plus
> `titlebar.mt` and `state.mt`. **Re-probe a plan against the code before
> implementing it** — this document's own standing warning, earned again.


**What it does:** Title bar, tab bar, ENTIRE event loop for all 5 tabs (Editor, Explorer, Browser, Email, Terminal), mouse hit detection, keyboard dispatch for every tab. Every tab's mouse/keyboard logic is inlined in one 900-line `main()` function.

**Split plan:**

```
main.mt (974) →
  titlebar.mt        draw_titlebar(), draw_statusbar()
  events_editor.mt   handle_key_editor(), handle_mouse_editor()
  events_browser.mt  handle_mouse_browser(), handle_key_browser()
  events_email.mt    handle_mouse_email(), handle_key_email()
  events_explorer.mt handle_mouse_explorer(), handle_key_explorer()
  events_terminal.mt handle_key_terminal()
  main.mt (~100L)    main() — init + event loop skeleton only
```

### 2.2 `fs/tritfs.mt` — 528 lines ⚠️ BORDERLINE GOD

**What it does:** Inode struct, FD table struct (9 inline fields), TritFS struct (9 inline inodes), sys_open, sys_close, sys_read, sys_write, sys_stat, sys_mkdir, create_file, check_permission, demo main(). The `sys_open` function has a 6-way elif chain to set one field because ManiT lacks array indexing into struct fields — this is the root cause.

**Split plan:**

```
fs/tritfs.mt →
  fs/inode.mt      Inode struct, make_inode, print_inode, itype/perm names
  fs/fdtable.mt    FileDesc, FdTable, fd_table_init, sys_open, sys_close
  fs/tritfs.mt     TritFS struct, tritfs_init, sys_read/write/stat/mkdir
  fs/perms.mt      check_permission
```

### 2.3 `userspace/gui_browser.mt` — 568 lines ⚠️ BORDERLINE

Monolithic SDL2 browser: address bar, history, rendering, scroll — all in one file. Acceptable for now but will grow.

### All other files: under 450 lines, single responsibility — no GOD files.

---

## 3. Structural Issues

### 3.1 The "9 inline fields" anti-pattern — PERVASIVE

Because ManiT does not have mutable array fields in structs (or indexing into struct fields), every container uses flat named fields: `fd0..fd8`, `s0..s8`, `e0..e8`, `i0..i8`, `q0..q2`. This causes:

- Repetitive 9-way `if/elif` chains for insert/update (tritfs.mt, timer.mt, klog.mt, messages.mt, signal.mt)
- Every "update one slot" operation rebuilds the entire struct with all 9 fields
- Massive boilerplate: `return SleepQueue { count: new_count, s0: entry, s1: queue.s1, s2: queue.s2, ... }` — this appears in timer.mt, klog.mt, tritfs.mt, messages.mt

**Root cause (AS WRITTEN 2 Aug 2026 — BOTH CLAIMS ARE FALSE, measured
30 Aug 2026):** ManiT compiler lacks:

1. ~~Mutable struct field arrays (e.g., `pub slots: [T; 9]`)~~
2. ~~Struct field spread/update syntax (e.g., `SomeStruct { ..old, field: new }`)~~

> **CORRECTION, 30 August 2026.** Both exist and both were probed directly.
> `pub slots: [PCB; 9]` compiles and reads back correctly on **both** backends,
> and `T { ..p, f: v }` copies (ENHANCEMENT_PLAN's status table records the
> same two as DONE). So the "9 inline fields" pattern is not forced by a
> missing feature.
>
> **But do not conclude the pattern should be replaced, because the real
> reasons are worse and neither is in this document.** (1) An UNSIZED `[T]`
> field is a live maniTC defect — the array is frame-allocated with no escape
> analysis, so a struct holding one, returned from a function, carries a
> pointer to a dead stack frame and corrupts silently on T3 (report.txt
> **P94**; `src/kernel/process.mt` is the instance). (2) The SIZED form is
> correct and costs a copy per assignment: converting `ProcTable` to
> `[PCB; 9]` fixes the corruption and then **exhausts the 2,536-word T3 heap**,
> 2,534 words against a 55-word margin. The nine named fields are the right
> shape here for two independent measured reasons, not for a missing feature.

### 3.2 Duplicated structs across files

`PCB` is defined in: `boot.mt`, `scheduler.mt`, `process.mt` — three different versions with different fields. Same for `priv_name()`, `state_name()`, `get_primary()` — duplicated verbatim in boot.mt and scheduler.mt.

**Root fix:** ManiT needs a `use` module system that actually imports types from other .mt files. Currently each .mt is compiled standalone. This is the single biggest architectural gap.

### 3.3 Shell commands hardcoded as string literals

In `shell.mt`, command dispatch is:

```
} elif cmd == "trit 42" {
} elif cmd == "trit 0" {
} elif cmd == "trit -13" {
```

Arguments are not parsed — entire command+args is matched as one literal. This means `trit 7` would fail. Real tokenization needed.

### 3.4 Simulated rather than real state mutation

All state-carrying structs are immutable values. Every operation returns a new copy of the entire struct. For small structs this is fine. For `KernelLog` (9 LogEntry fields, each with 5 fields), every `klog()` call copies ~45 values. This is a ManiT limitation (no `&mut` references to struct fields), but for correctness in the hosted T3ISA emulator it is fine.

### 3.5 `build.sh` has a fragile IR patch

```bash
sed 's/ret ptr 0$/ret ptr null/g' thatteos.ll > thatteos_fixed.ll
```

This patches a codegen bug in manitc. The tif merge-block generates `ret ptr 0` instead of `ret ptr null`. This should be fixed in the compiler, not worked around in the build script.

### 3.6 studioMani `build.sh` uses file concatenation

The studioMani build concatenates all .mt files into one before compiling — a preprocessing hack because ManiT has no module imports. This is the right workaround given the compiler's current state, but it means:

- Order of concatenation matters
- No namespacing between modules
- Global function name collisions possible

---

## 4. Bugs

### 4.1 `shell.mt:dispatch_command` — argument parsing absent

Commands with arguments (trit N, kill P S, stat F, echo TEXT) are matched as full literal strings. Any invocation with different arguments silently falls to "command not found". The `cmd_trit()`, `cmd_kill()`, `cmd_stat()` functions exist but are only reachable via hardcoded literals.

**Fix:** Implement `str_split_first(cmd)` → `(verb, args)` tokenization, then dispatch on verb, parse args from the remainder.

### 4.2 `tritfs.mt:sys_open` — FD slot indexing is off-by-one

`sys_open` places new FDs at `fd_table.count` (0-indexed), but only handles counts 3..7 and has an `else` for 8. If count is already 8 when called, `else` runs and creates fd8. If count is somehow 9, the function returns without placing the FD (guarded by `if fd_table.count >= 9` but only after allocating `new_fd`). Minor correctness issue — `new_fd` is created then the early return discards it. Clean up: move the guard before `make_fd`.

### 4.3 `timer.mt:timer_tick` — woken entries never cleared

`check_and_wake()` detects expiry and prints the wakeup message, but returns `bool`. The `timer_tick` caller receives `w0..w8` booleans but never uses them to mark the `SleepEntry` as `valid: false`. The sleep queue never actually clears — processes would be "woken" on every subsequent tick until the queue slot is reused. The comment `// Clear woken entries (simplified — mark invalid)` acknowledges this.

**Fix:** Return updated `SleepQueue` from `timer_tick` that marks expired entries `valid: false`.

### 4.4 `klog.mt:should_log` — filter logic inverted for ERROR

```
fn should_log(entry_level: trit, min_level: trit) -> bool {
    tif entry_level {
        - => return true,   // ERROR always logged
```

`-` is ERROR. But the level ordering is ERROR(-) < INFO(0) < DEBUG(+). "min_level=-" means only log ERROR; "min_level=0" means log INFO and ERROR. The current logic:

- When `entry_level=0 (INFO)` and `min_level=- (ERROR-only)`: returns `false` ✓
- When `entry_level=+ (DEBUG)` and `min_level=- (ERROR-only)`: returns `false` ✓

Actually the logic is correct. But the comment "ERROR(-) always logged" is misleading — it only holds when ERROR is a level; there is no mechanism to suppress ERROR messages even at a higher min_level. This is the correct behavior for a kernel log but should be clearly documented.

### 4.5 `interrupt.mt:get_interrupt_priority` — vector 0 (timer) is MEDIUM

```
fn get_interrupt_priority(vector: int) -> trit {
    if vector >= 1 && vector <= 5 { return +; }
    elif vector >= 18 { return -; }
    else { return 0; }
}
```

Vector 0 (timer) returns MEDIUM (0). But in `interrupt_init()`, the priorities array has `priorities[0] = 0` (MEDIUM) — consistent. However the IDT names array lists vector 0 as "timer" with MEDIUM priority. When `interrupt_dispatch(0, state)` is called during a HIGH handler (nesting_depth>0, current_priority=+), `can_preempt(0, +)` returns false — timer cannot preempt the syscall handler. This is correct real-world behavior (timer is preemptable by syscall handler) but the demo comment "Timer (MEDIUM) during HIGH handler: cannot preempt" should be explicit about this being intentional.

### 4.6 `capability.mt:get_cap` — fallthrough to c8 for idx > 8

```
fn get_cap(cap: CapWord, idx: int) -> trit {
    if idx == 0 { return cap.c0; }
    ...
    else { return cap.c8; }   // also hit for idx = 9, 10, etc.
}
```

Out-of-range `idx` silently returns `cap.c8`. Should assert or return DENIED(-) for unknown capability indices.

### 4.7 `signal.mt:sys_signal` — idx 0 (SIG_KILL) and idx 1 (SIG_STOP) not handled in update path

`sys_signal()` correctly rejects SIG_KILL(-4) and SIG_STOP(-3) before the update logic. But the update path only covers `idx == 2..8` (SIG_TERM through SIG_CHLD). `idx == 0` and `idx == 1` are never matched and fall to the `else` which updates `d8` — but this code is unreachable because SIG_KILL/SIG_STOP are rejected earlier. Safe but confusing. Add explicit comments.

### 4.8 `boot.mt` — duplicate function definitions with `scheduler.mt` and `process.mt`

`get_primary()`, `state_name()`, `PCB`, `process_init()`, `scheduler_run_demo()` are defined in `boot.mt` AND separately in `scheduler.mt` / `process.mt`. This is not a runtime bug (each file is compiled standalone) but means the two implementations can diverge silently.

---

## 5. Compiler / Language Improvements Needed

These are gaps in `manitc` that block thatteOS from being fully functional.

### 5.1 MODULE IMPORTS — Critical (blocks everything)

`use kernel::process::PCB;` — currently impossible. Each .mt is compiled standalone. Without this:

- Structs must be redefined in every file that needs them
- No shared type-checked interfaces between modules
- The `studioMani` build works around this by concatenating files — a hack

**Fix in manitc:** Implement `use path::to::module::Item;` resolution. The parser already has `use` statement parsing; the semantic analyzer needs to actually load and type-check the imported module.

### 5.2 STRUCT UPDATE SYNTAX — High Priority

Currently every field-update requires spelling out all N fields:

```manit
return PCB { pid: p.pid, state: 3, pc: p.pc, sp: p.sp,
             priority: p.priority, age: 0, quantum_used: 0 };
```

Rust-style spread syntax would eliminate 80% of this:

```manit
return PCB { ..p, state: 3, age: 0, quantum_used: 0 };
```

**Fix in manitc:** Add struct update syntax `{ ..base_expr, field: val, ... }` in the parser and lower it to field-by-field copy in IR.

### 5.3 ARRAY FIELDS IN STRUCTS — High Priority

`struct TritFS { pub i0: Inode, pub i1: Inode, ... pub i8: Inode }` — 9 named fields instead of `pub inodes: [Inode; 9]`. Arrays in structs need:

- Fixed-size array field type `[T; N]`
- Index access: `fs.inodes[3]`
- Mutable index assignment: `fs.inodes[idx] = new_inode`

**Fix in manitc:** The type system already has `[T]` (dynamic arrays). Add `[T; N]` (fixed-size), and allow them as struct fields. Lower to a stack-allocated block.

### 5.4 STRING SPLITTING / TOKENIZATION — Medium Priority

`str_split(s, delim) -> [str]` is absent from stdlib. The shell cannot parse `"trit 42"` into `["trit", "42"]`. This alone blocks the shell from being interactive.

**Fix:** Add to `manitc/stdlib/io.mt`:

- `str_split_first(s: str, sep: str) -> (str, str)` — split at first occurrence
- `str_trim(s: str) -> str` — strip leading/trailing whitespace
- `str_split(s: str, sep: str) -> [str]` — full tokenizer

### 5.5 MODIFIER KEY STATE — Medium Priority (studioMani)

`gui_key_mod_ctrl()` and `gui_key_mod_shift()` are missing. This blocks Ctrl+S (save), Ctrl+Z (undo), Shift+arrow (selection), Ctrl+F (find) in studioMani. Already noted in CLAUDE.md as pending.

**Fix in manitc runtime (C):** Add SDL2 `SDL_GetModState()` wrappers exposed as:

```
gui_key_mod_ctrl() -> int   // 1 if Ctrl held
gui_key_mod_shift() -> int  // 1 if Shift held
gui_key_mod_alt() -> int    // 1 if Alt held
```

### 5.6 ARROW KEY CODES — Medium Priority (studioMani editor)

`gui_key_left()` / `gui_key_right()` — SDL2 arrow key SDLK values — missing. Already noted in CLAUDE.md.

**Fix:** Add constants or functions returning SDLK_LEFT (1073741904), SDLK_RIGHT (1073741903), SDLK_UP (1073741906), SDLK_DOWN (1073741905).

### 5.7 FILESYSTEM STDLIB — Medium Priority (studioMani)

`fs_read_file(path) -> str`, `fs_write_file(path, content) -> int`, `fs_copy_file`, `fs_rename`, `fs_mkdir` — all missing. studioMani's editor cannot actually save files. Already noted in CLAUDE.md.

**Fix:** Implement in C runtime, expose via syscall wrapper numbers in the emulator's `do_syscall`.

### 5.8 NET IMAP/SMTP — Low Priority (studioMani)

`net_imap_connect`, `net_imap_list`, `net_imap_fetch`, `net_smtp_send` — noted as pending in CLAUDE.md. Email tab is fully drawn but backend is a stub.

### 5.9 `ret ptr 0` CODEGEN BUG — Fix in compiler

The `build.sh` patches `ret ptr 0` → `ret ptr null` via sed. This means tif-expressions that return pointer/string types emit invalid LLVM IR. Fix in `codegen_llvm/emit_instr.rs`: when emitting the merge block's phi/ret for a tif expression returning a pointer type, use `ptr null` not `ptr 0`.

### 5.10 ASSERT / UNREACHABLE — Missing

No `assert(condition, msg)` or `unreachable()` construct in ManiT. The compiler cannot statically verify exhaustiveness of some patterns. Add as builtin that maps to LLVM `unreachable` in release and `abort()` in debug.

---

## 6. OS Design Enhancements for Full Functionality

### 6.1 Unified Boot Entry Point

Currently `boot.mt`, `scheduler.mt`, `process.mt` etc. each have their own `main()` that runs a demo. A real OS needs a single `kernel_main()` in `boot.mt` that calls into the other modules. This requires module imports (§5.1).

**Plan:** Once module imports work:

1. Remove `main()` from all non-boot kernel files
2. `boot.mt:kernel_main()` calls `interrupt_init()`, `process_init()`, `vmem_init()`, `syscall_init()`, `tty_init()`, `tritfs_init()`, `timer_init()`, then `scheduler_run()`
3. The scheduler loop is the OS's run loop

### 6.2 Real Shell Input Loop

The hosted `thatteos.mt` shell already reads real stdin input via `io::readline()`. The `src/userspace/shell.mt` demo shell dispatches hardcoded strings. These need to merge: use the hosted shell's input loop + the kernel shell's command implementations + real argument tokenization (§5.4).

### 6.3 TritFS: Real Data Storage

`sys_read`/`sys_write` in `tritfs.mt` simulate bytes-transferred without touching actual data. For the hosted mode:

- Map TritFS inodes to real Linux files in `/tmp/tritfs/`
- `sys_open` → `open(2)`, `sys_read` → `read(2)`, `sys_write` → `write(2)` via the emulator's syscall bridge

### 6.4 Timer: Real Tick Source

In hosted mode, `timer_tick()` is called manually in demos. For real event-loop integration:

- Use `gui_ticks()` (SDL2 `SDL_GetTicks`) to advance the system tick each event loop iteration
- Call `timer_tick()` each ~16ms frame (60Hz)
- Wire to `scheduler_run()` when quantum expires

### 6.5 Interrupt → Scheduler Integration

`interrupt_dispatch()` and `scheduler_run()` are currently independent demos. In a real OS:

- Timer interrupt (vector 0) → `timer_tick()` → quantum expired → `scheduler_run()`
- Syscall interrupt (vector 1) → `syscall_dispatch()` → may yield → `scheduler_run()`
- This event-driven scheduler loop is the kernel's heart

### 6.6 IPC: Real Queue (not struct stubs)

`messages.mt` has `MsgQueue` with `q0_sender/q0_type/q0_cs` — only the first 3 message metadata fields are stored. Full messages (3 payloads) are not stored in the queue at all. Real IPC needs a proper ring buffer.

Once array-fields-in-structs are supported (§5.3):

```manit
struct MsgQueue {
    pub pid: int,
    pub messages: [IpcMsg; 9],
    pub head: int,
    pub tail: int,
    pub count: int,
}
```

### 6.7 Capability: Wire to Syscall Dispatcher

`capability.mt` has `enforce(cap, required_cap, syscall_name) -> bool` but it is never called from `syscall.mt`. Every syscall should call `enforce()` first. This requires:

1. Module imports (§5.1) so `syscall.mt` can `use security::capability::*`
2. A per-process CapWord table (one per PCB)

### 6.8 Signal: Wire to Process + Scheduler

`signal.mt:deliver_signal()` prints what it would do but doesn't actually:

- Set `process.state = KILLED(-4)` in the PCB
- Invoke `scheduler_run()` after state change
- Jump to a user-installed handler address

Again blocked on module imports.

### 6.9 studioMani: Gap Buffer Editor Complete

`studioMani/studioMani/buffer.mt` (370L) has a proper gap buffer implementation. The editor tab is functionally draw-correct. Missing:

- Ctrl+S → `fs_write_file()` (blocked on §5.7)
- Ctrl+Z/Ctrl+Y undo/redo (gap buffer supports it, needs history stack)
- Shift+arrow selection (needs §5.5, §5.6)
- Ctrl+F find bar (UI drawn, search logic absent)

### 6.10 studioMani: Terminal Tab

`terminal.mt` draws a terminal widget and has `process_spawn(cmd)` infrastructure. Missing: live PTY output streaming. Once `fs_read_file` works, can feed `/proc/self/fd/1` style output.

---

## 7. Missing Kernel Modules

For a fully functional OS these modules should exist but don't yet:

| Module                  | Responsibility                                        |
| ----------------------- | ----------------------------------------------------- |
| `kernel/context.mt`   | Save/restore CPU registers for real context switching |
| `kernel/mmu.mt`       | Physical frame allocator (buddy or bitmap)            |
| `fs/vfs.mt`           | VFS layer — abstract inode ops for TritFS + devfs    |
| `drivers/keyboard.mt` | Real keyboard input driver (SDL2 → tty buffer)       |
| `drivers/clock.mt`    | Wall-clock time, RTC interface                        |
| `ipc/pipe.mt`         | Unnamed pipes (for shell `                            |
| `net/socket.mt`       | TCP socket abstraction (for studioMani browser/email) |
| `mm/heap.mt`          | Kernel heap allocator (slab or BtreeMM)               |

---

## 8. Test Coverage Gaps

`tests/test_all.sh` is a good integration test harness (8 sections, ~50 checks). Gaps:

- `test_filesystem.mt` exists (compiled) but tests use simulated data not real TritFS ops
- `test_ipc.mt` tests compile but queue draining / MSG_WAIT not tested
- No test for scheduler starvation prevention (age >= 9 path)
- No test for privilege escalation rejection
- No test for capability attenuation correctness
- No negative tests (deliberate bad inputs to guards — `validate_pid(-5)` etc.)

The .mt test files in `tests/` appear to be T3ISA emulator tests (compiled to `.t3b`). The shell-based `test_all.sh` tests the hosted binary only.

---

## 9. Priority Action List

### Tier 1 — Compiler fixes (unlock everything)

1. **Fix `ret ptr 0` codegen bug** — remove the `build.sh` sed patch
2. **Add struct update syntax `{ ..base, field: val }`** — kills 80% of boilerplate
3. **Add `str_split_first()` to stdlib** — enables real shell command parsing

### Tier 2 — Language features (enable real OS)

4. **Module imports** (`use path::to::Type`) — enables single-definition structs
5. **Fixed-size array fields in structs** (`pub slots: [T; 9]`) — kills flat-field anti-pattern
6. **Modifier key + arrow key stdlib** — completes studioMani editor

### Tier 3 — OS functionality

7. **Wire shell argument parsing** — `cmd_trit(n)` reachable for any N
8. **Wire timer_tick to clear woken sleep entries** — fix §4.3
9. **Wire capability enforcement into syscall dispatcher**
10. **TritFS real file I/O** in hosted mode (map to Linux files)

### Tier 4 — Enhancements

11. **Split studioMani/main.mt** into per-tab event handlers
12. **Split fs/tritfs.mt** into inode/fdtable/fs layers
13. **Add `kernel/mmu.mt`** — physical frame allocator
14. **Add `ipc/pipe.mt`** — shell pipe operator
15. **Add negative test suite** to test_all.sh


---

## 10. What "Fully Functional" Requires (Summary)

| Capability                  | Status             | Blocker                     |
| --------------------------- | ------------------ | --------------------------- |
| Boot + scheduler loop       | Demo-only          | Module imports              |
| Real shell input            | Working (hosted)   | Arg parsing (str_split)     |
| Shell commands with args    | Broken             | str_split + dispatch fix    |
| Real filesystem r/w         | Simulated          | fs_read/write_file stdlib   |
| IPC between processes       | Simulated          | Real queue + module imports |
| Capability enforcement      | Disconnected       | Module imports + wire-up    |
| Signal delivery             | Disconnected       | Module imports + wire-up    |
| studioMani file save        | Stub               | fs_write_file stdlib        |
| studioMani editor shortcuts | Blocked            | Modifier + arrow keys       |
| studioMani email send       | Stub               | net_smtp stdlib             |
| T3ISA bare-metal boot       | Compiled, untested | Real hardware or QEMU T3ISA |

The kernel logic is sound and architecturally complete. The three critical path items are:

1. **Compiler: module imports** → struct deduplication, wiring subsystems
2. **Compiler: struct update syntax** → eliminate boilerplate
3. **Stdlib: str_split + fs_read/write_file + modifier keys** → shell and IDE usability

Once those three are done, thatteOS can be wired into a real hosted OS loop that actually boots, schedules, handles input, reads/writes files, and runs studioMani as a fully interactive IDE.
