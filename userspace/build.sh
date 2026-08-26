#!/usr/bin/env bash
# thatteos/userspace/build.sh — compile all thatteOS userspace programs
#
# Usage (from the thatteos repo root):  bash userspace/build.sh
#
# Compiles each .mt program in userspace/ to a native binary in userspace/bin/.
#
# ONE STEP, for the reasons `../build.sh` sets out at length (23 August 2026).
# It used to be three — emit .ll, sed-patch the IR, hand-link against a full
# manit_runtime.o — and this script kept all three after the sibling deleted
# them, so it had not built since 10 August 2026 (report.txt P42):
#
#   * maniTC now compiles a growing part of the stdlib from ManiT SOURCE, and a
#     ManiT function keeps its mangled name — `str::to_lower` is `@str_to_lower`,
#     the symbol the C runtime also defines. The compiler handles the collision
#     (it omits the runtime's declare for anything the module defines and builds
#     the runtime object with matching flags); a hand-link does not, and this
#     one died with "multiple definition of str_to_lower" and fifteen more.
#   * The sed patch matched nothing: maniTC emits `ret ptr null` today.
#
# Nothing noticed because `tests/test_all.sh` GUARDS every userspace test on the
# binary existing, so a missing bin/ makes 34 of its 61 tests vanish and the
# remaining 27 report "ALL TESTS PASSED". The stale binaries in bin/ kept it
# quiet instead — 16 days of tests running a compiler nobody was changing.
#
# Author: Manish Jagdish Thatte

set -e
cd "$(dirname "$0")/.."

MANITC="${MANITC:-../manitc/target/release/manitc}"
USRDIR=userspace
BINDIR=userspace/bin

# No CLANG, no runtime object and no pkg-config here any more. maniTC links the
# binary itself and does its own SDL2/libcurl detection for the GUI and network
# builtins, and it is the only party that knows which runtime symbols the module
# already defines. Duplicating a compiler's link logic in a shell script is how
# it drifts; delegating is how it stops. ../build.sh says the same at length.

mkdir -p "$BINDIR"

PROGRAMS="calc tritdump fib caps_demo ipc_demo fm browser editor gui_fm gui_browser"
TOTAL=$(echo $PROGRAMS | wc -w)
N=0

for prog in $PROGRAMS; do
    N=$((N + 1))
    src="$USRDIR/${prog}.mt"
    bin="$BINDIR/${prog}"

    # `-o` WITHOUT a .ll extension is what makes this link: maniTC reads a .ll
    # output path as "emit IR, do not link", which is why the old three-step
    # form's first command always succeeded and said nothing about whether the
    # program would link.
    echo "[$N/$TOTAL] $prog — compile and link ${prog}.mt → bin/${prog}"
    "$MANITC" compile --target llvm "$src" -o "$bin"
    echo "  ok"
done

echo ""
echo "=== userspace build complete ==="
echo "  binaries in: $BINDIR/"
ls -1 "$BINDIR/"
echo ""
echo "  run individually, e.g.:"
echo "    $BINDIR/calc"
echo "    $BINDIR/fib"
echo "    $BINDIR/fm              # file manager (full-screen TUI)"
echo "    $BINDIR/browser         # text web browser"
echo "    $BINDIR/editor  <file>  # TUI text editor"
echo "    $BINDIR/gui_fm          # graphical file manager (SDL2)"
echo "    $BINDIR/gui_browser     # graphical web browser  (SDL2)"
echo "    echo 'hello.txt' | $BINDIR/tritdump"
