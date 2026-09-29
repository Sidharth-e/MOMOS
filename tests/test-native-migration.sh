#!/usr/bin/env bash
#
# Stub-command harness for the native migration.
#
# These scripts cannot be run end-to-end off-device (they check for
# /data/data/com.termux and call pkg), so the decision logic is extracted
# function-by-function and exercised against stubbed commands instead.
#
# Run: bash tests/test-native-migration.sh

# SC2016: the generated harness scripts deliberately contain literal $VARs
# that must expand at harness runtime, not now.
# SC2001: sed is clearer than parameter expansion for the indent here.
# shellcheck disable=SC2016,SC2001

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOMOS_SH="$REPO_ROOT/scripts/momos.sh"
SETUP_SH="$REPO_ROOT/scripts/setup.sh"
LEGACY_SH="$REPO_ROOT/scripts/legacy/proot/momos.sh"

PASS=0
FAIL=0

# Populated by the run_* helpers. Output goes through a file rather than
# command substitution so the exit status survives out of the subshell.
OUT=""
RUN_STATUS=0

pass() { printf '  \033[0;32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  \033[0;31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

show() { sed 's/^/      /' <<< "$1"; }

# Pull a single top-level function definition out of a script, so it can be
# evaluated in isolation against stubbed globals.
extract_function() {
    local file="$1" fn="$2"
    awk -v fn="$fn" '
        $0 ~ "^"fn"\\(\\) \\{" { capture = 1 }
        capture { print }
        capture && /^}$/ { exit }
    ' "$file"
}

# Silence colour codes and logging so output is greppable.
harness_preamble() {
    cat <<'PREAMBLE'
RED=''; GREEN=''; YELLOW=''; BLUE=''; PURPLE=''; CYAN=''; WHITE=''; BOLD=''; DIM=''; NC=''
LEGACY_INSTALL_URL="https://example.invalid/legacy/proot/momos.sh"
OLLAMA_URL="http://127.0.0.1:11434"
LOG_FILE=/dev/null
log() { :; }
info() { echo "INFO: $1"; }
success() { echo "SUCCESS: $1"; }
warn() { echo "WARN: $1"; }
fail() { echo "FAIL: $1"; }
PREAMBLE
}

# Build a throwaway script from a preamble, some extracted functions, and a
# final expression, then run it with stubbed commands ahead of the real PATH.
# ---------------------------------------------------------------------------

section "momos.sh — architecture gate"

# Run check_arch() with `uname -m` reporting the given architecture.
check_arch_case() {
    local arch="$1" tmp
    tmp=$(mktemp -d)
    shift

    cat > "$tmp/uname" <<STUB
#!/bin/bash
echo "$arch"
STUB
    chmod +x "$tmp/uname"

    {
        harness_preamble
        extract_function "$MOMOS_SH" get_arch
        extract_function "$MOMOS_SH" check_arch
        echo 'check_arch'
    } > "$tmp/run.sh"

    PATH="$tmp:$PATH" bash "$tmp/run.sh" > "$tmp/out" 2>&1
    RUN_STATUS=$?
    OUT="$(cat "$tmp/out")"
    rm -rf "$tmp"
}

for arch in aarch64 x86_64; do
    check_arch_case "$arch"
    if [ "$RUN_STATUS" -eq 0 ] && grep -q "SUCCESS: Architecture: ${arch}" <<< "$OUT"; then
        pass "$arch accepted"
    else
        fail "$arch should be accepted (status=$RUN_STATUS)"
        show "$OUT"
    fi
done

# The trap: 32-bit Termux on a 64-bit phone. Must be refused, and must get the
# explanation saying the *device* is 64-bit but the *Termux* is not.
check_arch_case "armv8l"
if [ "$RUN_STATUS" -ne 0 ] && grep -q "32-bit" <<< "$OUT" && grep -q "legacy/proot" <<< "$OUT"; then
    pass "armv8l refused with 32-bit-Termux explanation"
else
    fail "armv8l must be refused with the 32-bit-Termux explanation (status=$RUN_STATUS)"
    show "$OUT"
fi

# Genuine 32-bit devices must be refused with a legacy pointer.
for arch in armv7l arm i686 i386; do
    check_arch_case "$arch"
    if [ "$RUN_STATUS" -ne 0 ] && grep -q "Unsupported architecture" <<< "$OUT" && grep -q "legacy/proot" <<< "$OUT"; then
        pass "$arch refused with legacy pointer"
    else
        fail "$arch should be refused with a legacy pointer (status=$RUN_STATUS)"
        show "$OUT"
    fi
done

# Unknown architectures must fail closed, not fall through to an install.
check_arch_case "riscv64"
if [ "$RUN_STATUS" -ne 0 ] && grep -q "Unrecognised architecture" <<< "$OUT"; then
    pass "unknown arch (riscv64) fails closed"
else
    fail "unknown arch must fail closed (status=$RUN_STATUS)"
    show "$OUT"
fi

# ---------------------------------------------------------------------------

section "setup.sh — method routing (NATIVE_OK)"

detect_arch_case() {
    local arch="$1" tmp
    tmp=$(mktemp -d)

    cat > "$tmp/uname" <<STUB
#!/bin/bash
echo "$arch"
STUB
    chmod +x "$tmp/uname"

    {
        extract_function "$SETUP_SH" detect_arch
        echo 'detect_arch; echo "ARCH=$ARCH NATIVE_OK=$NATIVE_OK"'
    } > "$tmp/run.sh"

    PATH="$tmp:$PATH" bash "$tmp/run.sh" > "$tmp/out" 2>&1
    RUN_STATUS=$?
    OUT="$(cat "$tmp/out")"
    rm -rf "$tmp"
}

for arch in aarch64 x86_64; do
    detect_arch_case "$arch"
    if grep -q "NATIVE_OK=1" <<< "$OUT"; then
        pass "$arch routes to Recommended (native)"
    else
        fail "$arch should set NATIVE_OK=1"
        show "$OUT"
    fi
done

for arch in armv8l armv7l i686; do
    detect_arch_case "$arch"
    if grep -q "NATIVE_OK=0" <<< "$OUT"; then
        pass "$arch routes to Legacy (PRoot)"
    else
        fail "$arch should set NATIVE_OK=0"
        show "$OUT"
    fi
done

# ---------------------------------------------------------------------------

section "launcher — readiness polling"

poll_case() {
    local curl_exit="$1" tmp
    tmp=$(mktemp -d)

    cat > "$tmp/curl" <<STUB
#!/bin/bash
exit $curl_exit
STUB
    cat > "$tmp/sleep" <<'STUB'
#!/bin/bash
:
STUB
    chmod +x "$tmp/curl" "$tmp/sleep"

    {
        harness_preamble
        # The generated launcher carries its own copies; the installer's are
        # behaviourally identical and easier to extract.
        extract_function "$MOMOS_SH" server_up
        extract_function "$MOMOS_SH" wait_for_server
        echo 'if wait_for_server 3; then echo "READY"; else echo "GAVE_UP"; fi'
    } > "$tmp/run.sh"

    PATH="$tmp:$PATH" bash "$tmp/run.sh" > "$tmp/out" 2>&1
    RUN_STATUS=$?
    OUT="$(cat "$tmp/out")"
    rm -rf "$tmp"
}

# Must give up rather than hang forever when the API never answers.
poll_case 1
if grep -q "GAVE_UP" <<< "$OUT"; then
    pass "wait_for_server gives up when API never answers"
else
    fail "wait_for_server should give up, got: $OUT"
fi

# Must return as soon as the API answers.
poll_case 0
if grep -q "READY" <<< "$OUT"; then
    pass "wait_for_server succeeds once the API answers"
else
    fail "wait_for_server should succeed, got: $OUT"
fi

# ---------------------------------------------------------------------------

section "momos.sh — size formatting"

fmt_case() {
    local tmp
    tmp=$(mktemp -d)
    {
        harness_preamble
        extract_function "$MOMOS_SH" fmt_size
        echo "fmt_size $1"
    } > "$tmp/run.sh"
    OUT=$(bash "$tmp/run.sh" 2>&1)
    rm -rf "$tmp"
}

fmt_case 8192
if [ "$OUT" = "8.0GB (8192MB)" ]; then
    pass "8192MB renders as 8.0GB (8192MB)"
else
    fail "unexpected formatting: $OUT"
fi

fmt_case 7986
if [ "$OUT" = "7.8GB (7986MB)" ]; then
    pass "non-round RAM renders as 7.8GB (7986MB)"
else
    fail "unexpected formatting: $OUT"
fi

# ---------------------------------------------------------------------------

section "momos.sh — storage detection (df portability)"

# Reproduces the on-device failure: GNU df accepts -Pk, toybox rejects -P and
# only answers to -k, and a broken df yields nothing usable.
storage_case() {
    local mode="$1" tmp
    tmp=$(mktemp -d)

    case "$mode" in
        gnu)
            cat > "$tmp/df" <<'STUB'
#!/bin/bash
echo "Filesystem     1024-blocks     Used Available Capacity Mounted on"
echo "/dev/block/dm-5  128000000 40000000  88000000      32% /data"
STUB
            ;;
        toybox)
            cat > "$tmp/df" <<'STUB'
#!/bin/bash
for a in "$@"; do
    if [ "$a" = "-Pk" ]; then
        echo "df: Unknown option -P" >&2
        exit 1
    fi
done
echo "Filesystem     1024-blocks     Used Available Capacity Mounted on"
echo "/dev/block/dm-5  128000000 40000000  88000000      32% /data"
STUB
            ;;
        broken)
            cat > "$tmp/df" <<'STUB'
#!/bin/bash
echo "df: something else went wrong" >&2
exit 1
STUB
            ;;
    esac
    chmod +x "$tmp/df"

    {
        harness_preamble
        echo "LOG_FILE=$tmp/diag.log"
        extract_function "$MOMOS_SH" is_number
        extract_function "$MOMOS_SH" log_storage_diagnostics
        extract_function "$MOMOS_SH" get_free_storage_mb
        echo 'echo "MB=$(get_free_storage_mb)"'
    } > "$tmp/run.sh"

    PATH="$tmp:$PATH" bash "$tmp/run.sh" > "$tmp/out" 2>&1
    RUN_STATUS=$?
    OUT="$(cat "$tmp/out")"
    DIAG="$(cat "$tmp/diag.log" 2>/dev/null || true)"
    rm -rf "$tmp"
}

# 88000000 KB / 1024 = 85937 MB
storage_case gnu
if grep -q "MB=85937" <<< "$OUT"; then
    pass "GNU df (-Pk) parses correctly"
else
    fail "GNU df should yield 85937MB, got: $OUT"
fi

storage_case toybox
if grep -q "MB=85937" <<< "$OUT"; then
    pass "toybox df (rejects -Pk) falls back to -k"
else
    fail "toybox df should fall back to -k and yield 85937MB, got: $OUT"
fi

storage_case broken
if grep -q "MB=0" <<< "$OUT"; then
    pass "unusable df reports 0 rather than a bogus number"
else
    fail "broken df should report 0, got: $OUT"
fi

if grep -q "storage detection failed" <<< "$DIAG"; then
    pass "failed detection writes diagnostics to the log"
else
    fail "failed detection should log diagnostics for the device"
fi

# ---------------------------------------------------------------------------

section "repo layout"

if [ -f "$LEGACY_SH" ] && [ -f "$REPO_ROOT/scripts/legacy/proot/setup.sh" ]; then
    pass "legacy/proot/ holds a complete PRoot snapshot"
else
    fail "legacy/proot/ is missing one of momos.sh / setup.sh"
fi

if [ -f "$REPO_ROOT/scripts/legacy/pre-momos/setup.sh" ] && [ -f "$REPO_ROOT/scripts/legacy/pre-momos/momo_setup.sh" ]; then
    pass "legacy/pre-momos/ holds the early prototypes"
else
    fail "legacy/pre-momos/ is incomplete"
fi

# The active installer must not reference proot-distro any more.
if grep -q "proot-distro" "$MOMOS_SH"; then
    fail "scripts/momos.sh still references proot-distro"
else
    pass "scripts/momos.sh is free of proot-distro"
fi

# ...but the legacy snapshot must, or it would not work.
if grep -q "proot-distro" "$LEGACY_SH"; then
    pass "legacy snapshot retains proot-distro"
else
    fail "legacy snapshot lost proot-distro"
fi

# setup.sh must not set up PRoot itself — it only routes to the legacy script,
# which is fetched at runtime. It does still call `proot-distro remove` in the
# uninstall path, deliberately, to tear down an existing legacy install.
if grep -qE "proot-distro (install|add)" "$SETUP_SH"; then
    fail "scripts/setup.sh still installs proot-distro itself"
else
    pass "scripts/setup.sh never installs proot-distro"
fi

# ---------------------------------------------------------------------------

printf '\n\033[1m%s\033[0m\n' "────────────────────────────────"
printf '  \033[0;32m%d passed\033[0m' "$PASS"
if [ "$FAIL" -gt 0 ]; then
    printf ', \033[0;31m%d failed\033[0m' "$FAIL"
fi
printf '\n\n'

[ "$FAIL" -eq 0 ]
