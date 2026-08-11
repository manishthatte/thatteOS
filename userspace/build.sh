#!/usr/bin/env bash
# thatteos/userspace/build.sh — compile all thatteOS userspace programs
#
# Usage (from the thatteos repo root):  bash userspace/build.sh
#
# Compiles each .mt program in userspace/ to a native binary in userspace/bin/.
# Steps per program:
#   1. manitc --target llvm → .ll
#   2. sed patch (ret ptr 0 → ret ptr null)
#   3. clang-19 link with manit_runtime.o → binary
#
# Author: Manish Jagdish Thatte

set -e
cd "$(dirname "$0")/.."

MANITC="${MANITC:-../manitc/target/release/manitc}"
CLANG="${CLANG:-clang-19}"
RUNTIME_SRC="${RUNTIME_SRC:-../manitc/runtime/manit_runtime.c}"
mkdir -p build
RUNTIME=build/manit_runtime.o
USRDIR=userspace
BINDIR=userspace/bin

CURL_CFLAGS=$(pkg-config --cflags libcurl 2>/dev/null || echo "")
CURL_LIBS=$(pkg-config --libs libcurl 2>/dev/null || echo "-lcurl")
SDL_CFLAGS=$(pkg-config --cflags sdl2 SDL2_ttf 2>/dev/null || echo "")
SDL_LIBS=$(pkg-config --libs sdl2 SDL2_ttf 2>/dev/null || echo "-lSDL2 -lSDL2_ttf")

# Ensure runtime object exists and is not stale (regenerate if the C source
# is newer than the object)
if [ ! -f "$RUNTIME" ] || [ "$RUNTIME_SRC" -nt "$RUNTIME" ]; then
    echo "[setup] compiling manit_runtime.c → $RUNTIME"
    "$CLANG" -O2 $CURL_CFLAGS $SDL_CFLAGS -c "$RUNTIME_SRC" -o "$RUNTIME"
fi

mkdir -p "$BINDIR"

PROGRAMS="calc tritdump fib caps_demo ipc_demo fm browser editor gui_fm gui_browser"
TOTAL=$(echo $PROGRAMS | wc -w)
N=0

for prog in $PROGRAMS; do
    N=$((N + 1))
    src="$USRDIR/${prog}.mt"
    ll="$USRDIR/${prog}.ll"
    ll_fixed="$USRDIR/${prog}_fixed.ll"
    bin="$BINDIR/${prog}"

    echo "[$N/$TOTAL] $prog"
    echo "  compile  ${prog}.mt → ${prog}.ll"
    "$MANITC" compile --target llvm "$src" -o "$ll"

    echo "  patch    ret ptr 0 → ret ptr null"
    sed 's/ret ptr 0$/ret ptr null/g' "$ll" > "$ll_fixed"

    echo "  link     → bin/${prog}"
    "$CLANG" "$ll_fixed" "$RUNTIME" -o "$bin" -lm $CURL_LIBS $SDL_LIBS

    rm -f "$ll" "$ll_fixed"
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
