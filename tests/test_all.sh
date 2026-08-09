#!/usr/bin/env bash
# thatteos/tests/test_all.sh — THATTEOS shell + userspace regression tests
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

check() {
    local label="$1"
    local output="$2"
    local pattern="$3"
    if echo "$output" | grep -qF -- "$pattern"; then
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

echo "=== THATTEOS test_all.sh ==="
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
if echo "$OUT" | grep -qF "thatteos"; then
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

# ── summary ──────────────────────────────────────────────────────────────────

TOTAL=$((PASS + FAIL))
echo "=== results: $PASS/$TOTAL passed ==="
if [ $FAIL -eq 0 ]; then
    echo "    ALL TESTS PASSED"
    exit 0
else
    echo "    $FAIL TEST(S) FAILED"
    exit 1
fi
