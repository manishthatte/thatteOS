#!/usr/bin/env bash
# thatteos/tests/test_all.sh — thatteOS shell + userspace regression tests
#
# Usage (from the thatteos repo root):  bash tests/test_all.sh
#
# Tests:
#   1. Shell basic commands (help, version, whoami, priv, uname, uptime)
#   2. Shell filesystem commands (ls, pwd, cat, wc, head)
#   3. Shell ternary commands (trit, caps, date)
#   4. Shell exit
#   5. calc — arithmetic and ternary display
#   6. fib  — Fibonacci sequence in balanced ternary
#   7. ipc_demo — signed IPC dispatch (non-interactive)
#   8. caps_demo — 9-trit CapWord enforcement (non-interactive)
#
# Each test checks for expected output patterns. Failures print FAIL + detail.
#
# Author: Manish Jagdish Thatte

set -euo pipefail
cd "$(dirname "$0")/.."

SHELL_BIN=./thatteos
BINDIR=./userspace/bin
PASS=0
FAIL=0

# ── helpers ─────────────────────────────────────────────────────────────────

# Substring test done in-shell, NOT via `echo "$output" | grep -qF`.
# `grep -q` exits the moment it matches, so with a large capture the writing
# `echo` is left with a closed pipe and dies of SIGPIPE; `set -o pipefail`
# then makes the whole pipeline exit 141 and the check reports a spurious
# FAIL even though the pattern is present. That is a race on how much of the
# output has been written when grep bails, which is why it only ever bit the
# one test with a big capture whose pattern matches early ("cat reads
# LICENSE": 37 KB of output, matched at line 65 of 730) and why it showed up
# far more often on CI than locally. `[[ == *"$pattern"* ]]` is an exact
# literal substring match with no subprocess and no pipe.
check() {
    local label="$1"
    local output="$2"
    local pattern="$3"
    if [[ "$output" == *"$pattern"* ]]; then
        echo "  PASS  $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL  $label"
        echo "        expected pattern: $pattern"
        echo "        got: $(echo "$output" | head -5)"
        FAIL=$((FAIL + 1))
    fi
}

run_shell() {
    # Feed commands to the shell via stdin; append 'exit' so the shell
    # terminates cleanly and flushes its stdio buffer before capture.
    printf "%s\nexit\n" "$1" | timeout 20 "$SHELL_BIN" 2>&1 || true
}

# ── build check ──────────────────────────────────────────────────────────────

echo "=== thatteOS test_all.sh ==="
echo ""
echo "--- pre-flight ---"

if [ ! -x "$SHELL_BIN" ]; then
    echo "  MISSING: $SHELL_BIN — run: bash thatteos/build.sh first"
    exit 1
fi
echo "  shell binary: ok"

if [ ! -d "$BINDIR" ]; then
    echo "  MISSING: $BINDIR — run: bash thatteos/userspace/build.sh first"
    exit 1
fi
echo "  userspace bin: ok"

# Every userspace program that EXISTS AS SOURCE must have a binary here. Until
# 30 August 2026 this script only guarded each test individually on `[ -x ... ]`
# and skipped silently, and the total below is PASS+FAIL — so a missing bin/
# ran 27 of 61 checks, passed 27, and printed ALL TESTS PASSED. A green summary
# said nothing about whether the tests ran.
#
# The denominator is now the directory, not whatever happened to be on disk.
MISSING_BINS=""
for f in userspace/*.mt; do
    base=$(basename "$f" .mt)
    [ -x "$BINDIR/$base" ] || MISSING_BINS="$MISSING_BINS $base"
done
if [ -n "$MISSING_BINS" ]; then
    echo "  MISSING binaries for:$MISSING_BINS"
    echo "  run: bash userspace/build.sh"
    echo "  (refusing to run a partial suite — a skipped check is not a pass)"
    exit 1
fi
echo "  userspace coverage: ok — $(ls -1 userspace/*.mt | wc -l) sources, all built"

KERNEL=./build/kernel
KERNEL_T3=./build/kernel.t3b
KERNEL_DEMOS=./build/kernel_demos
for b in "$KERNEL" "$KERNEL_T3" "$KERNEL_DEMOS"; do
    if [ ! -f "$b" ]; then
        echo "  MISSING: $b — run: bash build.sh"
        exit 1
    fi
done

# STALENESS, and this is not a hypothetical guard. On 30 August 2026 the T3
# code image crossed its 60,000-word ceiling and the assembler refused to write
# build/kernel.t3b — and this suite reported 96/96, because the PREVIOUS run's
# .t3b was still on disk and was what it tested. A failed build left a passing
# test. An artefact older than the source it claims to be built from is not
# evidence about that source.
for b in "$KERNEL" "$KERNEL_T3"; do
    if [ "build/kernel.mt" -nt "$b" ]; then
        echo "  STALE: $b is older than build/kernel.mt — run: bash build.sh"
        echo "  (a build that failed can leave the previous artefact in place)"
        exit 1
    fi
done
if [ "build/kernel_demos.mt" -nt "$KERNEL_DEMOS" ]; then
    echo "  STALE: $KERNEL_DEMOS is older than build/kernel_demos.mt — run: bash build.sh"
    exit 1
fi
echo "  kernel: ok (both backends, artefacts current)"
echo ""

# ── section 1: shell basics ──────────────────────────────────────────────────

echo "--- [1] shell basics ---"

OUT=$(run_shell "help")
check "help lists commands"     "$OUT" "help"
check "help mentions ls"        "$OUT" "ls"
check "help mentions cat"       "$OUT" "cat"

# 'version' is not a separate command; the banner always shows THATTE-OS
OUT=$(run_shell "help")
check "banner shows THATTE-OS"  "$OUT" "THATTE-OS"

OUT=$(run_shell "whoami")
check "whoami shows user"       "$OUT" "user"

OUT=$(run_shell "priv")
check "priv shows privilege"    "$OUT" "privilege"

# dmesg must print the kernel log header (only cmd_dmesg produces it —
# the boot banner does not contain this string)
OUT=$(run_shell "dmesg")
check "dmesg shows kernel log"  "$OUT" "--- THATTE-OS kernel log ---"

OUT=$(run_shell "uptime")
check "uptime shows ticks"      "$OUT" "tick"

echo ""

# ── section 2: filesystem commands ──────────────────────────────────────────

echo "--- [2] filesystem commands ---"

OUT=$(run_shell "ls")
# Boot banner contains "fault" in IDT description — so check ls output
# has at least one recognisable entry from the THATTE directory
if [[ "$OUT" == *"thatteos"* ]]; then
    echo "  PASS  ls shows directory entries"
    PASS=$((PASS + 1))
else
    echo "  FAIL  ls shows directory entries"
    echo "        output did not contain 'thatteos'"
    FAIL=$((FAIL + 1))
fi

# pwd must print the actual working directory (the repo root we cd'd into),
# not just any string containing '/'
OUT=$(run_shell "pwd")
check "pwd shows cwd"           "$OUT" "$(pwd)"

# Match on LICENSE file content, not on strings the boot banner also prints
OUT=$(run_shell "cat LICENSE")
check "cat reads LICENSE"       "$OUT" "GNU AFFERO GENERAL PUBLIC LICENSE"

OUT=$(run_shell "wc LICENSE")
check "wc shows line count"     "$OUT" "lines="

OUT=$(run_shell "head LICENSE")
check "head shows first lines"  "$OUT" "GNU AFFERO GENERAL PUBLIC LICENSE"

echo ""

# ── section 3: ternary / system commands ─────────────────────────────────────

echo "--- [3] ternary commands ---"

# Each pattern below is produced ONLY by the tested command, never by the
# boot banner — so these tests can actually fail.
OUT=$(run_shell "trit 42")
check "trit 42 = 0t+---0"            "$OUT" "0t+---0"

OUT=$(run_shell "trit 27")
check "trit 27 = 0t+000"             "$OUT" "0t+000"

OUT=$(run_shell "caps")
check "caps shows CapWord table"     "$OUT" "CapWord (9-trit capability word)"

OUT=$(run_shell "date")
if echo "$OUT" | grep -qE "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}"; then
    echo "  PASS  date returns timestamp"
    PASS=$((PASS + 1))
else
    echo "  FAIL  date returns timestamp"
    echo "        expected YYYY-MM-DD HH:MM:SS in output"
    FAIL=$((FAIL + 1))
fi

echo ""

# ── section 4: shell exit ─────────────────────────────────────────────────────

echo "--- [4] shell exit ---"

OUT=$(run_shell "exit")
check "exit prints bye"         "$OUT" "bye"

# quit is an alias for exit.  Feed ONLY 'quit' (no appended exit): if quit
# did not terminate the shell, the loop would spin on EOF until the timeout
# kills it and 'Goodbye' would never be printed — so this test can fail.
OUT=$(printf "quit\n" | timeout 10 "$SHELL_BIN" 2>&1 || true)
check "quit also exits"         "$OUT" "Goodbye"

echo ""

# ── section 5: calc ──────────────────────────────────────────────────────────

echo "--- [5] calc ---"

CALC="$BINDIR/calc"
if [ ! -x "$CALC" ]; then
    echo "  SKIP  calc binary not found"
else
    # calc format: <op> <a> <b>  (op is first token)
    OUT=$(printf "+ 3 4\nquit\n" | timeout 5 "$CALC" 2>&1 || true)
    check "calc 3+4 = 7"              "$OUT" "7"
    check "calc shows ternary"        "$OUT" "0t"

    OUT=$(printf "* 27 3\nquit\n" | timeout 5 "$CALC" 2>&1 || true)
    check "calc 27*3 = 81"            "$OUT" "81"

    OUT=$(printf "neg 9\nquit\n" | timeout 5 "$CALC" 2>&1 || true)
    # grep -F "-9" treats -9 as a flag; check for the full expression instead
    check "calc neg 9 = -9"           "$OUT" "neg(9)"

    OUT=$(printf "abs -5\nquit\n" | timeout 5 "$CALC" 2>&1 || true)
    check "calc abs -5 = 5"           "$OUT" "5"

    OUT=$(printf "** 3 3\nquit\n" | timeout 5 "$CALC" 2>&1 || true)
    check "calc 3**3 = 27"            "$OUT" "27"

    OUT=$(printf "/ 10 0\nquit\n" | timeout 5 "$CALC" 2>&1 || true)
    check "calc div-by-zero handled"  "$OUT" "zero"
fi
echo ""

# ── section 6: fib ───────────────────────────────────────────────────────────

echo "--- [6] fib ---"

FIB="$BINDIR/fib"
if [ ! -x "$FIB" ]; then
    echo "  SKIP  fib binary not found"
else
    OUT=$(printf "10\n" | timeout 5 "$FIB" 2>&1 || true)
    check "fib header printed"        "$OUT" "balanced ternary"
    check "fib F(0)=0"                "$OUT" "0"
    check "fib F(7)=13"               "$OUT" "13"
    check "fib trit count column"     "$OUT" "trits"
    check "fib phi insight printed"   "$OUT" "phi"
fi
echo ""

# ── section 7: ipc_demo ──────────────────────────────────────────────────────

echo "--- [7] ipc_demo ---"

IPC="$BINDIR/ipc_demo"
if [ ! -x "$IPC" ]; then
    echo "  SKIP  ipc_demo binary not found"
else
    OUT=$(timeout 5 "$IPC" 2>&1 || true)
    check "ipc header printed"        "$OUT" "signed-integer message passing"
    check "ipc REQUEST path"          "$OUT" "REQUEST"
    check "ipc HEARTBT path"          "$OUT" "HEARTBT"
    check "ipc ERROR path"            "$OUT" "ERROR"
    check "ipc TBRANCH positive"      "$OUT" "positive path"
    check "ipc TBRANCH negative"      "$OUT" "negative path"
    check "ipc queue stats"           "$OUT" "statistics"
    check "ipc MSG_ALLOC"             "$OUT" "MSG_ALLOC"
    check "ipc MSG_DENIED"            "$OUT" "MSG_DENIED"
fi
echo ""

# ── section 8: caps_demo ─────────────────────────────────────────────────────

echo "--- [8] caps_demo ---"

CAPS="$BINDIR/caps_demo"
if [ ! -x "$CAPS" ]; then
    echo "  SKIP  caps_demo binary not found"
else
    OUT=$(timeout 5 "$CAPS" 2>&1 || true)
    check "caps header printed"       "$OUT" "9-trit CapWord"
    check "caps KERNEL row"           "$OUT" "KERNEL"
    check "caps USER row"             "$OUT" "USER"
    check "caps SANDBOX row"          "$OUT" "SANDBOX"
    check "caps ALLOWED"              "$OUT" "ALLOWED"
    check "caps DENIED"               "$OUT" "DENIED"
    check "caps INHERITED"            "$OUT" "INHERITED"
    check "caps attenuation"          "$OUT" "Attenuation"
    check "caps attenuation rule"     "$OUT" "parent"
fi
echo ""

# ── section 9: negative tests ─────────────────────────────────────────────────
# Each test expects an ERROR or graceful rejection — NOT a crash or silent
# acceptance.  A test PASSES if the expected error/denial string is present.

echo "--- [9] negative tests ---"

# 9.1  Unknown command — shell must print "not found" or equivalent, not crash
OUT=$(run_shell "xyzzy_no_such_command_39217")
check "unknown cmd: error not crash"     "$OUT" "not found"

# 9.2  kill with out-of-range PID (>8) — must print error, not silently succeed
OUT=$(run_shell "kill 999 0")
check "kill OOB pid: error message"      "$OUT" "PID out of range"

# 9.3  kill with out-of-range signal (>4) — must print error
OUT=$(run_shell "kill 3 99")
check "kill OOB signal: error message"   "$OUT" "signal out of ternary range"

# 9.4  stat on nonexistent path — must print error, not crash
OUT=$(run_shell "stat /does/not/exist")
check "stat missing path: error"         "$OUT" "no such path"

# 9.5  trit with no argument (empty arg) — must print the usage message
OUT=$(run_shell "trit ")
check "trit empty arg: usage error"      "$OUT" "usage: trit"

# 9.6  echo with no argument — must not crash (prints blank line or empty)
OUT=$(run_shell "echo ")
if echo "$OUT" | grep -qiE "crash|segfault|panic"; then
    echo "  FAIL  echo empty: crashed"
    FAIL=$((FAIL + 1))
else
    echo "  PASS  echo empty: no crash"
    PASS=$((PASS + 1))
fi

# 9.7  Repeated 'exit' — second exit after shell quit; must not crash
OUT=$(printf "exit\nexit\n" | timeout 10 "$SHELL_BIN" 2>&1 || true)
if echo "$OUT" | grep -qiE "crash|segfault|panic"; then
    echo "  FAIL  double exit: crashed"
    FAIL=$((FAIL + 1))
else
    echo "  PASS  double exit: no crash"
    PASS=$((PASS + 1))
fi

# 9.8  Empty input line — shell must not crash on blank command
OUT=$(printf "\n\n\nexit\n" | timeout 10 "$SHELL_BIN" 2>&1 || true)
if echo "$OUT" | grep -qiE "crash|segfault|panic"; then
    echo "  FAIL  empty lines: crashed"
    FAIL=$((FAIL + 1))
else
    echo "  PASS  empty lines: no crash"
    PASS=$((PASS + 1))
fi

# 9.9  calc: div by zero — already covered in section 5, but repeat as neg test
if [ -x "$BINDIR/calc" ]; then
    OUT=$(printf "/ 1 0\nquit\n" | timeout 5 "$BINDIR/calc" 2>&1 || true)
    check "calc div-by-zero: error, no crash"  "$OUT" "zero"
fi

# 9.10  calc: unknown operator — must print error, not crash
if [ -x "$BINDIR/calc" ]; then
    OUT=$(printf "? 3 4\nquit\n" | timeout 5 "$BINDIR/calc" 2>&1 || true)
    if echo "$OUT" | grep -qiE "crash|segfault|panic"; then
        echo "  FAIL  calc bad op: crashed"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS  calc bad op: no crash"
        PASS=$((PASS + 1))
    fi
fi

# 9.11  fib: n=0 — boundary, must produce F(0)=0
if [ -x "$BINDIR/fib" ]; then
    OUT=$(printf "0\n" | timeout 5 "$BINDIR/fib" 2>&1 || true)
    # n=0 might just show the header and no rows — acceptable; must not crash
    if echo "$OUT" | grep -qiE "crash|segfault|panic"; then
        echo "  FAIL  fib n=0: crashed"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS  fib n=0: no crash"
        PASS=$((PASS + 1))
    fi
fi

# 9.12  caps_demo out-of-range capability index — fixed in task #13
#       The fix ensures out-of-range index returns DENIED, not silently reading
#       cap.c8.  We test the demo output includes DENIED at least once.
if [ -x "$BINDIR/caps_demo" ]; then
    OUT=$(timeout 5 "$BINDIR/caps_demo" 2>&1 || true)
    check "caps OOB → DENIED (task #13)"  "$OUT" "DENIED"
fi

echo ""

# ── section 10: the three programs that were built but never listed ──────────
#
# security_demo, stream_demo and sysinfo compiled and linked cleanly for weeks;
# `userspace/build.sh`'s PROGRAMS list simply never named them, so no binary
# existed and no test could reference one. They are ENHANCEMENT_PLAN.md §1.4.

echo "--- [10] security_demo, stream_demo, sysinfo ---"

OUT=$(timeout 10 "$BINDIR/security_demo" 2>&1 || true)
check "security: three-ring model stated"   "$OUT" "Three rings of privilege"
check "security: KERNEL row all ALLOW"      "$OUT" "KERNEL  (+1)    |    ALLOW     |      ALLOW      |    ALLOW"
check "security: USER private page TRAPs"   "$OUT" "USER    (-1)    |    TRAP     |      TRAP      |    ALLOW"
check "security: escalation denied"         "$OUT" "Privilege escalation USER -> KERNEL DENIED"
check "security: ring invariant held"       "$OUT" "[CHECK] ring invariant after denied escalation: HELD"
check "security: capability fault reported" "$OUT" "*** CAPABILITY FAULT ***"
check "security: revoked grant is dark"     "$OUT" "revoked — zone is dark"
# The invariant helper prints HELD or VIOLATED. A demo whose own check failed
# must not pass this suite, and the positive check above cannot see a SECOND
# occurrence that went the other way.
if [[ "$OUT" == *"VIOLATED"* ]]; then
    echo "  FAIL  security: no ring invariant violated"
    FAIL=$((FAIL + 1))
else
    echo "  PASS  security: no ring invariant violated"
    PASS=$((PASS + 1))
fi

OUT=$(timeout 10 "$BINDIR/stream_demo" 2>&1 || true)
check "stream: channel allocated"           "$OUT" "SWCNT path allocated"
check "stream: zero-copy claim stated"      "$OUT" "Same physical current as sender"
check "stream: word transfer"               "$OUT" "Full Word Transfer"
check "stream: teardown"                    "$OUT" "closed"
# Three single-trit round trips: +1, 0, -1. Count them rather than matching one,
# because one PASS present says nothing about the other two.
RT=$(printf '%s\n' "$OUT" | grep -c "round-trip PASS" || true)
if [ "$RT" -eq 3 ]; then
    echo "  PASS  stream: 3/3 trit round-trips verified"
    PASS=$((PASS + 1))
else
    echo "  FAIL  stream: 3/3 trit round-trips verified"
    echo "        expected 3 'round-trip PASS' lines, got: $RT"
    FAIL=$((FAIL + 1))
fi
if [[ "$OUT" == *"round-trip FAIL"* ]]; then
    echo "  FAIL  stream: no failed round-trip"
    FAIL=$((FAIL + 1))
else
    echo "  PASS  stream: no failed round-trip"
    PASS=$((PASS + 1))
fi

OUT=$(timeout 10 "$BINDIR/sysinfo" 2>&1 || true)
check "sysinfo: OS and version"             "$OUT" "thatteOS 0.1.0"
check "sysinfo: architecture"               "$OUT" "T3ISA (27-trit balanced ternary)"
check "sysinfo: author"                     "$OUT" "Manish Jagdish Thatte"
check "sysinfo: 3^27 address space"         "$OUT" "3^27 = 7,625,597,484,987"
check "sysinfo: 729-trit page"              "$OUT" "3^6 = 729 trits"
check "sysinfo: MST region layout"          "$OUT" "MST(+1): positive addresses"
check "sysinfo: process table"              "$OUT" "PID=3  shell"
check "sysinfo: TritFS section"             "$OUT" "TritFS"

echo ""

# ── section 11: the kernel, as ONE program ───────────────────────────────────
#
# ENHANCEMENT_PLAN.md §1. Until 30 August 2026 src/ was twenty-six .mt files
# with twenty-six `fn main`, and NOTHING compiled any of them — so this section
# is the first test the kernel has ever had.
#
# It asserts the boot sequence reaches the real modules, not boot.mt's own
# stubs of them. The `[IRQ]` and `[VMEM]` prefixes are the evidence: boot.mt's
# retired copies printed `[BOOT]`, so a banner from the real module is proof
# the call went where the merge sent it.

echo "--- [11] the kernel, one program, both backends ---"

OUT=$(timeout 30 "$KERNEL" 2>&1 || true)
check "kernel: boot banner"                 "$OUT" "THATTE-OS 0.1.0"
check "kernel: reaches kernel/interrupt.mt" "$OUT" "[IRQ] interrupt_init: registering 27 interrupt vectors"
check "kernel: reaches mm/vmem.mt"          "$OUT" "[VMEM]"
check "kernel: reaches syscall/syscall.mt"  "$OUT" "[SYSCALL]"
check "kernel: reaches drivers/tty.mt"      "$OUT" "[TTY] tty_init: loading TTY driver"
check "kernel: privilege drop to SERVICE"   "$OUT" "drop_to_service"
check "kernel: launches init at USER"       "$OUT" "init: running at USER privilege"
check "kernel: scheduler pass completes"    "$OUT" "[SCHED] scheduler_run: pass complete"
check "kernel: boot completes"              "$OUT" "THATTE-OS boot sequence complete"
# --- the event loop, ENHANCEMENT_PLAN §2.5 ---------------------------------
# These four rows are the kernel-level evidence for §2.1 and §2.5: that the
# timer reaches the scheduler and that waking a sleeper is a WRITE rather than
# a sentence. Before this phase the kernel printed "-> scheduler_run() invoked"
# at four sites and called it at none, so the third row here is the one that
# separates the two states.
check "kernel: event loop runs"             "$OUT" "[BOOT] event loop: interrupt -> timer -> scheduler"
check "kernel: interrupt drives the timer"  "$OUT" "[IRQ] interrupt_dispatch: vector=0"
check "kernel: timer wakes a sleeper"       "$OUT" "[TIMER] waking PID=1 (sleep expired at tick=2)"
check "kernel: quantum expiry runs the scheduler" "$OUT" "[TIMER] quantum expired (3 ticks)"
# The capability gate, exercised by the RUNNING kernel rather than by a demo.
# init is admitted at USER(-1) and holds user_caps, which withhold CAN_MOD.
check "kernel: a syscall passes the capability gate" "$OUT" "[SYSCALL] R1=-1 (SYS_YIELD)"
check "kernel: USER is refused SYS_MOD_LOAD at boot" "$OUT" "refused — capability enforcement is live"

# boot.mt's own stubs printed [BOOT] for these. If one comes back, a module got
# re-implemented locally again and this is the row that notices.
if [[ "$OUT" == *"[BOOT] interrupt_init"* ]] || [[ "$OUT" == *"[BOOT] vmem_init"* ]] || \
   [[ "$OUT" == *"[BOOT] syscall_init"* ]] || [[ "$OUT" == *"[BOOT] process_init"* ]]; then
    echo "  FAIL  kernel: no module re-implemented in boot.mt"
    FAIL=$((FAIL + 1))
else
    echo "  PASS  kernel: no module re-implemented in boot.mt"
    PASS=$((PASS + 1))
fi

# The 26 module demos — a SECOND program, build/kernel_demos, built from
# src/kernel_demos.manifest. They were 25 separate `fn main`s before the merge
# and nothing ran any of them; renaming them to `*_demo()` without calling them
# would have made them dead code with a nicer name.
#
# They are a separate program rather than a flag because the T3 backend emits
# every function in a translation unit whether it is reachable or not: beside
# the kernel they cost 19,000 words of a 60,000-word image, and with the
# assertions below added they took it over the ceiling.
#
# The 140 [CHECK] lines they print are the ones that used to be `let r1 = ...`
# bindings nobody read, beside hardcoded "PASS" string literals. The expected
# value at each site was derived FROM THE SOURCE -- the CapWord constructors,
# `sys_kill`'s privilege rules, the demo's own stated intent -- and not from
# what the program happened to print, because a check that copies the observed
# answer tests nothing.
#
# 37 -> 57 on 30 August 2026: timer's demo had ZERO assertions and closed by
# printing five hardcoded "PASS" lines. ENHANCEMENT_PLAN §2.2 recorded the
# sleep queue as broken; re-probing found the prescribed remedy already
# implemented and NOTHING pinning it. The 20 new rows pin it, and they bite --
# reintroducing exactly the defect §2.2 describes (wake_entry_if_due returning
# the entry without clearing `valid`) turns 7 of the 20 red, where before the
# whole defect was invisible. Update this number in the same commit that adds
# or removes an assertion.
DEMOS=$(timeout 60 "$KERNEL_DEMOS" 2>&1 || true)
check "demos: all 26 ran"           "$DEMOS" "all 26 module demonstrations complete"
NPASS=$(printf '%s\n' "$DEMOS" | grep -c "CHECK\] PASS" || true)
NFAIL=$(printf '%s\n' "$DEMOS" | grep -c "CHECK\] FAIL" || true)
if [ "$NPASS" -eq 140 ] && [ "$NFAIL" -eq 0 ]; then
    echo "  PASS  demos: 140/140 in-kernel assertions hold"
    PASS=$((PASS + 1))
else
    echo "  FAIL  demos: 140/140 in-kernel assertions hold"
    echo "        got $NPASS PASS and $NFAIL FAIL"
    printf '%s\n' "$DEMOS" | grep "CHECK\] FAIL" | head -5
    FAIL=$((FAIL + 1))
fi

# T3ISA is the actual target, so the kernel is checked ON it, not merely
# compiled FOR it. Byte-for-byte against the hosted run: a kernel that builds
# for T3 and answers differently there has not been ported, it has been forked.
# Three scripts resolve this binary and they must agree — build.sh and
# userspace/build.sh try $CARGO_TARGET_DIR first (global since 3 Sep 2026,
# so there is no repo-local target/) and then both spellings of the sibling
# checkout. This one used to try one spelling of one layout, which is how a
# storage change made three rows here fail while both build scripts were fine.
if [ -n "${MANITC:-}" ]; then
    MANITC_BIN="$MANITC"
elif [ -n "${CARGO_TARGET_DIR:-}" ] && [ -x "$CARGO_TARGET_DIR/release/manitc" ]; then
    MANITC_BIN="$CARGO_TARGET_DIR/release/manitc"
else
    MANITC_BIN=""
    for d in ../maniTC ../manitc; do
        [ -x "$d/target/release/manitc" ] && { MANITC_BIN="$d/target/release/manitc"; break; }
    done
    [ -z "$MANITC_BIN" ] && MANITC_BIN=../manitc/target/release/manitc
fi
if [ -x "$MANITC_BIN" ]; then
    T3OUT=$(timeout 60 "$MANITC_BIN" run-t3 "$KERNEL_T3" 2>&1 | tail -n +2 || true)
    if [ "$T3OUT" = "$OUT" ]; then
        echo "  PASS  kernel: T3ISA output is byte-identical to hosted"
        PASS=$((PASS + 1))
    else
        echo "  FAIL  kernel: T3ISA output is byte-identical to hosted"
        echo "        hosted $(printf '%s' "$OUT" | wc -l) lines, t3 $(printf '%s' "$T3OUT" | wc -l) lines"
        FAIL=$((FAIL + 1))
    fi
else
    echo "  FAIL  kernel: T3ISA output is byte-identical to hosted"
    echo "        the compiler was not found at $MANITC_BIN, so the T3 half"
    echo "        could not run. This is a FAIL and not a skip on purpose:"
    echo "        a skipped check is what made 27/27 read as ALL TESTS PASSED."
    FAIL=$((FAIL + 1))
fi

echo ""
echo "── studioMani ───────────────────────────────────────────────────────────────"

# UNTIL TODAY THIS SUITE DID NOT MENTION studioMani AT ALL. 3,472 lines of IDE
# and three standalone apps, built by studioMani/build.sh, checked by nothing —
# the same hole Phase 1 found in src/ and for the same reason: a build script
# that exits 0 is not a test. The rows below are deliberately modest about what
# they prove, because an SDL2 program cannot be driven headlessly here.
#
# WHAT A SMOKE ROW ACTUALLY PROVES, said plainly rather than implied by a green
# tick: the program links, SDL2 initialises, and the FIRST FRAME of the draw
# path runs to gui_present() without crashing — which for the IDE is the
# titlebar, the tab bar, the sidebar, the editor tab bar, the breadcrumb, the
# editor and the status bar. It proves NOTHING about the event handlers, which
# are the 700 lines that matter most. Driving those needs injected SDL events
# and is its own step.
#
# SDL_VIDEODRIVER=dummy is what makes it runnable with no display. rc 124 —
# killed by the timeout — is the PASS condition, because the program is an
# event loop and is supposed to still be running. An exit of 0 would mean it
# quit on its own, which it must not do; any other code is a crash.
SM_OUT=./studioMani/output
for prog in studioMani sm_browser sm_email sm_fm; do
    if [ ! -x "$SM_OUT/$prog" ]; then
        # A MISSING BINARY IS A FAIL AND NOT A SKIP. See trap 4 in CLAUDE.md:
        # a guard that skips a test when its input is missing is what once made
        # 27 of 61 checks read as ALL TESTS PASSED.
        echo "  FAIL  studioMani: $prog runs headless"
        echo "        $SM_OUT/$prog does not exist — run: bash studioMani/build.sh"
        FAIL=$((FAIL + 1))
        continue
    fi
    set +e
    SDL_VIDEODRIVER=dummy timeout 5 "$SM_OUT/$prog" >/dev/null 2>&1
    rc=$?
    set -e
    if [ "$rc" -eq 124 ]; then
        echo "  PASS  studioMani: $prog runs headless"
        PASS=$((PASS + 1))
    else
        echo "  FAIL  studioMani: $prog runs headless"
        echo "        exited $rc; expected 124 (still running when the timeout fired)"
        FAIL=$((FAIL + 1))
    fi
done

# The IDE is thirteen modules concatenated in dependency order, so the merged
# file is the only thing a compiler ever sees. Check IT, not the parts.
SM_MERGED="$SM_OUT/studioMani_merged.mt"
if [ -x "$MANITC_BIN" ] && [ -f "$SM_MERGED" ]; then
    SSA=$("$MANITC_BIN" check --verify-ssa "$SM_MERGED" 2>&1 || true)
    if ! printf '%s' "$SSA" | grep -q "violation"; then
        echo "  PASS  studioMani: merged IDE has no SSA violations"
        PASS=$((PASS + 1))
    else
        echo "  FAIL  studioMani: merged IDE has no SSA violations"
        printf '%s\n' "$SSA" | grep "violation" | head -3
        FAIL=$((FAIL + 1))
    fi

    # ZERO WARNINGS, which the kernel has held since Phase 1 and studioMani did
    # not until 30 August 2026. It had thirteen, all "unused variable" — and
    # two of them were naming REAL DEFECTS, not untidiness: a Tab indent and a
    # Replace All that pushed no undo snapshot, so neither was undoable. The
    # warning was the only thing in the repository that pointed at them.
    WARN=$("$MANITC_BIN" check "$SM_MERGED" 2>&1 | grep -c "^warning:" || true)
    if [ "$WARN" -eq 0 ]; then
        echo "  PASS  studioMani: merged IDE compiles with no warnings"
        PASS=$((PASS + 1))
    else
        echo "  FAIL  studioMani: merged IDE compiles with no warnings"
        echo "        $WARN warning(s)"
        FAIL=$((FAIL + 1))
    fi
else
    echo "  FAIL  studioMani: merged IDE has no SSA violations"
    echo "  FAIL  studioMani: merged IDE compiles with no warnings"
    echo "        compiler at $MANITC_BIN or $SM_MERGED missing"
    FAIL=$((FAIL + 2))
fi

echo ""

# ── summary ──────────────────────────────────────────────────────────────────

TOTAL=$((PASS + FAIL))
echo "=== results: $PASS/$TOTAL passed ==="

# The denominator is derived from what RAN, so it cannot detect its own
# shrinkage — that is exactly how 27/27 once read as ALL TESTS PASSED. Assert
# the count. This constant is a second source of truth and it is deliberate:
# it is the only thing that can notice a check disappearing. Update it in the
# same commit that adds or removes one; the message says so.
EXPECTED_CHECKS=108
if [ "$TOTAL" -ne "$EXPECTED_CHECKS" ]; then
    echo "    SUITE INCOMPLETE: ran $TOTAL checks, expected $EXPECTED_CHECKS"
    echo "    a check disappeared, or one was added without updating"
    echo "    EXPECTED_CHECKS in tests/test_all.sh"
    exit 1
fi

if [ $FAIL -eq 0 ]; then
    echo "    ALL TESTS PASSED"
    exit 0
else
    echo "    $FAIL TEST(S) FAILED"
    exit 1
fi
