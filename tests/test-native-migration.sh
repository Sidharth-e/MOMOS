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
DIAG=""
FETCHED=""

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

section "launcher — which ref does 'momos update' follow?"

# The launcher's own cmd_update is the copy that actually ships, since it lives
# inside the heredoc written to $PREFIX/bin/momos (the heredoc body sits at
# column 0, so it extracts like any other function).
update_ref_case() {
    local recorded="$1" env_branch="$2" tmp
    tmp=$(mktemp -d)
    mkdir -p "$tmp/home/.momos"

    if [ -n "$recorded" ]; then
        echo "$recorded" > "$tmp/home/.momos/branch"
    fi

    cat > "$tmp/curl" <<'STUB'
#!/bin/bash
echo "$@" >> "$CURL_LOG"
exit 0
STUB
    cat > "$tmp/pkg" <<'STUB'
#!/bin/bash
exit 0
STUB
    chmod +x "$tmp/curl" "$tmp/pkg"

    {
        echo "HOME=$tmp/home"
        echo 'LOG_DIR=$HOME/.momos'
        if [ -n "$env_branch" ]; then
            echo "MOMOS_BRANCH='$env_branch'"
        fi
        extract_function "$MOMOS_SH" cmd_update
        echo 'cmd_update'
    } > "$tmp/run.sh"

    CURL_LOG="$tmp/curl.log" PATH="$tmp:$PATH" bash "$tmp/run.sh" > "$tmp/out" 2>&1
    RUN_STATUS=$?
    OUT="$(cat "$tmp/out")"
    FETCHED="$(cat "$tmp/curl.log" 2>/dev/null || true)"
    rm -rf "$tmp"
}

# The point of the branch file: a branch install must not quietly snap back to
# main on the next update.
update_ref_case "feat/cross-device-access" ""
if grep -q "feat/cross-device-access/scripts/momos.sh" <<< "$FETCHED"; then
    pass "update follows the recorded branch"
else
    fail "update should follow the recorded branch, fetched: $FETCHED"
fi

# A pre-branch install has no branch file and must still work.
update_ref_case "" ""
if grep -q "main/scripts/momos.sh" <<< "$FETCHED"; then
    pass "update falls back to main when no branch was recorded"
else
    fail "update should fall back to main, fetched: $FETCHED"
fi

# An explicit MOMOS_BRANCH wins, so a branch can be switched deliberately.
update_ref_case "main" "feat/cross-device-access"
if grep -q "feat/cross-device-access/scripts/momos.sh" <<< "$FETCHED"; then
    pass "MOMOS_BRANCH overrides the recorded branch"
else
    fail "MOMOS_BRANCH should override the recorded branch, fetched: $FETCHED"
fi

# Getting the URL right is only half of it. The installer that cmd_update
# spawns resolves the ref for itself, and if it is not told which one, it
# defaults to main and writes main back into the branch file — quietly undoing
# the record on the very next update. These lines are lifted from the real
# script so this test cannot drift away from what actually runs.
installer_ref_lines() {
    grep -m1 '^MOMOS_BRANCH=' "$MOMOS_SH"
    grep -m1 '^export MOMOS_BRANCH' "$MOMOS_SH"
    grep -m1 '^MOMOS_RAW=' "$MOMOS_SH"
    grep -m1 'echo "\$MOMOS_BRANCH" > "\$LOG_DIR/branch"' "$MOMOS_SH" | sed 's/^[[:space:]]*//'
}

update_propagation_case() {
    local recorded="$1" tmp
    tmp=$(mktemp -d)
    mkdir -p "$tmp/home/.momos"
    echo "$recorded" > "$tmp/home/.momos/branch"

    # Stands in for the fetched installer: same ref resolution, same recording.
    {
        echo '#!/bin/bash'
        echo 'LOG_DIR=$HOME/.momos'
        installer_ref_lines
        echo 'echo "INSTALLER_SAW=${MOMOS_BRANCH}"'
        echo 'echo "INSTALLER_FETCHED=${MOMOS_RAW}/scripts/ui/index.html"'
    } > "$tmp/installer.bin"

    cat > "$tmp/curl" <<STUB
#!/bin/bash
cat "$tmp/installer.bin"
STUB
    cat > "$tmp/pkg" <<'STUB'
#!/bin/bash
exit 0
STUB
    chmod +x "$tmp/curl" "$tmp/pkg"

    {
        echo "HOME=$tmp/home"
        echo "LOG_DIR=$tmp/home/.momos"
        extract_function "$MOMOS_SH" cmd_update
        echo 'cmd_update'
    } > "$tmp/run.sh"

    PATH="$tmp:$PATH" bash "$tmp/run.sh" > "$tmp/out" 2>&1
    RUN_STATUS=$?
    OUT="$(cat "$tmp/out")"
    RECORDED_AFTER="$(cat "$tmp/home/.momos/branch" 2>/dev/null || echo '<missing>')"
    rm -rf "$tmp"
}

update_propagation_case "feat/cross-device-access"
if grep -qx "INSTALLER_SAW=feat/cross-device-access" <<< "$OUT"; then
    pass "the installer cmd_update spawns is told which ref to use"
else
    fail "installer defaulted to the wrong ref: $(grep INSTALLER_SAW <<< "$OUT" || echo '<no output>')"
fi

if [ "$RECORDED_AFTER" = "feat/cross-device-access" ]; then
    pass "update does not rewrite the recorded branch"
else
    fail "update clobbered the recorded branch with '$RECORDED_AFTER'"
fi

# Main is the correct fallback, and must survive being recorded as itself.
update_propagation_case "main"
if grep -qx "INSTALLER_SAW=main" <<< "$OUT" && [ "$RECORDED_AFTER" = "main" ]; then
    pass "update keeps main when main is the recorded ref"
else
    fail "main case wrong: saw=$(grep INSTALLER_SAW <<< "$OUT") recorded=$RECORDED_AFTER"
fi

# ---------------------------------------------------------------------------

section "launcher — web UI (port, LAN address, static server)"

# Ports below 1024 are privileged on Linux, and Termux is an unprivileged app,
# so the valid range starts at 1024.
port_case() {
    local port="$1" tmp
    tmp=$(mktemp -d)
    {
        harness_preamble
        extract_function "$MOMOS_SH" is_number
        extract_function "$MOMOS_SH" valid_port
        echo "if valid_port '$port'; then echo VALID; else echo INVALID; fi"
    } > "$tmp/run.sh"
    OUT=$(bash "$tmp/run.sh" 2>&1)
    rm -rf "$tmp"
}

for port in 1024 8080 65535; do
    port_case "$port"
    if [ "$OUT" = "VALID" ]; then
        pass "port $port accepted"
    else
        fail "port $port should be accepted, got: $OUT"
    fi
done

for port in 80 1023 0 65536 abc '' 80a; do
    port_case "$port"
    if [ "$OUT" = "INVALID" ]; then
        pass "port '${port}' rejected"
    else
        fail "port '${port}' should be rejected, got: $OUT"
    fi
done

# ---------------------------------------------------------------------------

ipv4_case() {
    local ip="$1" tmp
    tmp=$(mktemp -d)
    {
        extract_function "$MOMOS_SH" is_ipv4
        echo "if is_ipv4 '$ip'; then echo YES; else echo NO; fi"
    } > "$tmp/run.sh"
    OUT=$(bash "$tmp/run.sh" 2>&1)
    rm -rf "$tmp"
}

for ip in 192.168.1.42 127.0.0.1 10.0.0.1 255.255.255.255; do
    ipv4_case "$ip"
    if [ "$OUT" = "YES" ]; then
        pass "$ip recognised as IPv4"
    else
        fail "$ip should be recognised, got: $OUT"
    fi
done

for ip in 256.1.1.1 1.2.3 1.2.3.4.5 '' abc 192.168.1.; do
    ipv4_case "$ip"
    if [ "$OUT" = "NO" ]; then
        pass "'${ip}' rejected as IPv4"
    else
        fail "'${ip}' should be rejected, got: $OUT"
    fi
done

# ---------------------------------------------------------------------------

# A stock Termux has neither net-tools nor iproute2 for certain; which tools
# exist depends on what else pulled them in. Each mode reproduces one mix.
lan_ip_case() {
    local mode="$1" tmp
    tmp=$(mktemp -d)

    case "$mode" in
        # `ip route get` names the source address directly.
        ip-route)
            cat > "$tmp/ip" <<'STUB'
#!/bin/bash
echo "1.1.1.1 via 192.168.1.1 dev wlan0 src 192.168.1.42 uid 0"
STUB
            ;;
        # No route line, but the interface listing carries it. Loopback comes
        # first and must not win.
        ip-addr)
            cat > "$tmp/ip" <<'STUB'
#!/bin/bash
if [ "$1" = "-4" ] && [ "$2" = "addr" ]; then
    echo "1: lo: <LOOPBACK,UP> mtu 65536"
    echo "    inet 127.0.0.1/8 scope host lo"
    echo "3: wlan0: <BROADCAST,MULTICAST,UP> mtu 1500"
    echo "    inet 192.168.1.42/24 brd 192.168.1.255 scope global wlan0"
fi
STUB
            ;;
        # No iproute2, but net-tools' ifconfig answers.
        ifconfig)
            cat > "$tmp/ip" <<'STUB'
#!/bin/bash
exit 1
STUB
            cat > "$tmp/ifconfig" <<'STUB'
#!/bin/bash
echo "lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536"
echo "        inet 127.0.0.1  netmask 255.0.0.0"
echo "wlan0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500"
echo "        inet 192.168.1.42  netmask 255.255.255.0  broadcast 192.168.1.255"
STUB
            ;;
        # Android's toybox ifconfig spells it inet addr:.
        ifconfig-android)
            cat > "$tmp/ip" <<'STUB'
#!/bin/bash
exit 1
STUB
            cat > "$tmp/ifconfig" <<'STUB'
#!/bin/bash
echo "wlan0     Link encap:Ethernet"
echo "          inet addr:192.168.1.42  Bcast:192.168.1.255  Mask:255.255.255.0"
STUB
            ;;
        # Nothing usable installed: must give up rather than invent an address.
        none)
            cat > "$tmp/ip" <<'STUB'
#!/bin/bash
exit 1
STUB
            cat > "$tmp/ifconfig" <<'STUB'
#!/bin/bash
exit 1
STUB
            ;;
    esac
    chmod +x "$tmp"/*

    {
        extract_function "$MOMOS_SH" is_ipv4
        extract_function "$MOMOS_SH" lan_ip
        # Report the address and the status separately: `|| true` would mask
        # the exit code the "gives up" case exists to check.
        echo 'addr=$(lan_ip); status=$?'
        echo 'echo "IP:$addr"'
        echo 'echo "STATUS:$status"'
    } > "$tmp/run.sh"

    PATH="$tmp:$PATH" bash "$tmp/run.sh" > "$tmp/out" 2>&1
    RUN_STATUS=$?
    OUT="$(cat "$tmp/out")"
    rm -rf "$tmp"
}

# Helper so each case asserts on the address without repeating the marker.
lan_ip_should_be() {
    local want="$1" label="$2"
    if grep -qx "IP:$want" <<< "$OUT" && grep -qx "STATUS:0" <<< "$OUT"; then
        pass "$label"
    else
        fail "$label — expected '$want', got: $(tr '\n' ' ' <<< "$OUT")"
    fi
}

lan_ip_case ip-route
lan_ip_should_be "192.168.1.42" "ip route get yields the LAN address"

lan_ip_case ip-addr
lan_ip_should_be "192.168.1.42" "ip addr show yields the LAN address, skipping loopback"

lan_ip_case ifconfig
lan_ip_should_be "192.168.1.42" "ifconfig yields the LAN address, skipping loopback"

lan_ip_case ifconfig-android
lan_ip_should_be "192.168.1.42" "Android-style 'inet addr:' ifconfig is parsed"

# A wrong URL is worse than no URL — the user would type it on a laptop and
# get nothing, with no idea why.
lan_ip_case none
if grep -qx "IP:" <<< "$OUT" && grep -qx "STATUS:1" <<< "$OUT"; then
    pass "no address invented when no tool reports one, and it reports failure"
else
    fail "should give up quietly with a non-zero status, got: $(tr '\n' ' ' <<< "$OUT")"
fi

# ---------------------------------------------------------------------------

# Termux ships no web server. darkhttpd is ~1MB and serves static files, which
# is all the placeholder page needs; python is ~40MB that belongs to models.
httpd_case() {
    local mode="$1" tmp
    tmp=$(mktemp -d)

    case "$mode" in
        both)
            touch "$tmp/darkhttpd" "$tmp/python3"
            ;;
        darkhttpd-only)
            touch "$tmp/darkhttpd"
            ;;
        python-only)
            touch "$tmp/python3"
            ;;
        none) ;;
    esac
    chmod +x "$tmp"/* 2>/dev/null || true

    {
        extract_function "$MOMOS_SH" httpd_kind
        # PATH is narrowed so the host's own python3/darkhttpd cannot leak in
        # and mask the "nothing installed" case.
        echo "PATH='$tmp'"
        echo 'echo "KIND=$(httpd_kind)"'
    } > "$tmp/run.sh"

    OUT=$(bash "$tmp/run.sh" 2>&1)
    rm -rf "$tmp"
}

httpd_case both
if [ "$OUT" = "KIND=darkhttpd" ]; then
    pass "darkhttpd preferred when several servers are present"
else
    fail "darkhttpd should win, got: '$OUT'"
fi

httpd_case darkhttpd-only
if [ "$OUT" = "KIND=darkhttpd" ]; then
    pass "darkhttpd detected on its own"
else
    fail "expected darkhttpd, got: '$OUT'"
fi

httpd_case python-only
if [ "$OUT" = "KIND=python3" ]; then
    pass "python3 used when darkhttpd is absent"
else
    fail "expected python3, got: '$OUT'"
fi

httpd_case none
if [ "$OUT" = "KIND=" ]; then
    pass "no server reported when none is installed"
else
    fail "expected empty KIND, got: '$OUT'"
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

# The UI page is fetched to the device at install time, so it has to be a real
# file in the repo rather than something generated into the launcher.
UI_HTML="$REPO_ROOT/scripts/ui/index.html"
if [ -f "$UI_HTML" ]; then
    pass "scripts/ui/index.html exists"
else
    fail "scripts/ui/index.html is missing — 'momos ui' would have nothing to serve"
fi

# Both the installer and the launcher's self-heal path must point at the same
# path, or a fresh run and a `momos update` would disagree about where it lives.
if grep -q "scripts/ui/index.html" "$MOMOS_SH"; then
    pass "momos.sh knows where to fetch the UI page from"
else
    fail "momos.sh never references scripts/ui/index.html"
fi

# ---------------------------------------------------------------------------

printf '\n\033[1m%s\033[0m\n' "────────────────────────────────"
printf '  \033[0;32m%d passed\033[0m' "$PASS"
if [ "$FAIL" -gt 0 ]; then
    printf ', \033[0;31m%d failed\033[0m' "$FAIL"
fi
printf '\n\n'

[ "$FAIL" -eq 0 ]
