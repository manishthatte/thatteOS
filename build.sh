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
#   1. Merge the two kernel manifests and compile them:
#        build/kernel        (both backends)   build/kernel_demos  (hosted)
#   2. Compile and link thatteos.mt → ./thatteos, via manitc
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
# Since 3 Sep 2026 this machine sets CARGO_TARGET_DIR globally, so a maniTC
# built here lands in $CARGO_TARGET_DIR/release and there is no repo-local
# target/ at all. Look there FIRST and keep the old layout as a fallback: a
# checkout that still builds into ./target must keep working, and the two
# cannot be told apart from here.
if [ -z "$MANITC" ] && [ -n "${CARGO_TARGET_DIR:-}" ] \
   && [ -x "$CARGO_TARGET_DIR/release/manitc" ]; then
    MANITC="$CARGO_TARGET_DIR/release/manitc"
fi
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
    echo "error: the manitc binary was not found in \$CARGO_TARGET_DIR/release, ../maniTC or ../manitc" >&2
    echo "build it first:  git clone https://github.com/manishthatte/maniTC && cd maniTC && cargo build --release" >&2
    echo "or point at it:  MANITC=/path/to/manitc bash build.sh" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 1. The kernel — 26 modules, one program, and a second program beside it
# ---------------------------------------------------------------------------
#
# NEW 30 August 2026, and it closes a hole rather than adding a feature: until
# today NOTHING in this repository compiled src/ at all. Not this script, which
# built the root thatteos.mt only; not userspace/build.sh; not CI; not
# tests/test_all.sh. Twenty-six kernel modules and twelve tests/*.mt, about
# 9,000 lines, none of it built by anything.
#
# Compiling them by hand on 30 August found two that did not compile at all
# (kernel/interrupt.mt and security/capability.mt, both maniTC report.txt P91)
# — and security/capability.mt is the subject of commit 873a0db. A commit had
# landed on a module that did not compile, and the repository had no way to say
# so. That is what this step is for.
#
# ManiT has no cross-file bodies, so the kernel is CONCATENATED from a manifest.
# The merged source goes to build/ with a line map beside it, so a diagnostic
# can be traced back:
#     python3 tools/merge_modules.py --locate <N> build/kernel.mt
#
# TWO PROGRAMS, not one with a flag, and the reason is a measurement:
#   build/kernel        26 modules            BOTH backends   37,378 T3 words
#   build/kernel_demos  + 25 demo modules     hosted only     would be 60,621
# The T3 backend emits every function in the translation unit whether it is
# reachable or not, so the demos counted against the 60,000-word image ceiling
# even when nothing called them. Moving the entry point alone did not help.
echo "[1/2] kernel — merging manifests, then compiling"
python3 tools/merge_modules.py src/kernel.manifest -o build/kernel.mt
python3 tools/merge_modules.py src/kernel_demos.manifest -o build/kernel_demos.mt

"$MANITC" compile --target llvm build/kernel.mt -o build/kernel
echo "  kernel  llvm: build/kernel"
"$MANITC" compile --target t3 build/kernel.mt -o build/kernel.t3b
echo "  kernel  t3:   build/kernel.t3b"
"$MANITC" compile --target llvm build/kernel_demos.mt -o build/kernel_demos
echo "  demos   llvm: build/kernel_demos  (hosted only — see src/kernel_demos.manifest)"

# THE IMAGE CEILING IS REAL AND IT HAS BEEN CROSSED ONCE ALREADY, on the day
# this step was written. Report it every build, because a program that stops
# fitting fails in the assembler with a message far from the change that caused
# it — and because the number is the input Phase 6 of ENHANCEMENT_PLAN.md needs.
WORDS=$("$MANITC" run-t3 build/kernel.t3b 2>&1 | head -1 | grep -oE '[0-9]+ words' | grep -oE '[0-9]+' || true)
if [ -n "$WORDS" ]; then
    echo "  t3 image: $WORDS words of 60000"
    if [ "$WORDS" -gt 54000 ]; then
        echo "  WARNING: the T3 code image is within 6000 words of the 60,000-word" >&2
        echo "           ceiling. Adding modules to src/kernel.manifest will stop" >&2
        echo "           fitting soon; see maniTC report.txt P38." >&2
    fi
fi
echo ""

echo "[2/2] compiling and linking thatteos.mt"
# NOTE the output name has no .ll suffix. maniTC reads a .ll output path as a
# request for IR only and skips linking entirely, which is exactly how the
# previous version of this script appeared to succeed while producing nothing.
"$MANITC" compile thatteos.mt -o thatteos

echo ""
echo "  done."
echo "    kernel:  ./build/kernel  ./build/kernel.t3b  ./build/kernel_demos"
echo "    shell:   ./thatteos"
echo "  run:   ./thatteos"
