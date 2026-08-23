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
#   1. Compile and link thatteos.mt → ./thatteos, via manitc
#
# WHY THIS IS ONE STEP NOW (23 August 2026). It used to be three: emit LLVM IR,
# patch the IR with sed, then hand-link the IR against a separately compiled
# manit_runtime.o. All three had rotted.
#
#   * The IR patch (`ret ptr 0` → `ret ptr null`) matched nothing. maniTC emits
#     `ret ptr null` today; the sed was rewriting a bug that no longer exists.
#
#   * The hand-link broke outright. maniTC now compiles a growing part of the
#     stdlib from ManiT SOURCE rather than the C runtime, and a ManiT function
#     keeps its mangled name — `str::to_lower` is `@str_to_lower`, exactly the
#     symbol the C runtime also defines. maniTC handles that: it omits the
#     runtime's declare for anything the module itself defines, and it compiles
#     the runtime object with matching flags. This script did neither, so
#     linking thatteos.ll against a full manit_runtime.o produced "multiple
#     definition of str_to_lower" and a dozen more like it.
#
#   * `-o build/thatteos.ll` silently means IR-ONLY. maniTC treats a .ll output
#     path as "emit IR, do not link", so step 1 was never linking anyway and its
#     exit code said nothing about whether the program would link.
#
# `manitc compile -o thatteos` does all of it correctly, including pkg-config
# detection of SDL2/libcurl for the GUI and network builtins. Duplicating a
# compiler's link logic in a shell script is how it drifts; delegating is how it
# stops.
#
# Author: Manish Jagdish Thatte

set -e
cd "$(dirname "$0")"

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
if [ -z "$MANITC" ] || [ ! -x "$MANITC" ]; then
    echo "error: the manitc binary was not found in ../maniTC or ../manitc" >&2
    echo "build it first:  git clone https://github.com/manishthatte/maniTC && cd maniTC && cargo build --release" >&2
    echo "or point at it:  MANITC=/path/to/manitc bash build.sh" >&2
    exit 1
fi

echo "[1/1] compiling and linking thatteos.mt"
# NOTE the output name has no .ll suffix. maniTC reads a .ll output path as a
# request for IR only and skips linking entirely, which is exactly how the
# previous version of this script appeared to succeed while producing nothing.
"$MANITC" compile thatteos.mt -o thatteos

echo ""
echo "  done.  binary: ./thatteos"
echo "  run:   ./thatteos"
