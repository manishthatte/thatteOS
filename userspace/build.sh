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

# The ORDER is presentation order; the CONTENT is checked against the directory
# immediately below, because this list omitting a file is not hypothetical — it
# omitted security_demo, stream_demo and sysinfo, all three of which compiled
# and linked cleanly the whole time. Nothing failed; three programs simply were
# not built, and `tests/test_all.sh` then had no binary to test them with. That
# is report.txt P42's shape: a list that omits an input converts an unexercised
# program into a smaller green number. Adding the three names would have fixed
# the instance and left the mechanism; the drift check is what closes it.
PROGRAMS="calc tritdump fib caps_demo ipc_demo fm browser editor gui_fm gui_browser security_demo stream_demo sysinfo"

# A registry that must agree with another registry should be CHECKED, not
# described (report.txt P60). The other registry here is the directory listing.
MISSING_FROM_LIST=""
for f in "$USRDIR"/*.mt; do
    base=$(basename "$f" .mt)
    case " $PROGRAMS " in
        *" $base "*) ;;
        *) MISSING_FROM_LIST="$MISSING_FROM_LIST $base" ;;
    esac
done
if [ -n "$MISSING_FROM_LIST" ]; then
    echo "error: these userspace programs exist as source but are not in PROGRAMS:" >&2
    for m in $MISSING_FROM_LIST; do echo "         $USRDIR/$m.mt" >&2; done
    echo "       add them to PROGRAMS, or delete the source. A program that is" >&2
    echo "       never built is never tested and never known to be broken." >&2
    exit 1
fi

# And the converse: a name in the list with no source is a build that dies
# halfway through, having already written some binaries. Catch it before any
# compilation starts, so bin/ is never left half-current.
MISSING_SOURCE=""
for prog in $PROGRAMS; do
    [ -f "$USRDIR/${prog}.mt" ] || MISSING_SOURCE="$MISSING_SOURCE $prog"
done
if [ -n "$MISSING_SOURCE" ]; then
    echo "error: PROGRAMS names these, but no source exists:$MISSING_SOURCE" >&2
    exit 1
fi
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
echo "    $BINDIR/security_demo    # three-ring privilege + CapWord attenuation"
echo "    $BINDIR/stream_demo      # zero-copy trit stream IPC"
echo "    $BINDIR/sysinfo          # system information"
