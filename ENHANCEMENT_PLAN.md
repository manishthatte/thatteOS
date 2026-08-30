# thatteOS — Enhancement Plan

**Author: Manish Jagdish Thatte**
© Manish Jagdish Thatte

Written 29 August 2026, immediately after merging `oss/unreleased/thatteos` into
this repository. It supersedes the priority list in `WORKINGS_ANALYSIS.md`
(2 August 2026), which is merged here beside it and which **§2 below shows to be
stale in five of its ten blocking claims**.

---

## 0. What this plan was measured against, and why that sentence is here

Every number and every verdict below was produced by running the compiler, not
by reading a document. The instrument is named because this project has twice
recorded a result that turned out to be a property of the instrument rather than
of the subject (report.txt P37, P64).

| | |
|---|---|
| Compiler | `manitc/target/release/manitc` |
| sha (first 16) | `9d672ae3d50a5d65` |
| maniTC HEAD | `91472d6` ("the emulator held strings as text…", P82) |
| thatteOS HEAD | `ed7ddbb`, working tree carries this merge |

**HEAD moved under this session and that is worth recording.** Everything here
was first measured against `0c6133b887765551` (HEAD `79cf045`). At 07:49 a
concurrent session in the same directory committed P82 and rebuilt the release
binary to `9d672ae3d50a5d65`. **Every finding in §3 was then re-run against the
new binary and reproduces identically**, as did the studioMani build and
thatteOS 61/61. The working tree here is not private; pin the binary by sha
before measuring and check it again afterwards.

Two instrument hazards this repository already knows about, restated because
this plan's phases depend on them:

* **`build.sh` prefers `target/release/manitc` and falls back to debug.** A bare
  `./build.sh` tests whatever release binary happens to be on disk. To test a
  working tree, pass it: `MANITC=../manitc/target/debug/manitc ./build.sh`. This
  is how report.txt P37 — a silent wrong answer in five thatteOS files —
  survived a campaign of "61/61" runs.
* **`tests/test_all.sh` guards every userspace test on the binary existing.**
  With an empty `userspace/bin/` it runs 27 of its 61 tests, passes 27, and
  prints **ALL TESTS PASSED**. A green summary there does not mean the tests
  ran. Build both halves before believing the number.

---

## 1. What the merge brought in

`oss/unreleased/thatteos` held 39 files and **collided with nothing** in this
repository — the merge was purely additive.

| Merged | Size | Tracked? |
|---|---|---|
| `studioMani/` — the IDE (13 modules, 3,355 lines) plus three standalone apps (browser 290, email 370, file manager 411) | 4,426 lines of ManiT | yes |
| `tools/` — `build_usb.sh`, `launch_gui.sh`, `test_qemu.sh` | 28 KB | yes |
| `baremetal/ANALYSIS.txt` — the Target A/B/C strategic analysis, 28 July | 29 KB | **no — .gitignore, see §7** |
| `WORKINGS_ANALYSIS.md` — the 2 August deep study | 24 KB | yes |
| `CLAUDE.md` — thatteOS working rules | 12 KB | **no — .gitignore, see §7** |
| `baremetal/thatteos_{vmlinuz,initramfs}` | **46 MB** | **no — .gitignore** |
| `studioMani/output/*` — binaries, `.ll`, `.t3s` | 6.9 MB | **no — .gitignore** |

`.gitignore` gained `studioMani/output/`, `*.t3s`, and the two boot images **by
name**. They have no extension to match on, and a `git add -A` has swept this
tree before — on 25 August a machine-wide backup task committed an entire
uncommitted campaign and pushed it.

### 1.1 studioMani did not build, and four small classes of edit fixed it

The suite had not compiled since roughly 19 August, when maniTC began compiling
part of its stdlib from ManiT source. Four classes, **99 call sites across three
files**, and all four are now applied:

| # | Class | Sites | Why |
|---|---|---|---|
| 1 | `ch >= "a"` on `str` → compare code points | 3 | report.txt **P45**: `Ord` and `>` disagreed about which types are ordered and the operator's answer won. Before P45 this compared **addresses**, so the test never meant what it reads as — this is a repair, not a port. |
| 2 | flat `str_to_lower` / `str_from_int` / `str_parse_int` / `str_starts_with` → `str::…` | 94 | §3.1 below. These type-check and link on **neither** backend. |
| 3 | a struct literal filling two fields from one `str` | 1 | report.txt **P51**: a struct-literal field is one of four sites the move checker consumes at. Passing to a function does *not* move, so the copy now comes from a call. |
| 4 | user `fn str_count` renamed `sm_str_count` | 1 def | §3.2 below. It collided with the mangled name of `str::count`. |

**Result — all four binaries build and link against real SDL2, SDL2_ttf and
libcurl**, and thatteOS itself is unchanged at 61/61:

```
studioMani  361,592 bytes      sm_browser  159,856 bytes
sm_email    167,800 bytes      sm_fm       172,048 bytes
```

`studioMani/build.sh` was rewritten to delegate to `manitc compile`, as
`build.sh` and `userspace/build.sh` were on 23 August. It had kept all three
steps those two deleted — emit `.ll`, compile `manit_runtime.c` to an object,
hand-link with clang — and all three had rotted the same way. It also read
`$OUT/studioMani.ll`, a file the compile step above it only writes when the
output path ends in `.ll`, which it did not. This is report.txt **P42** in a
third script.

---

## 2. The 2 August analysis, re-measured

`WORKINGS_ANALYSIS.md` §10 named three critical-path items. **Two and a half of
them are already done.** Recorded here because acting on that document as
written would spend weeks re-implementing shipped features.

| Claim (2 Aug) | Measured 29 Aug | Verdict |
|---|---|---|
| §5.1 module imports impossible | `use lib_a; lib_a::helper(21)` — **check exits 0**, then `Undefined label: lib_a::helper` (T3) and `use of undefined value '@lib_a_helper'` (LLVM) | **STILL OPEN**, and silent — see §3.3 |
| §5.2 no struct update syntax | `P { ..p, b: 9 }` prints `9` on both backends | **DONE** |
| §5.3 no fixed-size array struct fields | `struct Q { pub slots: [int; 4] }`, `q.slots[2]` prints `3` on both backends | **DONE** |
| §5.4 no `str_split` / tokenisation | `str::split("trit 42", " ")` yields `trit`, `42` | **DONE** |
| §5.5 no modifier keys | `gui_key_mod_ctrl/shift/alt` declared and implemented in `runtime/gui.c` | **DONE** |
| §5.6 no arrow keys | `gui_key_left/right/up/down` present | **DONE** |
| §5.7 no filesystem stdlib | `fs_read_file`, `fs_write_file`, `fs_copy_file`, `fs_rename`, `fs_mkdir` all present | **DONE** |
| §5.8 no IMAP/SMTP | `net_imap_*` and `net_smtp_send` appear in `email.mt` only in comments and drawn strings — the client honestly says so on screen | **still absent, honestly stubbed** |
| §5.9 `ret ptr 0` codegen bug | maniTC emits `ret ptr null`; the `sed` patch was removed from both build scripts on 23 Aug | **DONE** |
| §7 missing kernel modules | `kernel/context.mt`, `mm/mmu.mt`, `ipc/pipe.mt`, `fs/inode.mt`, `fs/fdtable.mt`, `fs/perms.mt` all exist | **mostly DONE**; `fs/vfs.mt`, `drivers/keyboard.mt`, `drivers/clock.mt`, `net/socket.mt`, `mm/heap.mt` still absent |
| §4.1 shell cannot parse arguments | `thatteos.mt:dispatch` splits verb from args at the first space and passes `args` to 15 commands | **DONE in the hosted shell**, still true of `src/userspace/shell.mt` (8 hardcoded literals) |

**What is still true, and is the whole of the remaining structural problem:**
§3.2's duplicated structs and §6.1's absent unified entry point. Measured:
**every one of the 29 `.mt` files in `src/` has its own `fn main`**, `struct PCB` defined three
times, `struct Inode` three times, `priv_name` six times, `perm_name` five,
`state_name` three, `make_pcb` three, `TritFS`/`FileDesc`/`FdTable`/`vmem_init`
twice each. There is no `kernel_main`.

---

## 3. The finding this plan is organised around

> **`manitc check` exiting 0 does not mean the program links.** Four independent
> mechanisms produce a clean check and a dead program, and between them they
> account for studioMani being unbuildable, for the kernel being 29 separate
> demos, and for the flagship application being unable to run on the flagship
> target.

This is the same family as report.txt N1, P60, P61 and P62 — *a name in one
registry that no other registry defines* — and it now has four more members.
Each is reproduced below by a program short enough to read.

### 3.1 Five flat stdlib names are declared and defined nowhere

`str_from_int`, `str_parse_int`, `str_starts_with`, `str_ends_with` and
`str_substr` are entries in the analyzer's `register_builtins` table. None has a
definition in the C runtime, and the flat spelling does not trigger the stdlib
pull-in that would emit one.

```manit
fn main() { io::println(str_from_int(42)); }
```

```
check:   OK — 1 functions                      # ← one. the stdlib was not pulled in
llvm:    error: use of undefined value '@str_from_int'      (exit 1)
t3:      T3ISA assembler error: Undefined label: str_from_int
```

The qualified spelling works on both backends and the check verdict itself
carries the evidence: `str::from_int(42)` reports **98 functions**, because
asking for the module is what loads it.

**Dated.** The same two probes fail identically on
`manitc-release-96c6f5c7-preexisting` (25 Aug, the pre-campaign binary) and on
`manitc-release-42d8ffcd-from-083b4ff`. This predates the entire Phase-4
campaign; it is not a regression. thatteOS's own sources use **none** of the
five, which is exactly why thatteOS builds 61/61 while studioMani — written
2 August, before the migration — used `str_starts_with` 68 times.

### 3.2 A user function can collide with a stdlib module's mangled name

`str::count` is ManiT source and mangles to the symbol `@str_count`. A top-level
user function of that name emits a second definition of it.

```manit
fn str_count(hay: str, needle: str) -> int { return 7; }
fn main() { io::println(str::concat("a", "b")); }
```

```
check:   OK
llvm:    error: invalid redefinition of function 'str_count'   (exit 1)
t3:      exit 0 — assembles and runs
```

**The backends disagree about whether the program is legal at all.** This is
report.txt P62 from the free-function side; P62 was the `impl`-block side. The
colliding function in studioMani was never called — an unused definition broke
the link.

### 3.3 `use module;` type-checks and links on neither backend

```manit
// lib_a.mt
pub fn helper(x: int) -> int { return x * 2; }
// imports.mt
use lib_a;
fn main() { io::println(fmt::show_int(lib_a::helper(21))); }
```

```
check:   OK — 98 functions, no warning, no mention of the missing module
llvm:    error: use of undefined value '@lib_a_helper'
t3:      T3ISA assembler error: Undefined label: lib_a::helper
```

This is `WORKINGS_ANALYSIS.md` §5.1, still open, and **it is the reason the
kernel is 29 demos.** Nothing forces the duplication except that a `.mt` file
cannot use another one's bodies. studioMani's build concatenates thirteen files
for the same reason.

### 3.4 The entire `gui_*` surface has no T3ISA implementation

```manit
fn main() { gui_init(320, 200, "t"); gui_present(); gui_quit(); }
```

```
check:   OK
llvm:    binary produced, links SDL2                (exit 0)
t3:      wrote assembly … then
         [T3ISA] assembler error: Undefined label: gui_init   (exit 1, no .t3b)
```

**thatteOS's flagship application cannot run on thatteOS's own target.** The
`output/*.t3s` files this repository inherited from the unreleased tree are that
partial product: assembly written, assembly never assembled — and there is not a
single `.t3b` beside them, which is the artefact set testifying to it. The new
`studioMani/build.sh` therefore has the T3 target **off by default** behind
`WITH_T3=1`, and says why in its header.

### 3.5 A FIFTH mechanism, found 30 August 2026, and it is a different KIND

The four above are all *a name in one registry that no other registry defines*.
This one is a **type**, both registries agree the name exists, and Phase 0 —
which closed all four of the others — could never have found it.

```manit
struct S { pub sel: int, pub a: trit, pub b: trit }
let p = if s.sel == 0 { s.a } else { s.b };
```

```
check:        OK — no error, no warning
--verify-ssa: 0 violations, after lowering AND after optimisation
t3:           builds, runs, prints "+"                      <- correct
llvm:         %t12 = phi i8 [ %t9, %if_then0 ], [ %t11, %if_else1 ]
              error: '%t9' defined with type 'i64' but expected 'i8'
```

A struct field is a machine-word **slot**, so reading a `trit` field yields an
`i64`, while the phi is typed from the source *expression* — `trit`, i8. Every
other construct reconciles the two at the use; a phi cannot, because LLVM
requires an incoming value to be available in the *predecessor* block.

**It is a backend divergence in which T3 — the eventual target — is the correct
one**, so a parity failure would have pointed at the wrong backend. Parity
would not have fired anyway: it runs 17 maniTC examples and none of them reads
a sub-word struct field in a branch expression.

Fixed in maniTC as **report.txt P91**, at the definition rather than the phi
(the shape P13/P46 already established). Two live kernel modules —
`kernel/interrupt.mt` and `security/capability.mt` — were unbuildable on LLVM
because of it. See §3.6 for why nobody knew.

### 3.6 And the reason nobody knew: NOTHING COMPILED `src/`

Not `build.sh` (which built the root `thatteos.mt` only), not
`userspace/build.sh`, not `.github/workflows/ci.yml`, not `tests/test_all.sh`.
**Twenty-six kernel modules and twelve `tests/*.mt` — about 9,000 lines — that
no instrument in this repository ever touched.**

Compiling all 41 by hand on 30 August gave **39 built, 2 failed**. One of the
two failures is `security/capability.mt`, which is the subject of commit
`873a0db` ("security(capability): pin the attenuate/resolve composition
order"). **A commit landed on a module that did not compile, and the repository
had no way to say so.**

This is §5's table taken one step further than that table takes it. Those rows
ask what each instrument is blind to *within* what it measures. This is a body
of code that was outside every denominator, so no instrument was blind to it —
none of them was pointed at it at all. **Fixed by `build.sh` step 1**, which
builds the kernel on both backends, and by the `--verify-ssa` gate now in CI.

### 3.7 The shape shared by all four

In every case the analyzer holds a name the code generator cannot honour, and
nothing compares the two. report.txt P60 already wrote the remedy for its own
instance — *"a registry that must agree with another registry should be checked,
not described"* — and added
`registry_tests::every_source_implemented_module_is_expanded`. **The same test
does not exist for the analyzer's builtin table against the linkable world**, and
that absence is §3.1.

---

## 4. The plan

Seven phases. Phases 0 and 1 are prerequisites for most of what follows; 5 and 6
can run in parallel with 2–4. Effort figures are working-day estimates for one
person and are least reliable in Phase 6.

### Phase 0 — Close the check-vs-link gap *(compiler work, in maniTC)*

> **DONE, 29 August 2026 — all four items.** report.txt **P85** (0.1 + 0.2),
> **P86** (0.3), **P87** (0.4). Measured against subject
> `manitc-phase0-final` sha `2a62f72bc529c679` with control `8ad91ec361a0e8d0`
> built from the same tree: 744 tests / 0 / 2, 0 warnings; parity 17/17 on six
> flag combinations; thatteOS 61/61 both halves; studioMani four binaries at
> byte-identical sizes; `--verify-ssa` 0 over 147 files; R5 0 of 327 repo and
> 2 of 1,147 corpus, both `A=0 B=1` and both programs that did not link.
>
> **Two of the four items below state their premise wrongly, and the
> corrections are the finding rather than a footnote** — see the inline notes
> on 0.1 and 0.4.

Nothing downstream is trustworthy until a clean `check` predicts a link. Four
items, smallest first.

**0.1 — Delete or implement the ~~five~~ SEVEN orphan builtins.** *(~0.5 d)*
**DONE.** *The population was five by reading and **seven** by running: `abs`
and `sqrt` are orphans too, on the same mechanism, and they are the names a
programmer reaches for first. P70's rule, a second time. Deleting was not
sufficient on its own — with the entries merely gone, `abs` was answered
**"did you mean 'main'?"**, so `stdlib_expand::qualified_spellings` now does an
exact tail match against the stdlib text the binary carries.*
Either drop the five entries from `register_builtins` so the flat spelling
becomes an honest "unknown identifier — did you mean `str::from_int`?" (which is
already the diagnostic for `str_to_lower`, and it is a good one), or make the
flat spelling trigger the same module pull-in the qualified one does. **Prefer
deleting.** The comment already standing beside `str_to_upper`/`str_to_lower` in
that table gives the reason: *"a static entry here would be a second source of
truth that can drift from the stdlib"* — it drifted for the five that were left.

**0.2 — A registry test, in the shape P60 already established.** *(~1 d)*
**DONE** — `member_list_tests::every_registered_flat_builtin_is_linkable`,
verified red with 0.1 reverted. *It asserts LLVM-linkability only, and the
reason is a number this plan understates: **ninety** registered builtins link
on LLVM and have no T3ISA syscall, not the `gui_*` surface alone — also
`fs_*` (13), `io_*` (7), `terminal_*` (4), `env_*` (3), `path_*` (3) and one
each of `net_*`, `process_*`, `shell_*`. That is §3.4's real size.*
Assert that every name in `register_builtins` is reachable at link time on both
backends: defined in `runtime/*.c`, or intercepted by an emitter, or resolvable
as a stdlib module function whose module the name pulls in. Discriminate
mechanically, not by a list. With 0.1 reverted the test must go red — verify
that, or the test is measuring nothing. This is the one item that stops §3.1
recurring.

**0.3 — Diagnose the mangled-name collision.** *(~1 d)* **DONE** — lint
`colliding-stdlib-symbol`. *Keyed on the EXPANSION, not the name, and one
shipped file is why: `manitc/tests/05_ternary_types.mt` declares `fn trit_abs`
against `trit::abs` and links today, because it never references `trit::`. A
check on the name would reject working code.*
When a user's top-level function name equals the mangled name of a stdlib
function that will be emitted, refuse it at the declaration, naming both and the
remedy — the shape report.txt **P70** used for reserved type names, including
its lint (`colliding-stdlib-symbol`, default `deny`, with an `allow` escape that
exactly restores today's behaviour). Note P70's finding while doing it: **probe
both spellings of every name**; its recorded population of nine measured
fifteen.

**0.4 — Make `use` honest.** *(~0.5 d, and it unblocks Phase 1)* **DONE** —
lint `unlinkable-user-module`. **But this item names the wrong case.**
*`use unknown_module;` was ALREADY an error (`cannot load module …`, rc=1). The
silent case is the opposite: a module that EXISTS, whose signatures register
and whose bodies are dropped. A plan item aimed at the failure that is loud,
while the quiet one wears the same words. A second mechanism was found with
it: a user-module STRUCT runs correctly on T3 and makes LLVM emit
`%struct.lib_b::Point`, which is not a legal unquoted identifier, so clang
rejects the module outright.*
Until cross-file bodies exist, `use unknown_module;` followed by a call into it
must be an **error at check time**, not a link failure. This is the cheap half
of §3.3 and it is worth doing on its own: it converts a silent failure into a
diagnostic while the expensive half is designed.

> **Instrument note for all of Phase 0.** R5 (`manitc check` verdicts over every
> `.mt` that exists) is the right instrument for 0.1/0.3/0.4 and it has a known
> confound: it compares two *compilers*, so it is valid only when the input is
> held fixed. If a change touches `stdlib/*.mt` as well as the compiler, build
> the denominator per binary (report.txt P70's R5-a/R5-b split).

### Phase 1 — One kernel, not twenty-nine demos *(~8–12 d)*

> **DONE, 30 August 2026 — 1.1 through 1.4.** The kernel is one program: 26
> modules merged from `src/kernel.manifest`, **353 functions, 35 structs, zero
> warnings**, building and running on **both** backends with **byte-identical
> output**. A second program, `build/kernel_demos` (51 modules), carries the 25
> module demonstrations and **37 assertions that used to be discarded return
> values**. `tests/test_all.sh` is **96/96** (from 61). Route (b) as
> recommended, and (a) is still the destination.
>
> **Two of this section's own claims were stale and re-probing caught both** —
> which is §7's third risk arriving on schedule:
>
> * **1.3 says "There is no `kernel_main`."** There is, and there always was:
>   `boot.mt` has had `fn kernel_main()` with `fn main() { kernel_main(); }`
>   under it. What was actually wrong is subtler and worse — `kernel_main`
>   called **boot.mt's own private stubs** of `interrupt_init`, `process_init`,
>   `vmem_init`, `syscall_init` and `tty_init`, not the real modules'. The
>   entry point existed; it just did not reach the kernel.
> * **Phase 3 says `sys_open` "allocates `new_fd` and then early-returns on a
>   full table, discarding it".** Both copies of `sys_open` put the guard above
>   the allocation already. Struck.
>
> **And a third thing this section did not know to ask for.** The kernel could
> not be built for its own target at all: `context_save` took **13** parameters
> and `context_switch` **15**, against a T3 convention that passes arguments in
> R1–R8 and has no stack argument area. LLVM has no such limit, so those
> signatures compiled and ran on the hosted backend for months while **the two
> backends disagreed about whether `kernel/context.mt` was legal**. Both now
> take a `RegFile` struct — which is the honest model anyway, since r0..r8 are
> one thing on real hardware. **The kernel builds for T3ISA.**
>
> **The Phase 6 measurement is therefore available early, and getting it right
> took crossing the ceiling first.** The kernel's T3 image first measured
> **56,421 words of 60,000** — 94 % full. Then the in-kernel assertions were
> added and it became **60,621, and the assembler refused it**. Moving the
> ENTRY POINT into its own module changed nothing, which is the finding:
> **the T3 backend emits every function in the translation unit whether it is
> reachable or not**, so the 25 demos were in the image the whole time even
> though only `kernel_main` ran. They had to leave the translation unit
> entirely — `src/demos/` and a second manifest.
>
> **The real number is therefore 37,378 words — 62 % of the ceiling, 22,622
> words of headroom.** Nineteen thousand words of that first measurement were
> demonstrations. `build.sh` prints it every build and warns above 54,000.
>
> **And a stale artefact hid the crossing.** The build failed and left the
> previous `build/kernel.t3b` on disk, and `tests/test_all.sh` reported
> **96/96 against it**. A failed build left a passing test. The suite now
> refuses to run when an artefact is older than the source it claims to be
> built from, and that guard was verified by mutation.

This is the largest single structural change and everything in §5–§6 of
`WORKINGS_ANALYSIS.md` waits on it.

**1.1 — Decide the module mechanism.** Two options, and the choice is a real
fork:

* **(a) Real cross-file compilation in maniTC.** `use kernel::process;` loads,
  type-checks and *emits* the other file's bodies. Correct destination; touches
  the driver, the analyzer's module table and both emitters' symbol handling.
  Estimate ~5–8 d in maniTC alone, and it is a maniTC deliverable, not a
  thatteOS one.
* **(b) A declared, ordered concatenation.** A manifest lists the modules in
  dependency order and the build concatenates them into one translation unit —
  which is what studioMani already does, successfully, for thirteen files. Cheap
  (~1 d), honest, and it has a real cost: one flat namespace, so `priv_name`
  defined six times becomes six redefinition errors on the first build.

**Recommendation: (b) first, then (a).** (b) forces the deduplication in §1.2
immediately and makes the kernel a single program *this week*; (a) then replaces
the manifest without changing any source. Doing (a) first means deduplicating
against a compiler feature that does not exist yet.

> **DONE — (b), 30 August 2026.** `src/kernel.manifest` lists the 26 modules in
> dependency order; `tools/merge_modules.py` concatenates them **and writes a
> line map**, so a diagnostic in the merged file can be traced back:
> `python3 tools/merge_modules.py --locate 3805 build/kernel.mt` →
> `src/mm/vmem.mt:29`. A bare `cat` would have been one line and would have
> thrown away the only thing that made the modules worth keeping apart.
>
> **The premise was re-measured, not read**: `use lib_a;` still exits 0 at
> `check` and then fails to link on *both* backends, on the release binary, on
> 30 August. (b) is still the only route.
>
> **When (a) lands, this is what changes**: `src/kernel.manifest` and
> `tools/merge_modules.py` are deleted and the modules gain `use` lines. No
> module source moves. That was the point of doing (b) first.

**1.2 — Deduplicate.** One `PCB`, one `Inode`, one `TritFS`, one `priv_name`,
one `state_name`, one `perm_name`, one `make_pcb`, one `vmem_init`. Under (b)
the compiler names every collision for you, one build at a time. **Diff the
duplicates before deleting** — `boot.mt`'s `PCB` and `scheduler.mt`'s have
different fields, so the merge is a design decision at each site, not a
deletion.

> **DONE, 30 August 2026 — 43 collisions, and the warning above was the right
> one.** A census first (kind, name, and a whitespace/comment-normalised hash
> of each body) split them into **14 byte-identical** — safe folds — and **29
> that differed**, which is where the design decisions were. The 29 fell into
> four families and each family got a different answer:
>
> * **`boot.mt` re-implemented what it boots** (8 names). It carried private
>   stubs of `interrupt_init`, `process_init`, `syscall_init`, `vmem_init` and
>   `tty_init`, plus its own `PCB`, `make_pcb`, `state_name`, `get_primary`.
>   Deleted; `kernel_main` calls the real modules. Four of the five inits had
>   an identical signature so those call sites did not move. **boot's `PCB` and
>   `make_pcb` were never referenced by anything** — declared and dead.
> * **One name, several concepts** — renamed, not merged. `perm_name` was
>   defined five times and meant **three different things**: the fs layer's
>   permission bits (`"rwx"`), `kernel/tmin2.mt`'s memory-zone class, and
>   `mm/pgtable.mt`'s two-argument page-fault *action*. Now `perm_name`,
>   `zone_name`, `pgfault_action`. Likewise `check_address_privilege` (an int
>   pair vs a trit triple → `priv_check_address` and the original), and
>   `empty_entry`/`print_entry`, which were a **log record** in `kernel/klog.mt`
>   and a **photon grant** in `security/photon_cap.mt` sharing only the English
>   word "entry" → `klog_*` and `photon_*`.
> * **`PCB` was a UNION, not a copy.** The three definitions held *different
>   fields*: `kernel/process.mt` knew a process's identity and privilege,
>   `kernel/scheduler.mt` knew its priority, age and quantum. Choosing either
>   would have silently discarded three fields of the other, so the merged PCB
>   carries all ten — and every literal that built one was rewritten as
>   `PCB { ..p, ... }`, because the union broke all seven spelled-out literals
>   at once and an update expression cannot forget a field.
> * **`fs/tritfs.mt` had 28 declarations and NOT ONE of its own.** Every name
>   in it also existed in `inode.mt`, `fdtable.mt` or `perms.mt`. It was not a
>   layer above the three, it was a copy of all three taken before they were
>   split out. **The copies had drifted and not harmlessly**: its `create_file`
>   and `sys_mkdir` wrote a new inode into slot 6, 7, or — for every other
>   value of `next_ino`, including 0 through 5 — **slot 8**. `inode.mt`'s
>   delegate to `inode_set`, which handles all nine. 27 declarations deleted;
>   the file keeps `tritfs_demo`, which is what it uniquely had.
>
> **Every deletion left a note saying where the declaration went.** Deleting
> silently is how a reader later concludes the module never had the function.

**1.3 — `kernel_main`.** **DONE — but see the banner above: `kernel_main`
already existed.** The 25 non-boot module `main`s became `tmin2_demo()`,
`klog_demo()`, … — *renamed, never deleted*, because those 25 demos are the
only exercise most of this code has ever had, and deleting them to make the
merge compile would have bought one program at the price of the only evidence
the parts work. All 29 files in `src/` carry a `fn main`; three of them
(`userspace/init`, `login`, `shell`) should keep one. Strip the other 26, keep one
in `boot.mt`. It calls `interrupt_init`, `process_init`, `vmem_init`,
`syscall_init`, `tty_init`, `tritfs_init`, `timer_init`, then `scheduler_run`.
Each module's demo `main` becomes a `*_demo()` the test suite calls, so the
demos survive as tests rather than being deleted.

**1.4 — Build the three orphaned userspace programs.** **DONE.** *All three
compile, link and run; `PROGRAMS` is 13 and `tests/test_all.sh` gained 22 rows
for them. The one-line fix was not taken on its own, because it repairs the
instance and leaves the mechanism: `userspace/build.sh` now **checks its list
against the directory** in both directions, and `tests/test_all.sh` **refuses
to run a partial suite** rather than skipping — its `[ -x ]` guards silently
dropped 34 of 61 checks and printed ALL TESTS PASSED. All three guards were
verified by mutation. Two of the three programs also computed a verdict and
threw it away — `stream_demo` bound three `stream_read` results it never read,
`security_demo` captured `ring_before` to prove a denied escalation left the
ring alone and never compared. Both now state the claim beside the answer.* `security_demo`,
`stream_demo` and `sysinfo` exist, **all three compile and link cleanly today**,
and `userspace/build.sh`'s `PROGRAMS` list simply never named them. One line.
Then add their tests — and note the shape, because it is P42's: *a list that
omits an input converts an unexercised program into a smaller green number.*

### Phase 2 — Connect the subsystems *(~6–8 d, needs Phase 1)*

> **DONE, 30 August 2026 — 2.0 through 2.5.** The kernel's four subsystems now
> reach each other over one process table. `tests/test_all.sh` is **100/100**
> (from 96) with **98 in-kernel assertions** (from 37), both backends
> byte-identical, `--verify-ssa` 0 over 28 files, 0 warnings, T3 image
> **39,829 words of 60,000**.
>
> **2.2 was struck rather than implemented** — the remedy it prescribes was
> already in the code, and the item named a function (`check_and_wake`) that
> does not exist. **2.0 is new and was the reason the other four were stuck.**
> **2.1's prescribed fix was wrong twice** and is recorded in place.
>
> **Three things this phase learned the hard way, all measured:**
>
> * **A struct is a mutable reference; a struct RETURNED from a function is a
>   copy.** `f(t.p0)` writes through, `f(at(t,1))` does not, and
>   `at(t,0).age = 7` is discarded. The first table used an accessor for writes
>   and three assertions caught it while a fourth passed for the wrong reason.
> * **`ProcTable` holds nine NAMED PCB fields, not `slots: [PCB]`.** The array
>   version is correct on hosted and corrupts on T3 inside the kernel — count
>   short, pids garbage, then a trap storing through one of them. Not heap
>   (twelve fresh PCBs allocate at the point of failure), not the shared free
>   slot, not the mutating call, and not reproducible in any standalone program
>   built to the same shape. `SleepQueue` has always been nine named fields;
>   this now matches it, and the reason is written down beside the struct.
> * **The T3 heap is the binding constraint on this kernel, not the image.**
>   PCB gained a CapWord for 2.3 and roughly doubled; admitting nine processes
>   at boot then exhausted 2,536 words. Boot admits the **two** processes it
>   actually creates, and the nine-state coverage moved to the demo program,
>   which is hosted-only and spends no such budget.

The kernel's parts are individually sound and mutually unaware.

> **RE-PROBED 30 August 2026, before implementing any of it, as §7 instructs.
> One of the five items was already done, one prescribes a change that would
> make things worse, and the four that remain share a prerequisite this section
> never named.** The probe was `grep` and `awk` over `src/`, plus a positive
> control; the results are folded into the items below.
>
> **The shape they share: the kernel NARRATES what it would do.** Four sites
> print `-> scheduler_run() invoked` — `kernel/privilege.mt:93`,
> `kernel/timer.mt:207`, `kernel/panic.mt:149`, `mm/vmem.mt:120` — and
> `scheduler_run`, which exists at `kernel/scheduler.mt:211`, is called from
> **none** of them. `deliver_signal` prints "save context, jump to handler
> address" and returns `void`. `enforce` is called only from its own demo.
> This is Phase 1's finding one level in: there, `kernel_main` existed and
> called `boot.mt`'s private stubs rather than the real modules; here the
> subsystems exist and address each other in `io::println`.

* **2.0 A PROCESS TABLE THAT OUTLIVES A CALL — unnamed here, and 2.1/2.3/2.4/2.5
  all block on it.** `scheduler_run()` takes no arguments, returns nothing, and
  **builds its own hardcoded nine-PCB table as a local `let mut pcbs`** on every
  call, ages it, schedules it and discards it. `process_init()` beside it prints
  a description of a table and initialises none. So there is no process table in
  this kernel — there are two functions that each pretend to have one.
  Consequences for the items below: 2.1 cannot hand the scheduler anything,
  2.3's `CapWord` has no PCB field to live in (`struct PCB` carries pid, state,
  pc, sp, privilege, page_table, parent_pid, priority, age, quantum_used — and
  no capability), and 2.4 has nothing to set `process.state` *in*. Do this
  first, or the rest is more narration. *(estimate not carried over from the
  items below — this is new work)*
* **2.1 Timer → scheduler.** Confirmed as a gap, but **the fix as prescribed is
  wrong twice.** (a) `gui_ticks()` does not appear in `src/` at all — it is the
  SDL2 frame-loop convention from `userspace/` and studioMani, and the kernel is
  not a frame loop. (b) Calling `scheduler_run` on quantum expiry today would
  invoke the function described in 2.0, which fabricates a fresh fake table and
  throws it away: the output would look like scheduling while the timer's actual
  state went nowhere. **That is worse than the honest `println` it replaces.**
  Blocked on 2.0. *(~1 d after it)*
* **2.2 Fix the sleep queue. — STRUCK 30 August 2026. THE REMEDY WAS ALREADY
  IMPLEMENTED.** This item was carried from `WORKINGS_ANALYSIS.md` §4.3 with the
  warning "re-probe before fixing"; re-probing found: **there is no
  `check_and_wake`** anywhere in `src/`. The function is
  `kernel/timer.mt:146 wake_entry_if_due`, and it already returns
  `SleepEntry { .., valid: false }`; `timer_tick` already returns the cleaned
  queue in a `TickResult` and already decrements `count` by the number it
  invalidated. The prescribed fix — "return the updated `SleepQueue`" — is what
  the code does.
  **But nothing pinned it, and the demo was actively misleading:**
  `src/demos/timer.mt` had **zero assertions** and closed by printing five
  hardcoded `PASS` lines. It now carries **20 assertions**, every expected value
  derived from the source rather than from the program's output, and they bite:
  reintroducing exactly the defect this item describes — `wake_entry_if_due`
  returning the entry without clearing `valid` — turns **7 of the 20 red**,
  where before the whole defect was invisible. Demo assertions 37 → 57.
  *(0 d — the cost was the probe, and the probe is what found 2.0)*
* **2.3 Capability enforcement.** **Confirmed.** `security/capability.mt:273
  enforce(cap, required_cap, syscall_name) -> bool` is called from nine sites,
  **all nine in `src/demos/capability.mt`** and none in a syscall. This item's
  own stated prerequisite is also confirmed: `PCB` has no `CapWord` field.
  Blocked on 2.0. *(~2 d after it)*
* **2.4 Signal delivery.** **Confirmed.** `kernel/signal.mt:179 deliver_signal`
  returns `void` and its three dispositions print `CATCH:` / `DEFAULT:` /
  `IGNORE:`; the catch arm prints "save context, jump to handler address" and
  does neither. Called from five sites, all in `src/demos/signal.mt`.
  Blocked on 2.0 (nothing to set `state` in). *(~2 d after it)*
* **2.5 Interrupt → syscall → scheduler** as one event-driven loop. This is 2.0
  finished rather than a separate item: once the table is threaded, the loop is
  what threads it. *(~2 d)*

### Phase 3 — TritFS with real storage *(~4–6 d)*

> **DONE, 30 August 2026, and it is SPLIT IN TWO because of a measurement.**
> The permission mapping is written down first, as this section asks
> (`src/fs/perms.mt`, with `perm_to_unix`/`unix_to_perm` and eight assertions
> pinning it). `sys_read`/`sys_write` became `sys_read_data`/`sys_write_data`:
> they resolve the fd to its inode, **check the permission**, and move real
> bytes. `check_permission` had no caller outside its own demo before this —
> §2.3's shape again.
>
> **The `fs_*` half is HOSTED ONLY, in `src/fs/hosted_store.mt`, listed in
> `kernel_demos.manifest` and deliberately not in `kernel.manifest`.** §3 says
> the `fs_*` builtins "already exist and already work"; measured, they work on
> **LLVM only** — the same program compiled `--target t3` dies with
> `Undefined label: fs_mkdir`. That is §3.4's finding in the filesystem: ~90
> registered builtins are declared in the analyzer, implemented in the C
> runtime, and have no T3ISA syscall. `build/kernel` must build for both
> backends and produce byte-identical output, so one `fs_read_file` the kernel
> can reach stops it building for its own target.
>
> So: the kernel gets **real data movement on both backends** (in-memory,
> permission-checked); the demo program gets **real durability** — a genuine
> file under `/tmp/thatteos_tritfs/`, flushed, the inode cleared, and reloaded
> from disk, which is what the six `store:` assertions check. **Phase 6(a) is
> what would remove the split.** Until then "TritFS has real storage" is true
> of the hosted kernel and false of the T3 target.
>
> **The `sys_open` sub-item below was already struck during Phase 1** (both
> copies put the guard above the allocation); the line survives here because
> nobody deleted it, and it is struck again now.
>
> Two things found while doing it: the four remaining bare `Inode` literals all
> broke at once when the struct gained `content` (they now go through
> `make_inode`), and **the fdtable demo was opening inode 7, which no one had
> created** — a fresh TritFS leaves 6, 7 and 8 empty at r-x, so the write it
> asserted was being correctly refused. Suite **102/102**, in-kernel assertions
> **132** (from 37 before Phase 2).

`sys_read`/`sys_write` return byte counts without touching data. In hosted mode,
back inodes with real files under a root directory and route the four operations
through the `fs_*` builtins that already exist and already work. The permission
model is the interesting part and should not be flattened: **three-valued
permissions are the design claim**, so the mapping to Unix bits needs writing
down before it is coded, not after.

Also: `sys_open` allocates `new_fd` and then early-returns on a full table,
discarding it. Move the guard above the allocation.

### Phase 4 — One shell *(~3–4 d, needs Phase 1)*

> **DONE, 30 August 2026 — and "make them one binary" is the wrong goal, by
> measurement.** `thatteos.mt` uses `fs_copy`, `fs_list_dir_open`,
> `process_spawn`, `path_join` and `env_timestamp`; compiled `--target t3` it
> fails at the assembler with `Undefined label: env::os_name`. It drives the
> HOST filesystem and cannot run on the machine this kernel targets. So the two
> are not two implementations of one thing.
>
> **What was real duplication is gone.** `src/userspace/shell.mt` was in
> NEITHER manifest — 438 lines compiled by nothing — and is now in both. Its
> `priv_name` had drifted from `kernel/privilege.mt`'s ("KERNEL" vs
> "KERNEL(+1)") precisely because nothing ever compiled them together; that is
> the seventh instance of the six Phase 1.2 deduplicated, and the flat
> namespace is what asked the question.
>
> **One tokeniser, from the hosted shell as this section asks.** The kernel
> shell had two parsing strategies: whole-string equality for nine commands,
> and `str::starts_with` plus `args_after(cmd, 5)` for four — a helper that
> takes the length of its own keyword as an argument and is silently wrong for
> any verb that is not four letters. Both are replaced by trim / find-first-
> space / name+args, and `args_after` is deleted.
>
> **And the "syscall-backed command bodies" were not backed by anything.**
> `ps` printed five invented processes and "Total: 5/9" whatever the kernel was
> doing; `kill` printed "signal delivered via SYS_KILL" and called nothing;
> `stat` matched four path literals and reported `size: 0` for all of them.
> They now walk the §2.0 process table, call the §2.4 `sys_kill`, and look the
> path up in the §3 filesystem.
>
> **The finding is from an assertion that failed:** `kill 3 -2` does NOT
> terminate PID 3, because the shell runs as pid 2 at USER(-1) and `sys_kill`
> lets a USER process signal only itself. The refusal is the more interesting
> row, and it is paired with a self-signal that succeeds so the row is about
> the target rather than about `kill` being inert. Suite **102/102**,
> assertions **140**, 26 demos.

There are two. `thatteos.mt` (1,064 lines) is the real one: it reads stdin,
splits verb from arguments at the first space, and dispatches 29 arms into 28
command functions, 17 of which take arguments. `src/userspace/shell.mt` (438 lines) is the kernel-side
demo: eight hardcoded string literals, no arguments. Keep the hosted shell's
input loop and tokeniser, keep the kernel shell's syscall-backed command bodies,
delete the literals. Add pipes once `ipc/pipe.mt` is wired.

### Phase 5 — studioMani from drawn to working *(~8–10 d, parallel)*

> **RE-PROBED 30 August 2026, AND THIS SECTION IS STALE IN FOUR OF ITS SIX
> ITEMS.** "The UI is complete and the backends are stubs" was true when it was
> written and is not true now.
>
> * **5.1 Ctrl+S — ALREADY DONE.** `main.mt:418` is
>   `if k == gui_key_s() { fs_write_file(cur_file, buf_text(buf)); dirty = 0; }`,
>   and `fs_write_file` appears at nine sites (save-on-quit, save-before-open,
>   save-before-switch). The editor has been able to save for some time.
> * **5.2 Ctrl+Z — ALREADY DONE; Ctrl+Y WAS THE REAL GAP, and is now done.**
>   `buffer.mt`'s header has read "gap buffer, cursor navigation, undo/redo"
>   since it was written while the file provided `undo_push`, `undo_pop` and
>   `undo_stack_without_last` and nothing else — no redo stack, no Ctrl+Y arm.
>   A documentation claim outliving its implementation, the shape report.txt
>   P51/P55 already track. The three helpers are generic over a stack string,
>   so redo needed no new buffer code: a second stack, push-before-restore on
>   undo, and **clearing the redo stack on a fresh edit** — without which
>   Ctrl+Z, a keystroke, then Ctrl+Y restores a future the keystroke replaced.
> * **5.3 Selection and Ctrl+F — ALREADY DONE.** `find_next` at `main.mt:393`,
>   `buf_replace_all` at 405, Ctrl+H for replace at 367, `sel_anchor`
>   throughout. The find bar searches.
> * **5.4 Terminal tab — ALREADY DONE.** `shell_exec` at `main.mt:651` with
>   command history (`term_hist`, up/down navigation).
> * **5.5 Email — GENUINELY OPEN, and it is the only item here that was.**
>   `net_imap_connect`, `net_imap_list`, `net_imap_fetch` and `net_smtp_send`
>   are absent from the compiler — probed directly, not inferred. **NOT DONE
>   HERE**: it is C-runtime work inside maniTC, whose tree is currently shared
>   with another session, and landing it would move the compiler this
>   repository's build is pinned against in the middle of a campaign.
> * **5.6 Split `main.mt` — NOT DONE, and the reason is this section's own
>   sequencing rule.** It says "do it after 5.1–5.4, not before — splitting a
>   file and changing its behaviour in one step makes both unreviewable."
>   5.2's redo half changed behaviour in `main.mt` today. The split is a
>   mechanical refactor with no behaviour change and it should be its own step,
>   against a tree where the last behavioural change is already verified.
>
> The lesson is the one §7 records about `WORKINGS_ANALYSIS.md`, arriving in a
> section of this document: **re-probe before implementing.** Four of six items
> here would have been re-implementations of working code.

The UI is complete and the backends are stubs. Everything below is now
*unblocked* — §2 shows the stdlib gaps closed.

* **5.1 Ctrl+S.** `fs_write_file` exists. The editor cannot save. *(~1 d)*
* **5.2 Ctrl+Z / Ctrl+Y.** `buffer.mt` is a real gap buffer; it needs a history
  stack. *(~2 d)*
* **5.3 Selection and Ctrl+F.** `gui_key_mod_shift` and the arrow keys exist; the
  find bar is drawn and searches nothing. *(~2 d)*
* **5.4 Terminal tab.** `process_spawn` exists; live output streaming does not.
  *(~2 d)*
* **5.5 Email.** The one genuine stdlib gap: `net_imap_connect`, `net_imap_list`,
  `net_imap_fetch`, `net_smtp_send`. They are C-runtime work against libcurl,
  which is already linked. *(~3 d, in maniTC)*
* **5.6 Split `main.mt`.** 974 lines, with every tab's mouse and keyboard logic
  inlined in one `main()`. The split in `WORKINGS_ANALYSIS.md` §2.1 is a good
  one. **Do it after 5.1–5.4, not before** — splitting a file and changing its
  behaviour in one step makes both unreviewable.

### Phase 6 — The T3ISA half *(~10–15 d, least certain)*

> **THE MEASUREMENT THIS SECTION ASKS FOR IS DONE, 30 August 2026, AND IT
> SPLITS THE FORK IN TWO.** This section says "Measure first: compile the
> merged IDE with `--target t3` and read the reported image size." Doing that
> did not reach the image size: the build failed in the CODE GENERATOR.
>
> ```
> [T3ISA] `draw_sidebar` takes 12 parameters, but the T3 calling convention
> passes arguments only in R1-R8 and has no stack argument area.
> ```
>
> That is Phase 1's `context_save`/`context_switch` finding again — LLVM has no
> argument limit, so these signatures compiled and ran hosted for months while
> the two backends disagreed about whether the module was legal. **The
> population was measured, not guessed: FIVE functions in the whole repository
> exceed eight parameters, all five studioMani draw functions** (`draw_email`
> 13, `draw_sidebar` 12, `draw_browser` 12, `draw_explorer` 11, `draw_pane`
> 10). `src/`, `userspace/` and `thatteos.mt` are clean. All five now take
> parameter-group structs — `View`, `CtxMenu`, `NavState`, `Compose`,
> `PaneRect` — which are groupings the drawing code already passed around
> together, not arbitrary bundles to get under a limit.
>
> **With that fixed, the numbers are:**
>
> | target | `--target t3` |
> |---|---|
> | studioMani IDE (13 modules merged) | **75,160 words against a 60,000 ceiling — 25 % over** |
> | browser (290 lines) | reaches the assembler; `Undefined label: gui_set_color` |
> | email (370 lines) | reaches the assembler; `Undefined label: gui_set_color` |
> | filemanager (411 lines) | reaches the assembler; `Undefined label: gui_set_color` |
>
> **So the fork below is wrong as posed, and the recommendation with it.** (a)
> is not "expensive but sufficient": the three standalone apps are blocked
> ONLY by the missing `gui_*` syscalls and (a) would finish them, but **the IDE
> is 25 % over the image ceiling before any syscall work exists**, and that is
> a different limit. Implementing forty syscalls would leave a program that
> still cannot be loaded.
>
> The IDE therefore needs (a) **and** one of: the memory-map change
> (maniTC report.txt P77 — measured and DECLINED, because a bump allocator with
> no free exhausts any bound and moving the map postpones rather than removes
> the limit), or splitting the IDE so that no single translation unit carries
> all thirteen modules. **The cheap, real win available today is (a) for the
> three standalone apps**, which is a much smaller claim than "thatteOS runs on
> T3ISA" and is one that would actually be true.

§3.4 is a fork, and it should be decided explicitly rather than by drift:

* **(a) Implement `gui_*` as T3 syscalls.** ~40 builtins, each needing an
  emitter arm and an emulator handler bridging to SDL2. Real work, and it makes
  the claim "thatteOS runs on T3ISA" true of the whole system.
* **(b) Declare the GUI hosted-only** and say so in the reference and the build
  scripts. Cheap, honest, and it concedes that the flagship application is a
  Linux program.

**Recommendation: (a), but not yet** — after Phase 1, because a kernel that is
one program is the thing worth running on T3ISA, and after the memory-map work,
because report.txt P38/P63/P76 record the T3 image ceiling at 60,000 words with
a 2,536-word heap and a stack that grows down into the code. A 3,355-line IDE is
not obviously under those limits, and that is measurable before any of (a) is
written. **Measure first: compile the merged IDE with `--target t3` after 0.1 is
in and read the reported image size.**

### Phase 7 — Bare metal *(Target B/C, not scheduled)*

> **NOT DONE, and not attempted — 30 August 2026.** This is the one phase whose
> own text says it "is a multi-month project and it should not start until
> Phases 1–3 have made the hosted OS one program that actually schedules,
> allocates and reads files". Phases 1, 2 and 3 are now done, so the
> precondition is met and the reason it is still not started is the work
> itself: Target B needs an **`x86-64-bare` codegen target in maniTC** — a
> third backend beside LLVM and T3ISA — plus a bootloader, APIC init,
> context-switch stubs and a physical memory manager. None of that is
> thatteOS source; nearly all of it is compiler work.
>
> One thing Phase 6's measurement contributes to it: the T3 image ceiling and
> the 2,536-word heap are properties of the **emulator's memory map**, not of
> a bare-metal target, so the size limits that bind Phase 6 do not
> automatically bind Phase 7.

`baremetal/ANALYSIS.txt` sets out Targets A, B and C and its gap analysis is
sound. Target B (QEMU) needs an `x86-64-bare` codegen target in maniTC, a
bootloader, APIC init, context-switch stubs and a physical memory manager. It is
a multi-month project and it should not start until Phases 1–3 have made the
hosted OS one program that actually schedules, allocates and reads files —
because those are the pieces Target B would otherwise be porting in stub form.

---

## 5. What the test suite can and cannot see

Worth stating before the phases begin, because three of this project's sharpest
findings were about instruments rather than code.

| Instrument | Denominator | Blind to |
|---|---|---|
| `tests/test_all.sh` — 61 checks | curated | anything with no test; **and 34 of the 61 vanish silently if `userspace/bin/` is empty** |
| `manitc check` over the tree | every file | **linkability** — all four mechanisms in §3 |
| Cross-backend parity | 17 maniTC examples | a shared lowering shares its bugs (report.txt P58: parity was blind to four of ten probe findings) |
| `--verify-ssa` | every `.mt` | ~~operand types (P46)~~ — **it does not check operand types at all**, and 30 Aug proved it: it reported **0 violations twice** on a module clang then refused for a phi whose operands were the wrong width (§3.5). It verifies SSA *form* — dominance, multiply-defined, dangling targets, phi edges. **Now run in CI over all 27 files**, which is worth doing for what it does check (it found P37); just not for this |

Three additions, cheap and each closing a named gap:

1. ~~**Run `--verify-ssa` over every `.mt` in this repository, in CI.**~~
   **DONE 30 Aug** — `.github/workflows/ci.yml`, 27 files, 0 violations.
2. ~~**Assert a link, not a check.**~~ **DONE 30 Aug for `src/` and
   `userspace/`**, which is where it mattered: `build.sh` builds the merged
   kernel on both backends and `userspace/build.sh` builds all 13 programs, so
   CI now links what it used to only check. `studioMani/` remains hosted-only
   by §3.4. **Note what this cost to learn**: the per-module sweep that found
   the two broken files is no longer a valid instrument, because the modules
   are no longer standalone programs — they have no `main` and they call each
   other. The unit of compilation is `build/kernel.mt`, and that is what CI
   builds.
3. **Print the claim beside the answer.** `tests/expected/` in maniTC gets its
   value from every line stating its own claim (`PASS mul: 6*7=42`) rather than
   being captured output. It is the cheap design that makes a pinned expectation
   non-self-derived; thatteOS's tests should follow it.

---

## 6. Sequencing

```
Phase 0  ──┬─► Phase 1 ──┬─► Phase 2 ──► Phase 3 ──► Phase 4
           │             │
           │             └─► Phase 6 (after an image-size measurement)
           │
           └─► Phase 5   (parallel; only 5.5 needs maniTC)
                              Phase 7 — after 1–3
```

Phase 0 is ~3 days and gates everything. Phase 1(b) is ~1 day of build work plus
the deduplication it forces. **The first week's honest goal is: a clean `check`
means a link, the kernel is one program, and three more userspace binaries
exist.**

---

## 7. Risks

* **maniTC is under active concurrent development.** HEAD moved once during the
  writing of this document. Phase 0 and 5.5 are maniTC changes and will land in
  a tree someone else may be editing. Pin the binary by sha before measuring,
  check it after, and read `git log` before assuming anything about HEAD.
* **Phase 1(b) makes the namespace flat.** Six `priv_name`s become six errors at
  once. That is the point, but it is a day where nothing builds.
* **`WORKINGS_ANALYSIS.md` is stale in five of ten blocking claims.** Re-probe
  every item before implementing it. This project has lost five weeks to a
  recorded finding that had already been repaired (report.txt P52).
* **Two merged documents are deliberately unpublished.** `baremetal/ANALYSIS.txt`
  names the target hardware device, asserts a security primitive is novel, and
  refers to the modules' patent claims; `CLAUDE.md` states the device's
  signalling mechanism. This is a public repository and `CLAUDE.md` rule 8 defers
  such disclosure until the PCT filing is secured (~Mar 2027), so both are listed
  in `.gitignore` with the reason written beside them. **They remain in the
  working tree** — nothing was deleted, and Phase 7 still reads
  `baremetal/ANALYSIS.txt` locally. The decision was taken at the push rather
  than after it, because GitHub content is indexed and cached and removing a file
  later does not unpublish it.

---

## 8. What this plan does not cover

* **Nothing was committed.** Both repositories carry the merge as working-tree
  changes, per this project's convention.
* **No maniTC source was edited.** Phase 0 is specified, not implemented — a
  concurrent session held eight modified files in that tree throughout, and
  committed them as `91472d6` mid-session.
* **`net_imap_*` / `net_smtp_send` remain unimplemented**, and `email.mt` still
  says so on its own screen. That is the correct state under `CLAUDE.md` rule 7.
* **The three-valued permission mapping is not designed here**, only flagged as
  needing design before code.

© Manish Jagdish Thatte
