#!/usr/bin/env bash
# build.sh — build the thatteOS interactive shell binary (hosted mode)
#
# Prerequisite: the maniTC compiler, built from the sibling repository:
#     git clone https://github.com/manishthatte/maniTC
#     cd maniTC && cargo build --release
#
# Usage (from this repo's root):
#     bash build.sh
#     MANITC=/path/to/manitc bash build.sh      # custom compiler location
#
# Steps:
#   1. Compile thatteos.mt → LLVM IR via manitc
#   2. Link with clang + the ManiT C runtime → ./thatteos binary
#
# Author: Manish Jagdish Thatte

set -e
cd "$(dirname "$0")"

CLANG="${CLANG:-clang-19}"

# The sibling checkout may be called either maniTC (the repository name, which
# is what `git clone` produces) or manitc (the crate/binary name, which is what
# older checkouts and some local setups use). Linux filenames are
# case-sensitive, so hardcoding one spelling breaks the other. Try both, and
# let MANITC/RUNTIME_SRC override entirely.
if [ -z "$MANITC" ]; then
    for d in ../maniTC ../manitc; do
        if [ -x "$d/target/release/manitc" ]; then
            MANITC="$d/target/release/manitc"
            SIBLING="$d"
            break
        fi
    done
fi
if [ -z "$RUNTIME_SRC" ] && [ -n "$SIBLING" ]; then
    RUNTIME_SRC="$SIBLING/runtime/manit_runtime.c"
fi
RUNTIME_SRC="${RUNTIME_SRC:-../maniTC/runtime/manit_runtime.c}"

if [ -z "$MANITC" ] || [ ! -x "$MANITC" ]; then
    echo "error: the manitc binary was not found in ../maniTC or ../manitc" >&2
    echo "build it first:  git clone https://github.com/manishthatte/maniTC && cd maniTC && cargo build --release" >&2
    echo "or point at it:  MANITC=/path/to/manitc bash build.sh" >&2
    exit 1
fi

CURL_CFLAGS=$(pkg-config --cflags libcurl 2>/dev/null || echo "")
CURL_LIBS=$(pkg-config --libs libcurl 2>/dev/null || echo "-lcurl")
SDL_CFLAGS=$(pkg-config --cflags sdl2 SDL2_ttf 2>/dev/null || echo "")
SDL_LIBS=$(pkg-config --libs sdl2 SDL2_ttf 2>/dev/null || echo "-lSDL2 -lSDL2_ttf")

mkdir -p build
RUNTIME=build/manit_runtime.o
# Rebuild the runtime when missing OR when the C source is newer than the
# object, so a stale runtime never links silently.
if [ ! -f "$RUNTIME" ] || [ "$RUNTIME_SRC" -nt "$RUNTIME" ]; then
    echo "[setup] compiling manit_runtime.c"
    "$CLANG" -O2 $CURL_CFLAGS $SDL_CFLAGS -c "$RUNTIME_SRC" -o "$RUNTIME"
fi

echo "[1/3] compiling thatteos.mt → LLVM IR"
"$MANITC" compile --target llvm thatteos.mt -o build/thatteos.ll

echo "[2/3] patching  ret ptr 0 → ret ptr null"
sed 's/ret ptr 0$/ret ptr null/g' build/thatteos.ll > build/thatteos_fixed.ll

echo "[3/3] linking"
"$CLANG" build/thatteos_fixed.ll "$RUNTIME" -o thatteos -lm $CURL_LIBS $SDL_LIBS

echo ""
echo "  done.  binary: ./thatteos"
echo "  run:   ./thatteos"
