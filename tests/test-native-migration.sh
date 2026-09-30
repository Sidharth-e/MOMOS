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
UI_HTML="$REPO_ROOT/scripts/ui/index.html"

PASS=0
FAIL=0

# Populated by the run_* helpers. Output goes through a file rather than
# command substitution so the exit status survives out of the subshell.
OUT=""
RUN_STATUS=0
DIAG=""
FETCHED=""
KEPT=""      # what survived on disk after a case that may have clobbered it
JSON=""      # contents of a file a case generated
LINES=""     # line count of that file
CURLED=""    # whether a stub curl was invoked

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

section "launcher — momos serve --lan"

# cmd_serve is where "expose the server" is either true or a lie the user
# cannot see through: a bare `ollama serve` looks identical to an exposed one
# from inside the phone. Most of what follows checks the bind it chose.
#
# lan_ip and lan_reachable are stubbed rather than extracted — the address and
# the reachability probe are inputs to the decision, not the decision. The
# ollama stub prints the environment it was handed, which is the only way to
# assert on an export that exists solely for the lifetime of that one command.
serve_case() {
    local args="$1" up="$2" ip="$3" reachable="$4" tmp
    tmp=$(mktemp -d)
    mkdir -p "$tmp/home/.momos"

    cat > "$tmp/ollama" <<'STUB'
#!/bin/bash
echo "OLLAMA_HOST=${OLLAMA_HOST:-<unset>}"
echo "OLLAMA_ORIGINS=${OLLAMA_ORIGINS:-<unset>}"
echo "OLLAMA_INVOKED=1"
STUB
    chmod +x "$tmp/ollama"

    {
        echo 'set -euo pipefail'
        echo "LOG_DIR='$tmp/home/.momos'"
        echo 'STATE_FILE=$LOG_DIR/state'
        echo 'UI_DIR=$LOG_DIR/ui'
        echo 'UI_VERSION="2"'
        echo 'OLLAMA_URL="http://127.0.0.1:11434"'
        echo 'MODEL=""'
        echo "server_up() { return $up; }"
        echo "lan_ip() { [ -n '$ip' ] || return 1; printf '%s\\n' '$ip'; }"
        echo "lan_reachable() { return $reachable; }"
        extract_function "$MOMOS_SH" print_lan_urls
        extract_function "$MOMOS_SH" cmd_serve
        echo "cmd_serve $args"
    } > "$tmp/run.sh"

    PATH="$tmp:$PATH" bash "$tmp/run.sh" > "$tmp/out" 2>&1
    RUN_STATUS=$?
    OUT="$(cat "$tmp/out")"
    rm -rf "$tmp"
}

# The launcher has no info/success/warn/fail — those are installer-scope, and
# the installer is long gone by the time this runs. Omitting harness_preamble
# and emitting the real `set -euo pipefail` means a function that reached for
# one would fail here as "command not found", exactly as it would on the phone.
# It also re-checks the ${1:-} and `|| true` discipline the strict mode needs.
serve_case '' 1 '192.168.1.42' 0
if [ "$RUN_STATUS" -eq 0 ] \
    && grep -qxF 'OLLAMA_HOST=127.0.0.1:11434' <<< "$OUT" \
    && grep -qxF 'OLLAMA_ORIGINS=<unset>' <<< "$OUT"; then
    pass "bare 'serve' pins loopback and sets no origins"
else
    fail "bare 'serve' should bind 127.0.0.1 only (status=$RUN_STATUS)"
    show "$OUT"
fi

serve_case '--lan' 1 '192.168.1.42' 0
if [ "$RUN_STATUS" -eq 0 ] \
    && grep -qxF 'OLLAMA_HOST=0.0.0.0:11434' <<< "$OUT" \
    && grep -qxF 'OLLAMA_ORIGINS=http://192.168.1.42:*' <<< "$OUT"; then
    pass "'serve --lan' binds all interfaces with the exact-IP origin"
else
    fail "--lan should export OLLAMA_HOST=0.0.0.0:11434 and the exact-IP origin (status=$RUN_STATUS)"
    show "$OUT"
fi

# A bare `*` would let any page the user visits drive and delete the phone's
# models, and a subnet form would accept http://192.168.1.5.evil.com. The
# exact-IP form is a real control, so it is asserted against explicitly.
if grep -qxF 'OLLAMA_ORIGINS=*' <<< "$OUT"; then
    fail "the origin must never be a bare '*': any web page could then use the phone"
else
    pass "the origin is never a bare '*'"
fi

serve_case '--lan' 1 '' 0
if [ "$RUN_STATUS" -eq 0 ] \
    && grep -qxF 'OLLAMA_HOST=0.0.0.0:11434' <<< "$OUT" \
    && grep -qxF 'OLLAMA_ORIGINS=<unset>' <<< "$OUT" \
    && grep -qF 'OLLAMA_ORIGINS=' <<< "$OUT"; then
    pass "--lan with no detectable address still binds, and prints the override"
else
    fail "--lan should bind anyway and explain the CORS block (status=$RUN_STATUS)"
    show "$OUT"
fi

# The failure this whole flag exists to prevent. A server started earlier by
# `momos chat` is up, so the old code answered "already running" and exited 0
# while the laptop could not connect and nothing on screen said so.
serve_case '--lan' 0 '192.168.1.42' 1
if [ "$RUN_STATUS" -ne 0 ] \
    && grep -q 'momos stop' <<< "$OUT" \
    && ! grep -q 'OLLAMA_INVOKED=1' <<< "$OUT"; then
    pass "loopback-only server: --lan explains, fails, and does not restart it"
else
    fail "a private server must not be reported as exposed (status=$RUN_STATUS)"
    show "$OUT"
fi

# Not restarting matters: a restart would kill a chat in progress in the other
# Termux session, so the reachable case must report and return without touching
# the server.
serve_case '--lan' 0 '192.168.1.42' 0
if [ "$RUN_STATUS" -eq 0 ] \
    && ! grep -q 'OLLAMA_INVOKED=1' <<< "$OUT" \
    && grep -q '/v1' <<< "$OUT"; then
    pass "already-exposed server: --lan reports success without restarting"
else
    fail "an already-exposed server should be reported, not restarted (status=$RUN_STATUS)"
    show "$OUT"
fi

serve_case '--lan' 0 '' 0
if [ "$RUN_STATUS" -ne 0 ] && ! grep -q 'OLLAMA_INVOKED=1' <<< "$OUT"; then
    pass "up server with no detectable address refuses to guess"
else
    fail "should not claim exposure when the address is unknown (status=$RUN_STATUS)"
    show "$OUT"
fi

serve_case '' 0 '192.168.1.42' 0
if [ "$RUN_STATUS" -eq 0 ] && ! grep -q 'OLLAMA_INVOKED=1' <<< "$OUT"; then
    pass "bare 'serve' over a running server still reports and returns"
else
    fail "bare 'serve' should keep today's already-running behaviour (status=$RUN_STATUS)"
    show "$OUT"
fi

# A typo silently ignored would leave a loopback server running while the user
# believes they are exposed.
for bad in '-lan' '--lans'; do
    serve_case "$bad" 1 '192.168.1.42' 0
    if [ "$RUN_STATUS" -ne 0 ] \
        && grep -q "Unknown option: $bad" <<< "$OUT" \
        && grep -q 'Usage: momos serve' <<< "$OUT" \
        && ! grep -q 'OLLAMA_INVOKED=1' <<< "$OUT"; then
        pass "'$bad' rejected with usage instead of starting a private server"
    else
        fail "'$bad' must be rejected, not ignored (status=$RUN_STATUS)"
        show "$OUT"
    fi
done

serve_case '--lan --foo' 1 '192.168.1.42' 0
if [ "$RUN_STATUS" -ne 0 ] \
    && grep -q 'Too many arguments' <<< "$OUT" \
    && ! grep -q 'OLLAMA_INVOKED=1' <<< "$OUT"; then
    pass "a second argument is refused rather than half-applied"
else
    fail "extra arguments should be refused (status=$RUN_STATUS)"
    show "$OUT"
fi

# ---------------------------------------------------------------------------

# The empty-address guard is not cosmetic: under `set -e` a curl to
# "http://:11434" would abort the whole CLI, and `momos serve --lan` calls it
# on a path where no address is already known.
lan_reachable_case() {
    local ip="$1" curl_status="$2" tmp
    tmp=$(mktemp -d)

    cat > "$tmp/curl" <<STUB
#!/bin/bash
echo "CURLED" >> '$tmp/curl.log'
exit $curl_status
STUB
    chmod +x "$tmp/curl"

    {
        echo 'set -euo pipefail'
        extract_function "$MOMOS_SH" lan_reachable
        echo "if lan_reachable '$ip'; then echo REACHABLE; else echo UNREACHABLE; fi"
    } > "$tmp/run.sh"

    PATH="$tmp:$PATH" bash "$tmp/run.sh" > "$tmp/out" 2>&1
    RUN_STATUS=$?
    OUT="$(cat "$tmp/out")"
    CURLED="$(grep -c CURLED "$tmp/curl.log" 2>/dev/null || echo 0)"
    rm -rf "$tmp"
}

lan_reachable_case '' 0
if [ "$RUN_STATUS" -eq 0 ] && [ "$OUT" = "UNREACHABLE" ] && [ "$CURLED" = "0" ]; then
    pass "lan_reachable with no address gives up without probing the network"
else
    fail "an empty address must not be probed (status=$RUN_STATUS, curl=$CURLED)"
    show "$OUT"
fi

lan_reachable_case '192.168.1.42' 7
if [ "$RUN_STATUS" -eq 0 ] && [ "$OUT" = "UNREACHABLE" ] && [ "$CURLED" = "1" ]; then
    pass "a refused probe reports unreachable rather than aborting under set -e"
else
    fail "a failed probe must return 1, not kill the CLI (status=$RUN_STATUS)"
    show "$OUT"
fi

# ---------------------------------------------------------------------------

section "launcher — the UI page stays current, and survives being offline"

# The page is fetched, so there is a working copy and a network between them,
# and every interesting failure lives in the gap: an install too old to have
# the marker, a phone with no signal, and a captive portal answering 200 with
# somebody else's HTML.
#
# The curl stub creates and truncates its -o target *before* it fails, because
# real curl does — that is precisely the behaviour index.html.new exists to
# contain, and a stub that failed without touching the file would not test it.
ui_fetch_case() {
    local cached="$1" curl_mode="$2" body="$3" tmp
    tmp=$(mktemp -d)
    mkdir -p "$tmp/home/.momos/ui"

    if [ -n "$cached" ]; then
        printf '%s' "$cached" > "$tmp/home/.momos/ui/index.html"
    fi

    cat > "$tmp/curl" <<'STUB'
#!/bin/bash
out=""
while [ $# -gt 0 ]; do
    case "$1" in
        -o) out="$2"; shift 2 ;;
        *) shift ;;
    esac
done
echo "CALLED" >> "$CURL_LOG"
if [ -n "$out" ]; then
    printf '%s' "$CURL_BODY" > "$out"
fi
[ "$CURL_MODE" = fail ] && exit 22
exit 0
STUB
    chmod +x "$tmp/curl"

    {
        echo 'set -euo pipefail'
        echo "LOG_DIR='$tmp/home/.momos'"
        echo 'UI_DIR=$LOG_DIR/ui'
        echo 'UI_VERSION="2"'
        extract_function "$MOMOS_SH" ensure_ui_files
        echo 'ensure_ui_files'
        echo 'echo "REACHED_END"'
    } > "$tmp/run.sh"

    CURL_LOG="$tmp/curl.log" CURL_MODE="$curl_mode" CURL_BODY="$body" \
        PATH="$tmp:$PATH" bash "$tmp/run.sh" > "$tmp/out" 2>&1
    RUN_STATUS=$?
    OUT="$(cat "$tmp/out")"
    FETCHED="$(cat "$tmp/curl.log" 2>/dev/null || true)"
    KEPT="$(cat "$tmp/home/.momos/ui/index.html" 2>/dev/null || echo '<missing>')"
    rm -rf "$tmp"
}

old_page='<!-- momos-ui:1 -->
the older page'
new_page='<!-- momos-ui:2 -->
the newer page'

ui_fetch_case "$new_page" fail ''
if [ "$RUN_STATUS" -eq 0 ] && [ -z "$FETCHED" ] && grep -qx 'REACHED_END' <<< "$OUT"; then
    pass "a current page is not fetched again"
else
    fail "the marker should short-circuit the fetch (status=$RUN_STATUS, curl='$FETCHED')"
    show "$OUT"
fi

ui_fetch_case "$old_page" ok "$new_page"
if [ "$RUN_STATUS" -eq 0 ] && [ "$KEPT" = "$new_page" ] && [ -n "$FETCHED" ]; then
    pass "an outdated page is replaced"
else
    fail "an outdated page should be replaced, kept: '$KEPT'"
    show "$OUT"
fi

ui_fetch_case '' ok "$new_page"
if [ "$RUN_STATUS" -eq 0 ] && [ "$KEPT" = "$new_page" ]; then
    pass "a first install writes the page"
else
    fail "a missing page should be installed, kept: '$KEPT'"
    show "$OUT"
fi

# Offline-first. `momos update` on a phone with no network must not delete the
# page it already has — the old code wrote straight to index.html with curl -o,
# which truncates before the transfer can fail.
ui_fetch_case "$old_page" fail "$new_page"
if [ "$RUN_STATUS" -eq 0 ] && [ "$KEPT" = "$old_page" ]; then
    pass "a failed refresh keeps the cached page byte-for-byte and exits 0"
else
    fail "an offline refresh must not destroy the working page (status=$RUN_STATUS)"
    show "kept: $KEPT"
    show "$OUT"
fi

# A captive portal is the reason the download is checked for our own marker at
# all: it answers 200 with a login page, and a naive check for `curl` success
# would install it and break the UI on the device.
ui_fetch_case "$old_page" ok '<html>Sign in to the Wi-Fi</html>'
if [ "$RUN_STATUS" -eq 0 ] && [ "$KEPT" = "$old_page" ]; then
    pass "a response without the marker is refused and the old page kept"
else
    fail "a page that is not ours must not be installed, kept: '$KEPT'"
    show "$OUT"
fi

# The fast path wants this exact version, not any marker: a page stamped for a
# future launcher would otherwise pin the device on a page the CLI has moved
# past. The trailing `-->` in the pattern is what makes the match exact.
ui_fetch_case '<!-- momos-ui:20 -->
ahead of the CLI' fail ''
if [ "$RUN_STATUS" -eq 0 ] && [ -n "$FETCHED" ]; then
    pass "the marker match is exact, not a prefix"
else
    fail "momos-ui:20 must not satisfy momos-ui:2 (curl='$FETCHED')"
    show "$OUT"
fi

ui_fetch_case '' fail ''
if [ "$RUN_STATUS" -ne 0 ] && grep -q 'Could not download the UI page' <<< "$OUT"; then
    pass "no cached page and no network is still a hard failure"
else
    fail "a first install with no network must fail loudly (status=$RUN_STATUS)"
    show "$OUT"
fi

# ---------------------------------------------------------------------------

section "launcher — the runtime.json the page reads for its model"

runtime_case() {
    local model="$1" tmp
    tmp=$(mktemp -d)
    mkdir -p "$tmp/ui"

    {
        echo 'set -euo pipefail'
        echo "UI_DIR='$tmp/ui'"
        extract_function "$MOMOS_SH" write_runtime_json
        echo "write_runtime_json '$model'"
    } > "$tmp/run.sh"

    PATH="$tmp:$PATH" bash "$tmp/run.sh" > "$tmp/out" 2>&1
    RUN_STATUS=$?
    OUT="$(cat "$tmp/out")"
    JSON="$(cat "$tmp/ui/runtime.json" 2>/dev/null || echo '<missing>')"
    LINES="$(wc -l < "$tmp/ui/runtime.json" 2>/dev/null | tr -d ' ' || echo 0)"
    rm -rf "$tmp"
}

runtime_case 'deepseek-r1:1.5b'
if [ "$RUN_STATUS" -eq 0 ] && [ "$JSON" = '{"model":"deepseek-r1:1.5b","ollama_port":11434}' ]; then
    pass "a normal model is written verbatim"
else
    fail "unexpected runtime.json: '$JSON' (status=$RUN_STATUS)"
    show "$OUT"
fi

# The state file is normally one line written by `momos chat`, but it is a file
# on a phone that anything could have edited. A quote or backslash reaching the
# JSON would produce a parse error the page reads as "no model", with nothing
# on screen to explain why.
runtime_case 'a"b\c'
if [ "$RUN_STATUS" -eq 0 ] && [ "$JSON" = '{"model":"abc","ollama_port":11434}' ]; then
    pass "quotes and backslashes are stripped rather than emitted raw"
else
    fail "unsafe characters should be stripped, got: '$JSON'"
    show "$OUT"
fi

runtime_case ''
if [ "$RUN_STATUS" -eq 0 ] && [ "$JSON" = '{"model":"","ollama_port":11434}' ]; then
    pass "an empty state yields a valid object, not a malformed one"
else
    fail "an empty model should still be valid JSON, got: '$JSON'"
    show "$OUT"
fi

runtime_case $'first\nsecond'
if [ "$RUN_STATUS" -eq 0 ] \
    && [ "$JSON" = '{"model":"first","ollama_port":11434}' ] \
    && [ "$LINES" = "1" ]; then
    pass "a multi-line state file yields one line of JSON"
else
    fail "a multi-line state should collapse to its first line, got: '$JSON' ($LINES lines)"
    show "$OUT"
fi

# ---------------------------------------------------------------------------

section "launcher — momos ui wiring"

# cmd_ui has to have written runtime.json before serve_ui execs, because exec
# replaces the process and no later statement ever runs. serve_ui is therefore
# replaced after extraction — in the real script it execs, which would end this
# harness. The launcher's own MODEL preamble is reproduced rather than assumed,
# so what is tested is how the device actually reads its state.
ui_wiring_case() {
    local model="$1" tmp
    tmp=$(mktemp -d)
    mkdir -p "$tmp/home/.momos"

    if [ -n "$model" ]; then
        printf '%s\n' "$model" > "$tmp/home/.momos/state"
    fi

    {
        echo 'set -euo pipefail'
        echo "LOG_DIR='$tmp/home/.momos'"
        echo 'STATE_FILE=$LOG_DIR/state'
        echo 'SERVER_LOG=$LOG_DIR/server.log'
        echo 'UI_DIR=$LOG_DIR/ui'
        echo 'UI_VERSION="2"'
        echo 'OLLAMA_URL="http://127.0.0.1:11434"'
        echo 'MODEL=""'
        echo 'if [ -f "$STATE_FILE" ]; then'
        echo '    MODEL=$(cat "$STATE_FILE")'
        echo 'fi'
        extract_function "$MOMOS_SH" is_number
        extract_function "$MOMOS_SH" valid_port
        extract_function "$MOMOS_SH" write_runtime_json
        extract_function "$MOMOS_SH" cmd_ui
        # Defined after cmd_ui, so these replace the real ones: later wins.
        echo 'ensure_ui_files() { echo "STEP:ensure_ui"; mkdir -p "$UI_DIR"; }'
        echo 'install_httpd() { echo darkhttpd; }'
        echo 'lan_ip() { echo 192.168.1.42; }'
        echo 'serve_ui() { echo "STEP:serve_ui"; cat "$UI_DIR/runtime.json"; }'
        echo 'cmd_ui'
    } > "$tmp/run.sh"

    MOMOS_UI_NO_OPEN=1 PATH="$tmp:$PATH" bash "$tmp/run.sh" > "$tmp/out" 2>&1
    RUN_STATUS=$?
    OUT="$(cat "$tmp/out")"
    rm -rf "$tmp"
}

ui_wiring_case 'llama3.2:3b'
ensure_line=$(grep -n 'STEP:ensure_ui' <<< "$OUT" | cut -d: -f1)
serve_line=$(grep -n 'STEP:serve_ui' <<< "$OUT" | cut -d: -f1)
json_line=$(grep -n '^{"model"' <<< "$OUT" | cut -d: -f1)

if [ "$RUN_STATUS" -eq 0 ] \
    && [ -n "$ensure_line" ] && [ -n "$serve_line" ] \
    && [ "$ensure_line" -lt "$serve_line" ]; then
    pass "the page is ensured before the server is started"
else
    fail "ordering wrong: ensure=$ensure_line serve=$serve_line (status=$RUN_STATUS)"
    show "$OUT"
fi

if [ -n "$json_line" ] && [ "$json_line" -gt "$serve_line" ]; then
    pass "runtime.json is written by the time serve_ui runs"
else
    fail "runtime.json must exist before serve_ui (json=$json_line, serve=$serve_line)"
    show "$OUT"
fi

if grep -qx '{"model":"llama3.2:3b","ollama_port":11434}' <<< "$OUT"; then
    pass "runtime.json carries the last-used model through to the page"
else
    fail "expected the state file's model in runtime.json"
    show "$OUT"
fi

# The launcher runs under `set -u`, and a first run has no state file at all.
# An unbound $MODEL here would make `momos ui` fail before serving anything.
ui_wiring_case ''
if [ "$RUN_STATUS" -eq 0 ] && grep -qx '{"model":"","ollama_port":11434}' <<< "$OUT"; then
    pass "ui works with no model chosen yet, under set -u"
else
    fail "an unset model must not abort 'momos ui' (status=$RUN_STATUS)"
    show "$OUT"
fi

# ---------------------------------------------------------------------------

section "launcher — the pieces two files must agree on"

# Args reach cmd_serve only because the dispatcher shifts the command name off
# first. Without the shift, even a bare `momos serve` lands in the
# unknown-option branch, and `--lan` would be read as the command name.
if grep -qE '^[[:space:]]*serve\)[[:space:]]+shift; cmd_serve "\$@" ;;' "$MOMOS_SH"; then
    pass "the serve dispatch forwards its arguments"
else
    fail "dispatch must be 'serve) shift; cmd_serve \"\$@\" ;;' — options are dropped otherwise"
fi

# The version lives in two files that cannot import from each other: the
# launcher is a quoted heredoc, so it cannot interpolate the page at install
# time. Drifting apart means the device refetches forever, or never.
script_version=$(sed -n 's/^UI_VERSION="\([^"]*\)"$/\1/p' "$MOMOS_SH" | head -n1)
page_version=$(sed -n 's/.*<!-- momos-ui:\([0-9][0-9]*\) -->.*/\1/p' "$UI_HTML" | head -n1)

if [ -n "$script_version" ] && [ "$script_version" = "$page_version" ]; then
    pass "UI_VERSION in momos.sh matches the marker in index.html ($script_version)"
else
    fail "version drift: momos.sh has '$script_version', index.html has '$page_version'"
fi

help_text=$(sed -n '/^show_help() {/,/^}/p' "$MOMOS_SH")

if grep -q 'serve \[--lan\]' <<< "$help_text"; then
    pass "help documents 'serve [--lan]'"
else
    fail "help should document the --lan option"
fi

if grep -q 'momos stop' <<< "$help_text"; then
    pass "help documents 'stop', which --lan's failure path tells the user to run"
else
    fail "help should list 'stop' — the loopback-only path sends you to it"
fi

# The page is static HTML with no build step, so nothing else would catch a
# transport that was renamed or a marker that was dropped.
page_has() {
    if grep -qF "$1" "$UI_HTML"; then
        pass "index.html has $2"
    else
        fail "index.html is missing $2 (expected to find '$1')"
    fi
}

page_has '/api/chat' 'the chat endpoint'
page_has 'runtime.json' 'the runtime config lookup'
page_has 'AbortController' 'the stop button'
page_has 'aria-live' 'the live-region attributes'
page_has 'role="status"' 'the status region'
page_has 'prefers-reduced-motion' 'a reduced-motion branch'
page_has ':focus-visible' 'a visible focus style'
page_has 'textContent' 'text-node insertion'

# The page talks to the native API because /v1 cannot express keep_alive. If it
# ever reached for the compatibility surface, the reasoning models the README
# recommends would silently lose their thinking field.
if grep -q '/v1' "$UI_HTML"; then
    fail "index.html should use /api/chat — /v1 cannot express keep_alive or num_ctx"
else
    pass "index.html stays on the native API"
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
