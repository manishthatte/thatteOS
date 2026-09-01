#!/usr/bin/env bash
# studioMani/build.sh — build the studioMani IDE and its three standalone apps
#
# Usage (from anywhere):
#     bash studioMani/build.sh
#     MANITC=/path/to/manitc bash studioMani/build.sh   # custom compiler
#     WITH_T3=1 bash studioMani/build.sh                # also try the T3ISA target
#
# ONE STEP PER TARGET, for the reasons ../build.sh and ../userspace/build.sh set
# out at length (23 August 2026). This script kept the three-step form — emit
# .ll, compile runtime/manit_runtime.c to an object, hand-link the two with
# clang — after both siblings deleted it, and all three steps had rotted the
# same way:
#
#   * maniTC compiles a growing part of the stdlib from ManiT SOURCE now, and a
#     ManiT function keeps its mangled name — `str::to_lower` is `@str_to_lower`,
#     which is also what the C runtime calls its own. maniTC handles the
#     collision (it omits the runtime's declare for anything the module itself
#     defines, and compiles the runtime object with matching flags). A hand-link
#     does neither and dies with "multiple definition of str_to_lower".
#   * `link_binary` read `$OUT/studioMani.ll`, a file the compile step above it
#     only writes when the output path ends in .ll — which it did not.
#   * SDL2/libcurl detection was duplicated here; maniTC does its own pkg-config
#     probe and is the only party that knows which runtime symbols the module
#     already defines.
#
# THE T3ISA TARGET IS OFF BY DEFAULT AND THAT IS A MEASUREMENT, NOT A
# PREFERENCE. Every `gui_*` builtin is declared in the analyzer and implemented
# in runtime/gui.c against SDL2; NONE of them has a T3ISA syscall. A GUI program
# therefore type-checks, writes its .t3s, and dies in the assembler with
# "Undefined label: gui_init" — exit 1, no .t3b. The `output/*.t3s` files this
# repository inherited are that partial product: assembly written, assembly
# never assembled. Set WITH_T3=1 to watch it happen; the failure is reported and
# does not stop the hosted build.
#
# Author: Manish Jagdish Thatte

set -e
cd "$(dirname "$0")"

# The sibling checkout may be called maniTC (the repository name `git clone`
# produces) or manitc (the crate name older checkouts use). Linux filenames are
# case-sensitive, so try both and let MANITC override entirely.
if [ -z "$MANITC" ]; then
    for d in ../../maniTC ../../manitc; do
        if [ -x "$d/target/release/manitc" ]; then
            MANITC="$d/target/release/manitc"
            break
        fi
    done
fi
if [ -z "$MANITC" ] || [ ! -x "$MANITC" ]; then
    echo "error: the manitc binary was not found in ../../maniTC or ../../manitc" >&2
    echo "build it first:  git clone https://github.com/manishthatte/maniTC && cd maniTC && cargo build --release" >&2
    echo "or point at it:  MANITC=/path/to/manitc bash studioMani/build.sh" >&2
    exit 1
fi

OUT=output
mkdir -p "$OUT"

echo "=== studioMani build ==="
echo "compiler: $MANITC"
echo ""

# -- Main IDE -----------------------------------------------------------------
# The modules are concatenated because ManiT has no cross-file bodies: `use`
# registers signatures, and every function body a program calls must be in the
# translation unit. Order matters — a callee must precede nothing in particular,
# but a struct must precede its first use, so this list is the dependency order.
#
# The merged file is written into output/ rather than /tmp: it is the actual
# translation unit every diagnostic will name, and a line number is worthless if
# the file it points into has been overwritten by the next build (or by another
# user, /tmp being shared).
MERGED="$OUT/studioMani_merged.mt"
echo "[1/4] studioMani IDE — merging 13 modules → $MERGED"
cat studioMani/theme.mt \
    studioMani/layout.mt \
    studioMani/buffer.mt \
    studioMani/highlight.mt \
    studioMani/dialogs.mt \
    studioMani/sidebar.mt \
    studioMani/editor.mt \
    studioMani/explorer.mt \
    studioMani/browser.mt \
    studioMani/email.mt \
    studioMani/terminal.mt \
    studioMani/palette.mt \
    studioMani/state.mt \
    studioMani/titlebar.mt \
    studioMani/frame.mt \
    studioMani/events_quit.mt \
    studioMani/events_key.mt \
    studioMani/events_text.mt \
    studioMani/events_mouse.mt \
    studioMani/events_wheel.mt \
    studioMani/main.mt > "$MERGED"

build_hosted() {
    local label="$1" src="$2" out="$3"
    # NOTE the output name has no .ll suffix. maniTC reads a .ll output path as
    # a request for IR only and skips linking entirely, which is exactly how the
    # previous version of this script appeared to succeed while producing
    # nothing linkable.
    echo "      compiling and linking $src → $out"
    "$MANITC" compile --target llvm "$src" -o "$out"
}

build_t3() {
    local src="$1" out="$2"
    if [ "${WITH_T3:-0}" != "1" ]; then return 0; fi
    echo "      T3ISA: $src → $out  (expected to fail at the assembler; see header)"
    if "$MANITC" compile --target t3 "$src" -o "$out"; then
        echo "      T3ISA: ok"
    else
        echo "      T3ISA: FAILED (exit $?) — no .t3b produced"
    fi
}

build_hosted "studioMani" "$MERGED" "$OUT/studioMani"
build_t3 "$MERGED" "$OUT/studioMani.t3b"

echo "[2/4] browser"
build_hosted "browser" browser/browser.mt "$OUT/sm_browser"
build_t3 browser/browser.mt "$OUT/sm_browser.t3b"

echo "[3/4] email"
build_hosted "email" email/email.mt "$OUT/sm_email"
build_t3 email/email.mt "$OUT/sm_email.t3b"

echo "[4/4] filemanager"
build_hosted "filemanager" filemanager/fm.mt "$OUT/sm_fm"
build_t3 filemanager/fm.mt "$OUT/sm_fm.t3b"

echo ""
echo "  done.  binaries in $OUT/"
echo "  run:   ./$OUT/studioMani   ./$OUT/sm_browser   ./$OUT/sm_email   ./$OUT/sm_fm"
