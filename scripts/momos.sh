#!/data/data/com.termux/files/usr/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

LOG_DIR="$HOME/.momos"
LOG_FILE="$LOG_DIR/install.log"
STATE_FILE="$LOG_DIR/state"
UI_DIR="$LOG_DIR/ui"
LAUNCHER_PATH="$PREFIX/bin/momos"
OLLAMA_URL="http://127.0.0.1:11434"

# Which ref the scripts fetch from. Override to install or test a branch:
#   MOMOS_BRANCH=my-branch bash -c "$(curl -fsSL .../my-branch/scripts/momos.sh)"
# Exported so the launcher and any child script inherit the same ref.
#
# A branch name is pasted into a URL path, so it is held to what a ref can
# actually contain. A `..` segment would otherwise climb out of this repository
# on the same host and fetch the launcher from somebody else's — and because the
# value is written to $LOG_DIR/branch, a bad one would be followed by every
# later update rather than only by this run.
MOMOS_BRANCH="${MOMOS_BRANCH:-main}"
case "$MOMOS_BRANCH" in
    ''|*[!A-Za-z0-9._/-]*|*..*)
        echo "Ignoring unusable MOMOS_BRANCH '$MOMOS_BRANCH' — using main." >&2
        MOMOS_BRANCH="main"
        ;;
esac
export MOMOS_BRANCH
MOMOS_RAW="https://raw.githubusercontent.com/Sidharth-e/MOMOS/${MOMOS_BRANCH}"
LEGACY_INSTALL_URL="${MOMOS_RAW}/scripts/legacy/proot/momos.sh"

mkdir -p "$LOG_DIR"

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"; }

info()    { echo -e "${BLUE}→${NC} $1"; log "INFO: $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; log "OK: $1"; }
warn()    { echo -e "${YELLOW}★${NC} $1"; log "WARN: $1"; }
fail()    { echo -e "${RED}✗${NC} $1"; log "ERROR: $1"; }

run_or_fail() {
    local label="$1"
    shift
    info "$label"
    if ! "$@" >> "$LOG_FILE" 2>&1; then
        fail "$label — failed. Check $LOG_FILE"
        exit 1
    fi
    success "$label"
}

header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}   ${WHITE}${BOLD}MOMOS${NC} — ${DIM}Mobile Models Ollama Setup${NC}        ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

get_arch() {
    uname -m
}

is_number() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

# Render a megabyte count as GB with the exact MB alongside, since vendors
# round capacity and the raw number is what actually matters for model fit.
fmt_size() {
    awk -v mb="$1" 'BEGIN { printf "%.1fGB (%dMB)", mb / 1024, mb }'
}

get_ram_mb() {
    local mem
    mem=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print int($2/1024)}' || true)
    echo "${mem:-0}"
}

# `df -m` is a GNU coreutils flag. Termux only has GNU df when something
# pulled in coreutils; otherwise /system/bin/df (toybox) handles it and
# rejects -m. So try the portable flag sets in turn and take the first that
# yields a number. All three report 1K blocks.
get_free_storage_mb() {
    local kb

    kb=$(df -Pk "$HOME" 2>/dev/null | awk 'END { print $4 }')
    if ! is_number "$kb"; then
        kb=$(df -k "$HOME" 2>/dev/null | awk 'END { print $4 }')
    fi
    if ! is_number "$kb"; then
        kb=$(df "$HOME" 2>/dev/null | awk 'END { print $4 }')
    fi

    if ! is_number "$kb"; then
        log_storage_diagnostics
        echo 0
        return
    fi

    echo $((kb / 1024))
}

# Record what df actually did, so an undetectable device is diagnosable
# instead of just reporting a bare warning.
log_storage_diagnostics() {
    {
        echo "--- storage detection failed at $(date '+%F %T') ---"
        echo "\$ command -v df: $(command -v df 2>&1)"
        echo "\$ df -Pk \$HOME:"; df -Pk "$HOME" 2>&1
        echo "\$ df -k \$HOME:";  df -k "$HOME" 2>&1
        echo "\$ df \$HOME:";     df "$HOME" 2>&1
        echo "\$ df -h \$HOME:";  df -h "$HOME" 2>&1
    } >> "$LOG_FILE" 2>&1
}

check_internet() {
    if ping -c 1 -W 3 google.com > /dev/null 2>&1; then
        return 0
    elif ping -c 1 -W 3 1.1.1.1 > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Ollama is served from the official Termux repository, but only the 64-bit
# architectures are built: TERMUX_PKG_EXCLUDED_ARCHES="arm, i686".
#
# 32-bit ARM needs care here. A 64-bit phone running a 32-bit Termux reports
# `armv8l`, which contains "armv8" and looks 64-bit at a glance — but the
# Termux userland is 32-bit, so the aarch64 package will not install. Only
# the literal aarch64/x86_64 values are accepted.
check_arch() {
    ARCH=$(get_arch)

    case "$ARCH" in
        aarch64|x86_64)
            success "Architecture: ${ARCH} (64-bit)"
            return 0
            ;;
        armv8l)
            fail "This Termux is 32-bit (reports 'armv8l'), even though the device is 64-bit."
            echo ""
            echo -e "${DIM}Ollama's native Termux package is built for 64-bit only, so it${NC}"
            echo -e "${DIM}cannot be installed here. The legacy PRoot installer works.${NC}"
            echo ""
            echo -e "  ${CYAN}bash -c \"\$(curl -fsSL ${LEGACY_INSTALL_URL})\"${NC}"
            echo ""
            exit 1
            ;;
        armv7l|arm|i686|i386)
            fail "Unsupported architecture: ${ARCH} (32-bit)."
            echo ""
            echo -e "${DIM}Ollama's native Termux package requires a 64-bit device.${NC}"
            echo -e "${DIM}The legacy PRoot installer runs on 32-bit devices.${NC}"
            echo ""
            echo -e "  ${CYAN}bash -c \"\$(curl -fsSL ${LEGACY_INSTALL_URL})\"${NC}"
            echo ""
            exit 1
            ;;
        *)
            fail "Unrecognised architecture: ${ARCH}"
            echo ""
            echo -e "${DIM}Please open an issue with your device details:${NC}"
            echo -e "  ${CYAN}https://github.com/Sidharth-e/MOMOS/issues${NC}"
            echo ""
            exit 1
            ;;
    esac
}

preflight() {
    echo -e "${PURPLE}Pre-flight checks${NC}"
    echo -e "${DIM}────────────────────────────────────${NC}"

    if [ ! -d "/data/data/com.termux" ]; then
        fail "Not running inside Termux. This script is for Termux on Android."
        exit 1
    fi
    success "Termux environment"

    if ! check_internet; then
        fail "No internet connection. Connect to Wi-Fi or mobile data and retry."
        exit 1
    fi
    success "Internet connectivity"

    check_arch

    RAM_MB=$(get_ram_mb)
    if [ "$RAM_MB" -gt 0 ]; then
        success "RAM: $(fmt_size "$RAM_MB")"
    else
        warn "Could not detect RAM — model recommendations may be inaccurate"
        RAM_MB=3000
    fi

    STORAGE_MB=$(get_free_storage_mb)
    if [ "$STORAGE_MB" -gt 0 ]; then
        success "Free storage: $(fmt_size "$STORAGE_MB")"
    else
        warn "Could not detect free storage — continuing (details in $LOG_FILE)"
        STORAGE_MB=99999
    fi

    echo ""
}

select_model() {
    local recommended=""
    if [ "$RAM_MB" -ge 7000 ]; then
        recommended="5"
    elif [ "$RAM_MB" -ge 3500 ]; then
        recommended="3"
    else
        recommended="1"
    fi

    declare -a NAMES TAGS SIZES RAM_REQS
    NAMES=("Llama 3.2 1B" "DeepSeek R1 1.5B" "Llama 3.2 3B" "Qwen 2.5 3B" "DeepSeek R1 7B" "Qwen 2.5 7B" "Custom model")
    TAGS=("llama3.2:1b" "deepseek-r1:1.5b" "llama3.2:3b" "qwen2.5:3b" "deepseek-r1:7b" "qwen2.5:7b" "")
    SIZES=("~1.3GB" "~1.1GB" "~2.0GB" "~1.9GB" "~4.7GB" "~4.7GB" "")
    RAM_REQS=("2GB+" "2GB+" "4GB+" "4GB+" "6GB+" "6GB+" "")

    echo -e "${WHITE}${BOLD}Select a model:${NC}"
    echo ""

    local i
    for i in "${!NAMES[@]}"; do
        local marker=""
        if [ "$((i+1))" = "$recommended" ]; then
            marker=" ${GREEN}← recommended for your device${NC}"
        fi

        if [ -n "${SIZES[$i]}" ]; then
            printf "  ${CYAN}[%d]${NC} %-22s ${DIM}%s  (%s RAM)${NC}%b\n" \
                "$((i+1))" "${NAMES[$i]}" "${SIZES[$i]}" "${RAM_REQS[$i]}" "$marker"
        else
            printf "  ${CYAN}[%d]${NC} %s\n" "$((i+1))" "${NAMES[$i]}"
        fi
    done

    echo ""
    read -rp "$(echo -e "${YELLOW}Enter choice [1-${#NAMES[@]}] (default=$recommended): ${NC}")" choice < /dev/tty
    choice="${choice:-$recommended}"

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#NAMES[@]}" ]; then
        warn "Invalid choice — using default"
        choice="$recommended"
    fi

    local idx=$((choice - 1))

    if [ -z "${TAGS[$idx]}" ]; then
        read -rp "$(echo -e "${YELLOW}Enter model tag (e.g. qwen2.5:3b): ${NC}")" custom_tag < /dev/tty
        if [ -z "$custom_tag" ]; then
            fail "No model name entered."
            exit 1
        fi
        SELECTED_MODEL="$custom_tag"
    else
        SELECTED_MODEL="${TAGS[$idx]}"
    fi

    local needed_mb=0
    case "$SELECTED_MODEL" in
        *1b*|*1.5b*) needed_mb=1600 ;;
        *3b*)        needed_mb=2500 ;;
        *7b*)        needed_mb=5500 ;;
    esac

    if [ "$needed_mb" -gt 0 ] && [ "$STORAGE_MB" -lt "$needed_mb" ]; then
        fail "Not enough storage. ${SELECTED_MODEL} needs ~$(fmt_size "$needed_mb") but only $(fmt_size "$STORAGE_MB") free."
        exit 1
    fi

    echo "$SELECTED_MODEL" > "$STATE_FILE"
    echo ""
    success "Selected: ${SELECTED_MODEL}"
    echo ""
}

install_ollama() {
    run_or_fail "Updating Termux package lists" pkg update -y

    if command -v ollama > /dev/null 2>&1; then
        success "Ollama already installed — skipping"
    else
        run_or_fail "Installing Ollama (official Termux package)" pkg install -y ollama
    fi

    if ! command -v ollama > /dev/null 2>&1; then
        fail "Ollama installed but not found on PATH. Check $LOG_FILE"
        exit 1
    fi

    if ! command -v curl > /dev/null 2>&1; then
        run_or_fail "Installing curl" pkg install -y curl
    fi
}

server_up() {
    curl -fsS "$OLLAMA_URL/api/tags" > /dev/null 2>&1
}

# Poll the API instead of guessing with a fixed sleep, so a slow phone does
# not produce a false "server failed" and a fast one does not stall.
wait_for_server() {
    local tries="${1:-90}" i=0
    while [ "$i" -lt "$tries" ]; do
        if server_up; then
            return 0
        fi
        sleep 1
        i=$((i+1))
    done
    return 1
}

start_server() {
    if server_up; then
        success "Ollama server already running"
        return 0
    fi

    info "Starting Ollama server"
    # Pinned, like launch_ollama in the launcher and for the same reason: a bare
    # `ollama serve` inherits OLLAMA_HOST and OLLAMA_ORIGINS from the profile of
    # whoever ran the installer, which would expose the API to the Wi-Fi during
    # an install that never asked for it — and `ensure_server` would later find
    # it already up and never rebind it. `env -u` drops the variable rather than
    # emptying it, which Ollama does not treat as the same thing.
    env -u OLLAMA_ORIGINS OLLAMA_HOST="127.0.0.1:11434" \
        nohup ollama serve >> "$LOG_DIR/server.log" 2>&1 &

    if wait_for_server 90; then
        success "Ollama server ready"
    else
        fail "Ollama server did not start in time. Check $LOG_DIR/server.log"
        exit 1
    fi
}

pull_model() {
    local model="$1"
    echo ""
    echo -e "${WHITE}${BOLD}Downloading ${model}${NC}"
    echo -e "${DIM}This is the longest step — progress shown below.${NC}"
    echo ""
    if ! ollama pull "$model"; then
        fail "Failed to download ${model}. Check $LOG_FILE"
        exit 1
    fi
    echo ""
    success "Model ready: ${model}"
}

install_launcher() {
    # Record the ref so `momos update` keeps following it.
    echo "$MOMOS_BRANCH" > "$LOG_DIR/branch"

    cat > "$LAUNCHER_PATH" << 'LAUNCHER_HEADER'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

LOG_DIR="$HOME/.momos"
STATE_FILE="$LOG_DIR/state"
SERVER_LOG="$LOG_DIR/server.log"
UI_DIR="$LOG_DIR/ui"
UI_LOG="$LOG_DIR/ui.log"
# Holds "<pid> <port>" for the background static server, so `momos ui stop` can
# both end it and say which port it ended.
UI_PID_FILE="$LOG_DIR/ui.pid"
# Keep in step with the `momos-ui:` marker in scripts/ui/index.html. The
# launcher compares the two and re-fetches the page on a mismatch, so an
# existing install picks up a new page without a full reinstall. The number is
# duplicated in the page on purpose: this heredoc is quoted, so interpolating it
# here would expand every $VAR in the launcher at install time.
UI_VERSION="4"
OLLAMA_URL="http://127.0.0.1:11434"

MODEL=""
if [ -f "$STATE_FILE" ]; then
    MODEL=$(cat "$STATE_FILE")
fi

server_up() {
    curl -fsS "$OLLAMA_URL/api/tags" > /dev/null 2>&1
}

wait_for_server() {
    local tries="${1:-90}" i=0
    while [ "$i" -lt "$tries" ]; do
        if server_up; then
            return 0
        fi
        sleep 1
        i=$((i+1))
    done
    return 1
}

# The one place that says what to do when the server never comes up. Four call
# sites spelled this block out; the message and the exit were the same at each,
# and it is the message a user is most likely to have to act on.
wait_for_ollama() {
    if wait_for_server 90; then
        return 0
    fi
    echo "Ollama did not start. Check $SERVER_LOG"
    exit 1
}

# Every bind choice goes through here, so the pinning rule lives in one place:
# OLLAMA_HOST is set on this command only, never inherited. Anyone with it
# exported in their shell profile would otherwise expose the server without
# asking for it — `momos serve --lan` is meant to be the only way to do that.
#
# OLLAMA_ORIGINS is left unset rather than emptied when there is no origin to
# pin: an empty value is not the same thing to Ollama as an absent one.
launch_ollama() {
    local host="$1" origins="${2:-}"

    if [ -n "$origins" ]; then
        OLLAMA_HOST="$host" OLLAMA_ORIGINS="$origins" \
            nohup ollama serve >> "$SERVER_LOG" 2>&1 &
    else
        OLLAMA_HOST="$host" nohup ollama serve >> "$SERVER_LOG" 2>&1 &
    fi
}

ensure_server() {
    if server_up; then
        return 0
    fi
    echo "Starting Ollama server..."
    launch_ollama "127.0.0.1:11434"
    wait_for_ollama
}

is_number() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

# Below 1024 is privileged, and Termux runs as an ordinary app.
valid_port() {
    local port="${1:-}"
    is_number "$port" || return 1
    [ "$port" -ge 1024 ] && [ "$port" -le 65535 ]
}

# Four numeric octets, each 0-255.
is_ipv4() {
    local ip="${1:-}" octet
    local -a octets

    [ -n "$ip" ] || return 1

    # read -a with a local IFS makes the split explicit; bare $ip would rely on
    # word splitting.
    IFS=. read -ra octets <<< "$ip"
    [ "${#octets[@]}" -eq 4 ] || return 1

    for octet in "${octets[@]}"; do
        case "$octet" in
            ''|*[!0-9]*) return 1 ;;
        esac
        [ "$octet" -le 255 ] || return 1
    done

    return 0
}

# The address a laptop has to dial to reach this phone. Which tool can answer
# varies — net-tools and iproute2 are both optional in Termux, and Android
# keeps its own `ip` in /system/bin — so ask each in turn. Returning nothing is
# deliberate: a guessed address would send the user to a dead URL with no clue
# why, which is worse than being told it could not be determined.
lan_ip() {
    local bin out addr

    for bin in ip /system/bin/ip; do
        command -v "$bin" > /dev/null 2>&1 || continue

        out=$("$bin" -4 route get 1.1.1.1 2>/dev/null || true)
        addr=$(sed -n 's/.* src \([0-9.]*\).*/\1/p' <<< "$out" | head -n1 || true)
        if is_ipv4 "$addr"; then
            echo "$addr"
            return 0
        fi

        out=$("$bin" -4 addr show 2>/dev/null || true)
        addr=$(sed -n 's/.*inet \([0-9.]*\)\/.*/\1/p' <<< "$out" \
            | grep -v '^127\.' | head -n1 || true)
        if is_ipv4 "$addr"; then
            echo "$addr"
            return 0
        fi
    done

    # toybox spells it `inet addr:`, net-tools and BSD spell it `inet `. The
    # optional group is \{0,1\} rather than \?: \? is a GNU extension that BSD
    # sed silently ignores, leaving the whole substitution unmatched.
    out=$(ifconfig 2>/dev/null || true)
    addr=$(sed -n 's/.*inet \(addr:\)\{0,1\}\([0-9.]*\).*/\2/p' <<< "$out" \
        | grep -v '^127\.' | head -n1 || true)
    if is_ipv4 "$addr"; then
        echo "$addr"
        return 0
    fi

    return 1
}

# Answers only when ollama is listening on the phone's Wi-Fi address, which can
# only happen if it bound 0.0.0.0 rather than 127.0.0.1: connecting to the
# phone's own LAN address still goes over the loopback interface, and a socket
# bound to 127.0.0.1 refuses that address even from the phone itself. This is how
# `momos serve --lan` tells "already exposed" from "already running but private"
# instead of reporting success and leaving the laptop unable to connect.
#
# The timeout matters: a wedged server would otherwise hang the command with no
# output at all, which looks exactly like a slow start.
lan_reachable() {
    local ip="${1:-}"
    [ -n "$ip" ] || return 1
    curl -fsS --max-time 2 "http://${ip}:11434/api/tags" > /dev/null 2>&1
}

# Termux ships no web server. darkhttpd is about 1MB and serves static files,
# which is all this page needs; python would be roughly 40MB competing with the
# models for space on the same device. Prefer whatever is already installed.
httpd_kind() {
    if command -v darkhttpd > /dev/null 2>&1; then
        echo darkhttpd
    elif command -v python3 > /dev/null 2>&1; then
        echo python3
    else
        echo ""
    fi
}

# Prints the name of a usable static file server on stdout, and nothing else:
# the caller reads it with `kind=$(install_httpd)`, so a progress line printed
# to stdout would be captured into the value and stop it matching any case.
# Everything the user reads goes to stderr.
install_httpd() {
    local kind
    kind=$(httpd_kind)
    if [ -n "$kind" ]; then
        echo "$kind"
        return 0
    fi

    echo "Installing darkhttpd (static file server, ~1MB)..." >&2
    if pkg install -y darkhttpd >> "$LOG_DIR/install.log" 2>&1 \
        && command -v darkhttpd > /dev/null 2>&1; then
        echo darkhttpd
        return 0
    fi

    echo "darkhttpd is not available — falling back to python (~40MB)." >&2
    if pkg install -y python >> "$LOG_DIR/install.log" 2>&1 \
        && command -v python3 > /dev/null 2>&1; then
        echo python3
        return 0
    fi

    return 1
}

# The ref every fetch below follows: the one recorded at install time, unless
# MOMOS_BRANCH overrides it for a one-off. Held to what a git ref can contain
# for the reason given at the top of the installer — it reaches a URL path, and
# the value being read back here came from a file that outlives the run which
# wrote it, so a bad one would be followed by every later update.
resolve_branch() {
    local branch
    branch=$(cat "$LOG_DIR/branch" 2>/dev/null || echo main)
    branch="${MOMOS_BRANCH:-$branch}"

    case "$branch" in
        ''|*[!A-Za-z0-9._/-]*|*..*)
            echo "Ignoring unusable branch name '$branch' — using main." >&2
            branch="main"
            ;;
    esac

    echo "$branch"
}

# The page lives on the device so the UI works with no network; a missing or
# outdated one is re-fetched from the same ref the rest of the CLI follows.
#
# A refresh that fails leaves the page already on the phone in place. That is
# the point of the design: an old page still serves, and the next run or
# `momos update` retries. Removing it because the phone happens to be offline
# would break the one thing this function exists to guarantee.
ensure_ui_files() {
    mkdir -p "$UI_DIR"

    local branch url
    branch=$(resolve_branch)
    url="https://raw.githubusercontent.com/Sidharth-e/MOMOS/${branch}/scripts/ui/index.html"

    # The marker is the page's own version stamp. Matching the exact version (not
    # just any marker) is what makes this a fast path, and the trailing `-->`
    # keeps `momos-ui:2` from matching a page stamped `momos-ui:20`.
    if [ -f "$UI_DIR/index.html" ] \
        && grep -q "<!-- momos-ui:${UI_VERSION} -->" "$UI_DIR/index.html" 2>/dev/null; then
        return 0
    fi

    if [ -f "$UI_DIR/index.html" ]; then
        echo "Updating the UI page..."
    else
        echo "Fetching the UI page..."
    fi

    # Download beside the old file and move it in only once it is really our
    # page: curl -o truncates its target before it can fail, so writing straight
    # to index.html would destroy a working page on a dropped connection.
    #
    # The stamp is matched whole rather than as the bare substring "momos-ui:",
    # which any response — a captive portal echoing the request back, say —
    # could contain. Any *version* will do, though: requiring this exact one
    # would refetch forever while the page on a branch runs ahead of a launcher
    # that is due an update.
    if curl -fsSL "$url" -o "$UI_DIR/index.html.new" \
        && grep -q '<!-- momos-ui:[0-9][0-9]* -->' "$UI_DIR/index.html.new" 2>/dev/null; then
        mv "$UI_DIR/index.html.new" "$UI_DIR/index.html"
        return 0
    fi

    rm -f "$UI_DIR/index.html.new"

    if [ -f "$UI_DIR/index.html" ]; then
        echo "Could not update the UI page — serving the one already on the phone."
        echo "  $url"
        return 0
    fi

    echo "Could not download the UI page:"
    echo "  $url"
    exit 1
}

# The page's model picker offers what the phone has installed, but it has to
# start somewhere: this is the model a new chat opens with, and the only one on
# offer if the page cannot reach Ollama to ask. The file sits beside index.html
# because darkhttpd serves that directory, and is rewritten on every `momos ui`
# so it cannot drift from the CLI's own state.
#
# Nothing the page does writes back here. It is served by a static file server,
# so a choice made in the browser stays in the browser — which is also why saved
# chats are per-browser rather than per-phone.
#
# That state is normally one line written by `momos chat`, but a hand-edited file
# could hold anything. Taking the first line and dropping quotes and backslashes
# keeps a stray character from producing invalid JSON, which the page would read
# as "no model" with nothing on screen to explain why.
write_runtime_json() {
    local model="${1:-}"
    model=$(printf '%s\n' "$model" | head -n1 | tr -d '"\\')
    printf '{"model":"%s","ollama_port":11434}\n' "$model" > "$UI_DIR/runtime.json"
}

# Backgrounded like the model server, so the terminal comes straight back. The
# PID is recorded with the port so `momos ui stop` can report what it ended.
launch_ui() {
    local kind="$1" port="$2"

    case "$kind" in
        darkhttpd)
            nohup darkhttpd "$UI_DIR" --port "$port" --addr 0.0.0.0 \
                >> "$UI_LOG" 2>&1 &
            ;;
        python3)
            nohup python3 -m http.server "$port" --bind 0.0.0.0 \
                --directory "$UI_DIR" >> "$UI_LOG" 2>&1 &
            ;;
        *)
            echo "No static file server available."
            return 1
            ;;
    esac

    echo "$! $port" > "$UI_PID_FILE"
}

# Answers only once the page is actually being served, which is the difference
# between "darkhttpd was launched" and "you can open it".
ui_up() {
    local port="${1:-}"
    [ -n "$port" ] || return 1
    curl -fsS --max-time 2 "http://127.0.0.1:${port}/" > /dev/null 2>&1
}

wait_for_ui() {
    local port="$1" tries="${2:-30}" i=0
    while [ "$i" -lt "$tries" ]; do
        if ui_up "$port"; then
            return 0
        fi
        sleep 1
        i=$((i+1))
    done
    return 1
}

print_ui_urls() {
    local port="$1" lan="${2:-}"
    echo "  Phone:   http://localhost:${port}"
    if [ -n "$lan" ]; then
        echo "  Network: http://${lan}:${port}   <- open this on your laptop"
    else
        echo "  Network: http://<phone-ip>:${port}   (could not detect this phone's address)"
    fi
}

# The command line of a PID, for the identity check below. procfs is always
# there in Termux, so the fallback is for anywhere else this is run — and it is
# why the check can be tested off-device rather than only on a phone.
proc_cmdline() {
    local pid="$1"

    if [ -r "/proc/$pid/cmdline" ]; then
        tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true
        return
    fi

    ps -o args= -p "$pid" 2>/dev/null || true
}

# A PID file outlives the process it names, and PIDs get reused. Killing on the
# number alone would let a stale file take out whatever holds that PID now, so
# the command line is checked first.
ui_stop() {
    local pid="" port="" cmdline=""

    if [ -f "$UI_PID_FILE" ]; then
        read -r pid port < "$UI_PID_FILE" || true
    fi

    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$UI_PID_FILE"
        echo "The web UI is not running."
        return 0
    fi

    cmdline=$(proc_cmdline "$pid")
    case "$cmdline" in
        *darkhttpd*|*http.server*) ;;
        *)
            rm -f "$UI_PID_FILE"
            echo "PID $pid is not the web UI any more — leaving it alone."
            return 1
            ;;
    esac

    kill "$pid" 2>/dev/null || true
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null || true
    fi

    rm -f "$UI_PID_FILE"
    echo "Web UI stopped${port:+ (port $port)}."
}

show_help() {
    echo "╭──────────────────────────────────────────╮"
    echo "│   MOMOS — Mobile Models Ollama Setup     │"
    echo "╰──────────────────────────────────────────╯"
    echo ""
    echo "Usage: momos [command] [options]"
    echo ""
    echo "Commands:"
    echo "  chat [model]          Start chatting (default: last used model)"
    echo "  ui [port]             Serve the web UI in the background (default port 8080)"
    echo "  ui stop               Stop the background web UI"
    echo "  serve [--lan]         Start the Ollama server in the background"
    echo "  stop                  Stop the background Ollama server"
    echo "  models list           Show all installed models"
    echo "  models pull <name>    Download a new model"
    echo "  models delete <name>  Remove an installed model"
    echo "  logs                  Follow the server and web UI output"
    echo "  update                Update MOMOS and Ollama"
    echo "  uninstall             Uninstall MOMOS and remove models"
    echo "  help                  Show this help"
    echo ""
    echo "Examples:"
    echo "  momos chat                       Chat with last used model"
    echo "  momos chat deepseek-r1:1.5b      Chat with a specific model"
    echo "  momos ui                         Serve the web UI on port 8080"
    echo "  momos ui 9000                    Serve it on port 9000 instead"
    echo "  momos ui stop                    Stop the background web UI"
    echo "  momos serve --lan                Expose Ollama to other devices"
    echo "  momos stop                       Stop the background Ollama server"
    echo "  momos logs                       Follow the server and web UI output"
    echo "  momos models list                See what's installed"
    echo "  momos models pull qwen2.5:3b     Download Qwen 2.5 3B"
    echo "  momos models delete llama3.2:3b  Remove a model"
    echo "  momos update                     Update MOMOS"
    echo "  momos uninstall                  Uninstall MOMOS"
    echo ""
    echo "No arguments = interactive menu"
    echo ""
    if [ -n "$MODEL" ]; then
        echo "Last used model: $MODEL"
    fi
}

cmd_chat() {
    local target="${1:-$MODEL}"
    if [ -z "$target" ]; then
        echo "No model specified."
        echo ""
        echo "Usage: momos chat [model]"
        echo "Example: momos chat deepseek-r1:1.5b"
        exit 1
    fi
    echo "$target" > "$STATE_FILE"
    ensure_server
    ollama run "$target"
}

cmd_ui() {
    if [ "${1:-}" = "stop" ]; then
        ui_stop
        return
    fi

    local port="${1:-8080}"

    if ! valid_port "$port"; then
        echo "Invalid port: ${1:-}"
        echo ""
        echo "Usage: momos ui [port]"
        echo "  port must be 1024-65535 (default 8080)"
        echo "  momos ui stop   stop the background web UI"
        exit 1
    fi

    # One server at a time: the PID file tracks one, so a second launch would
    # only fail on the port it is already bound to.
    local running="" running_port=""
    if [ -f "$UI_PID_FILE" ]; then
        read -r running running_port < "$UI_PID_FILE" || true
        if [ -n "$running" ] && kill -0 "$running" 2>/dev/null \
            && ui_up "$running_port"; then
            echo "The web UI is already running on port ${running_port}."
            echo ""
            print_ui_urls "$running_port" "$(lan_ip || true)"
            echo ""
            echo "  Stop it with: momos ui stop"
            return 0
        fi
        rm -f "$UI_PID_FILE"
    fi

    ensure_ui_files

    # The page reads the last-used model from here. Written before the server
    # starts, so the file is in place whichever static server ends up running.
    write_runtime_json "$MODEL"

    local kind
    if ! kind=$(install_httpd); then
        echo "Could not find or install a static file server."
        exit 1
    fi

    local lan
    lan=$(lan_ip || true)

    launch_ui "$kind" "$port"

    if ! wait_for_ui "$port"; then
        rm -f "$UI_PID_FILE"
        echo "The web UI did not start. Check $UI_LOG"
        exit 1
    fi

    echo "MOMOS UI — running in the background"
    echo ""
    print_ui_urls "$port" "$lan"
    echo ""
    echo "  Anyone on your Wi-Fi can reach this page — it has no login."
    echo "  All output: $UI_LOG   (momos logs)"
    echo "  Stop it with: momos ui stop"
    echo ""

    # Skip the browser when there is no browser to open: termux-open-url is
    # only present with termux-tools, and tests set MOMOS_UI_NO_OPEN.
    if [ -z "${MOMOS_UI_NO_OPEN:-}" ] && command -v termux-open-url > /dev/null 2>&1; then
        termux-open-url "http://localhost:${port}" > /dev/null 2>&1 || true
    fi
}

# Printed once the server is confirmed up. The server outlives this command, so
# the block has to carry the two things the terminal used to imply by staying
# open: how to stop it, and where its output went.
#
# Bare echo: the launcher has no colour helpers, those belong to the installer,
# which is long gone by the time this runs.
print_lan_urls() {
    local ip="$1"
    echo "  Ollama:            http://${ip}:11434"
    echo "  OpenAI-compatible: http://${ip}:11434/v1"
    echo "                     (any non-empty key; the server ignores it)"
    echo "  Chat page:         run 'momos ui' in this session, then open"
    echo "                     the URL it prints (port 8080 by default)"
    echo ""
    echo "  No login: anyone on your Wi-Fi can reach these, and the API is not"
    echo "  read-only — they can list, pull and delete your models."
    echo "  Generating is CPU-heavy; the phone will slow down."
    echo ""
    echo "  All output: $SERVER_LOG   (momos logs)"
    echo "  Stop it with: momos stop"
    echo ""
}

# The private counterpart to print_lan_urls, for the bind nobody else can reach.
print_local_urls() {
    echo "  Ollama:            http://localhost:11434"
    echo "  OpenAI-compatible: http://localhost:11434/v1"
    echo "                     (any non-empty key; the server ignores it)"
    echo ""
    echo "  Reachable from this phone only. For your Wi-Fi: momos serve --lan"
    echo ""
    echo "  All output: $SERVER_LOG   (momos logs)"
    echo "  Stop it with: momos stop"
    echo ""
}

cmd_serve() {
    local lan_mode=0 ip

    # A typo like `-lan` silently ignored would leave a loopback server running
    # while the user believes they are exposed, which is the exact failure this
    # flag exists to remove. Reject anything unrecognised instead.
    if [ "$#" -gt 1 ]; then
        echo "Too many arguments."
        echo ""
        echo "Usage: momos serve [--lan]"
        exit 1
    fi

    case "${1:-}" in
        --lan) lan_mode=1 ;;
        "")    ;;
        *)
            echo "Unknown option: $1"
            echo ""
            echo "Usage: momos serve [--lan]"
            echo "  --lan  also expose Ollama to other devices on your Wi-Fi"
            exit 1
            ;;
    esac

    if server_up; then
        if [ "$lan_mode" -eq 0 ]; then
            echo "Ollama is already running."
            echo "Use 'momos logs' to follow its output, or stop it with 'momos stop'."
            exit 0
        fi

        ip=$(lan_ip || true)
        if [ -z "$ip" ]; then
            echo "Ollama is already running, but this phone's address could not be"
            echo "detected, so there is no way to confirm it is exposed. To be sure:"
            echo ""
            echo "  momos stop && momos serve --lan"
            exit 1
        fi

        if lan_reachable "$ip"; then
            echo "Ollama is already running and already reachable on your Wi-Fi."
            echo ""
            print_lan_urls "$ip"
            exit 0
        fi

        # What this branch exists for: `momos chat` or `momos models` started the
        # server on loopback earlier in some other session, so the old "already
        # running" answer was true and useless — the laptop cannot reach it and
        # nothing on screen said so.
        echo "Ollama is already running, but only on this phone (127.0.0.1), so a"
        echo "laptop cannot reach it. The bind only changes on a restart:"
        echo ""
        echo "  momos stop"
        echo "  momos serve --lan"
        exit 1
    fi

    if [ "$lan_mode" -eq 0 ]; then
        echo "Starting Ollama server in the background..."
        launch_ollama "127.0.0.1:11434"
        wait_for_ollama
        echo "Ollama is running."
        echo ""
        print_local_urls
        return
    fi

    ip=$(lan_ip || true)
    if [ -z "$ip" ]; then
        # Bind anyway: a native client sends no Origin header, so only browsers
        # are blocked. Say which, rather than failing the whole command.
        echo "Could not detect this phone's address, so browser access will be"
        echo "blocked by Ollama's CORS check. Other clients — curl, the OpenAI"
        echo "SDKs — send no Origin and are unaffected."
        echo ""
        echo "To allow browsers anyway, set the origin by hand — the loopback"
        echo "entries included, or the page on the phone itself will be refused:"
        echo ""
        echo "  OLLAMA_HOST=0.0.0.0 \\"
        echo "    OLLAMA_ORIGINS='http://<phone-ip>:*,http://localhost:*,http://127.0.0.1:*' \\"
        echo "    ollama serve"
        echo ""
        launch_ollama "0.0.0.0:11434"
        wait_for_ollama
        echo "Ollama is running, exposed but with browser access blocked."
        echo ""
        echo "  All output: $SERVER_LOG   (momos logs)"
        echo "  Stop it with: momos stop"
        echo ""
        return
    fi

    echo "Starting Ollama server, exposed to your Wi-Fi..."
    # The exact-IP form, never a subnet wildcard. Origins containing `*` match as
    # prefix+suffix, so `http://192.168.1.*` would also accept a hostile origin
    # such as http://192.168.1.5.evil.com, while `http://<ip>:*` pins the host
    # exactly and leaves the port free — which is what the page needs, since
    # `momos ui` can be given any port.
    #
    # The loopback origins are named back explicitly because setting
    # OLLAMA_ORIGINS replaces Ollama's built-in list rather than adding to it.
    # Without them the page opened on the phone itself — which dials 127.0.0.1
    # and sends `Origin: http://localhost:<port>` — is refused by the very
    # server it is talking to, while the laptop works and gives no clue why.
    launch_ollama "0.0.0.0:11434" \
        "http://${ip}:*,http://localhost:*,http://127.0.0.1:*"

    wait_for_ollama

    # The API answering on loopback only proves it started, not that the LAN
    # bind took effect. Without this second probe a failed bind would be
    # reported as exposure, which is the one answer this command must never
    # get wrong.
    if ! lan_reachable "$ip"; then
        echo "Ollama started but is not reachable on ${ip}."
        echo "Check $SERVER_LOG, then try: momos stop && momos serve --lan"
        exit 1
    fi

    echo "Ollama is running and exposed to your Wi-Fi."
    echo ""
    print_lan_urls "$ip"
}

cmd_stop() {
    if ! server_up; then
        echo "Ollama is not running."
        exit 0
    fi
    echo "Stopping Ollama server..."
    pkill -f "ollama serve" 2>/dev/null || true
    sleep 1
    if server_up; then
        echo "Ollama is still responding — it may be supervised by another process."
        exit 1
    fi
    echo "Ollama stopped."
}

cmd_models() {
    local action="${1:-}"

    case "$action" in
        list|ls|"")
            ensure_server
            ollama list
            ;;
        pull|add)
            local name="${2:-}"
            if [ -z "$name" ]; then
                echo "Usage: momos models pull <model>"
                echo "Example: momos models pull qwen2.5:3b"
                echo ""
                echo "Browse models at: https://ollama.com/library"
                exit 1
            fi
            ensure_server
            ollama pull "$name"
            ;;
        delete|rm|remove)
            local name="${2:-}"
            if [ -z "$name" ]; then
                echo "Usage: momos models delete <model>"
                echo "Example: momos models delete llama3.2:3b"
                exit 1
            fi
            ensure_server
            ollama rm "$name"
            ;;
        *)
            echo "Unknown models command: $action"
            echo ""
            echo "Usage:"
            echo "  momos models list           Show installed models"
            echo "  momos models pull <name>    Download a model"
            echo "  momos models delete <name>  Remove a model"
            exit 1
            ;;
    esac
}

# One place to watch both background servers. `tail -f` with several files
# prints a `==> file <==` header whenever the output switches, so a line from
# the web server is never mistaken for one from Ollama. The file that does not
# exist yet is simply left out rather than passed to tail, which would error on
# it; whichever server is started later creates its log for the next run.
cmd_logs() {
    local f
    set --
    for f in "$SERVER_LOG" "$UI_LOG"; do
        if [ -f "$f" ]; then
            set -- "$@" "$f"
        fi
    done

    if [ "$#" -eq 0 ]; then
        echo "No logs yet in $LOG_DIR"
        echo ""
        echo "Start a server first:"
        echo "  momos serve"
        echo "  momos ui"
        exit 1
    fi

    echo "Following server output (Ctrl+C to stop)..."
    echo ""
    tail -f "$@"
}

cmd_update() {
    local branch url
    # Follow whichever ref this install came from, so testing a branch does not
    # silently drop the user back onto main.
    branch=$(resolve_branch)
    url="https://raw.githubusercontent.com/Sidharth-e/MOMOS/${branch}/scripts/momos.sh"
    echo "Updating MOMOS (ref: ${branch})..."
    pkg upgrade -y ollama >> "$LOG_DIR/install.log" 2>&1 || true
    # Pass the ref down. The installer resolves MOMOS_BRANCH for itself and
    # records it, so without this it would default to main and overwrite the
    # branch file — dropping the install back onto main after one update.
    MOMOS_BRANCH="$branch" bash -c "$(curl -fsSL "$url")" bash --update
}

cmd_uninstall() {
    read -rp "Are you sure you want to uninstall MOMOS? This removes Ollama and the launcher [y/N]: " confirm
    case "$confirm" in
        [yY]|[yY][eE][sS])
            echo "Stopping Ollama server..."
            pkill -f "ollama serve" 2>/dev/null || true

            # Before its directory goes: a backgrounded darkhttpd would other-
            # wise keep serving a page that no longer exists, with nothing left
            # on the phone that knows how to stop it.
            ui_stop > /dev/null 2>&1 || true

            echo "Removing Ollama..."
            pkg uninstall -y ollama 2>/dev/null || true

            if [ -d "$HOME/.ollama" ]; then
                read -rp "Also delete downloaded models in ~/.ollama? [y/N]: " del_models
                case "$del_models" in
                    [yY]|[yY][eE][sS])
                        echo "Deleting models..."
                        rm -rf "$HOME/.ollama"
                        ;;
                    *)
                        echo "Keeping models in ~/.ollama"
                        ;;
                esac
            fi

            echo "Removing MOMOS configuration..."
            rm -rf "$LOG_DIR"
            echo "Removing launcher..."
            rm -f "$PREFIX/bin/momos"
            echo "MOMOS has been uninstalled."
            exit 0
            ;;
        *)
            echo "Uninstall cancelled."
            exit 0
            ;;
    esac
}

cmd_menu() {
    echo "╭──────────────────────────╮"
    echo "│   MOMOS — Quick Menu     │"
    echo "╰──────────────────────────╯"
    echo ""
    echo "  [1] Chat with AI"
    echo "  [2] Open the web UI"
    echo "  [3] List models"
    echo "  [4] Pull a new model"
    echo "  [5] Delete a model"
    echo "  [6] View server logs"
    echo "  [7] Update MOMOS"
    echo "  [8] Uninstall MOMOS"
    echo "  [9] Help"
    echo "  [10] Exit"
    echo ""
    read -rp "Choice [1-10]: " pick
    case "$pick" in
        1) cmd_chat "$@" ;;
        2) cmd_ui ;;
        3) cmd_models list ;;
        4)
            read -rp "Model to pull (e.g. qwen2.5:3b): " pull_name
            if [ -n "$pull_name" ]; then
                cmd_models pull "$pull_name"
            fi
            ;;
        5)
            read -rp "Model to delete: " del_name
            if [ -n "$del_name" ]; then
                cmd_models delete "$del_name"
            fi
            ;;
        6) cmd_logs ;;
        7) cmd_update ;;
        8) cmd_uninstall ;;
        9) show_help ;;
        *) exit 0 ;;
    esac
}

case "${1:-}" in
    chat)      shift; cmd_chat "$@" ;;
    ui)        shift; cmd_ui "$@" ;;
    serve)     shift; cmd_serve "$@" ;;
    stop)      cmd_stop ;;
    models)    shift; cmd_models "$@" ;;
    logs)      cmd_logs ;;
    update)    cmd_update ;;
    uninstall) cmd_uninstall ;;
    help|--help|-h) show_help ;;
    *)         cmd_menu "$@" ;;
esac
LAUNCHER_HEADER

    chmod +x "$LAUNCHER_PATH"
    success "Installed 'momos' command"

    # Called from here rather than main() so that `momos update` refreshes the
    # page as well — both paths go through this function.
    install_ui
}

# The page ships in the repo and is fetched to the device so `momos ui` works
# with no network. A failure here is not fatal: the launcher re-fetches it the
# first time the UI is actually started.
install_ui() {
    local url="$MOMOS_RAW/scripts/ui/index.html"
    mkdir -p "$UI_DIR"

    # The same download-beside-then-move dance as ensure_ui_files, for the same
    # reason: curl -o truncates its target before it can fail, so an update on a
    # phone with no network would otherwise delete a page that still works. The
    # stamp is matched whole here too, for the reason given there.
    if curl -fsSL "$url" -o "$UI_DIR/index.html.new" \
        && grep -q '<!-- momos-ui:[0-9][0-9]* -->' "$UI_DIR/index.html.new" 2>/dev/null; then
        mv "$UI_DIR/index.html.new" "$UI_DIR/index.html"
        success "Installed web UI page"
    else
        rm -f "$UI_DIR/index.html.new"
        warn "Could not download the web UI page — 'momos ui' will retry when you run it"
    fi
}

finish() {
    local model="$1"
    echo ""
    echo -e "${GREEN}${BOLD}🎉 All done!${NC}"
    echo ""
    echo -e "  ${WHITE}Start chatting now:${NC}"
    echo -e "    ${CYAN}momos${NC}                    ${DIM}interactive menu${NC}"
    echo -e "    ${CYAN}momos chat${NC}                ${DIM}jump straight into ${model}${NC}"
    echo ""
    echo -e "  ${WHITE}Manage models:${NC}"
    echo -e "    ${CYAN}momos models list${NC}          ${DIM}see installed models${NC}"
    echo -e "    ${CYAN}momos models pull <name>${NC}   ${DIM}download a new model${NC}"
    echo -e "    ${CYAN}momos models delete <name>${NC} ${DIM}remove a model${NC}"
    echo ""
    echo -e "  ${WHITE}Web UI:${NC}"
    echo -e "    ${CYAN}momos ui${NC}                  ${DIM}serve the UI in the background${NC}"
    echo -e "    ${CYAN}momos ui 9000${NC}             ${DIM}serve it on another port${NC}"
    echo -e "    ${CYAN}momos ui stop${NC}             ${DIM}stop the background web UI${NC}"
    echo ""
    echo -e "  ${WHITE}Server:${NC}"
    echo -e "    ${CYAN}momos serve${NC}                ${DIM}start the server in the background${NC}"
    echo -e "    ${CYAN}momos serve --lan${NC}          ${DIM}and expose it to your Wi-Fi${NC}"
    echo -e "    ${CYAN}momos stop${NC}                 ${DIM}stop the background server${NC}"
    echo -e "    ${CYAN}momos logs${NC}                 ${DIM}follow the server and UI output${NC}"
    echo ""
    echo -e "  ${WHITE}Maintenance:${NC}"
    echo -e "    ${CYAN}momos update${NC}               ${DIM}update MOMOS and Ollama${NC}"
    echo -e "    ${CYAN}momos uninstall${NC}            ${DIM}remove MOMOS and models${NC}"
    echo ""
    echo -e "  ${DIM}Logs: $LOG_FILE${NC}"
    echo ""
}

uninstall_momos() {
    header
    echo -e "${YELLOW}Uninstalling MOMOS...${NC}"
    echo ""
    read -rp "$(echo -e "${YELLOW}Are you sure you want to uninstall MOMOS? This removes Ollama and the launcher [y/N]: ${NC}")" confirm < /dev/tty
    case "$confirm" in
        [yY]|[yY][eE][sS])
            info "Stopping Ollama server..."
            pkill -f "ollama serve" 2>/dev/null || true

            # The UI server is backgrounded, so nothing else would end it and it
            # would go on serving a page the next step deletes. Matched on the
            # directory it serves, which is what makes it ours — but spelled as
            # the tail of that path rather than the whole of it, because pkill -f
            # takes an extended regex and the dots and slashes of a full path
            # would not all be literal ones. `~/.momos/ui` contains none.
            info "Stopping web UI..."
            pkill -f 'momos/ui' 2>/dev/null || true

            info "Removing Ollama..."
            pkg uninstall -y ollama 2>/dev/null || true

            if [ -d "$HOME/.ollama" ]; then
                read -rp "$(echo -e "${YELLOW}Also delete downloaded models in ~/.ollama? [y/N]: ${NC}")" del_models < /dev/tty
                case "$del_models" in
                    [yY]|[yY][eE][sS])
                        info "Deleting models..."
                        rm -rf "$HOME/.ollama"
                        ;;
                    *)
                        info "Keeping models in ~/.ollama"
                        ;;
                esac
            fi

            info "Removing MOMOS configuration and state..."
            rm -rf "$LOG_DIR"
            info "Removing launcher..."
            rm -f "$LAUNCHER_PATH"
            success "MOMOS has been completely uninstalled."
            exit 0
            ;;
        *)
            echo "Uninstall cancelled."
            exit 0
            ;;
    esac
}

main() {
    local action="${1:-}"
    case "$action" in
        --uninstall|uninstall)
            uninstall_momos
            return
            ;;
        --update|update)
            header
            preflight
            if [ -f "$STATE_FILE" ]; then
                SELECTED_MODEL=$(cat "$STATE_FILE")
            else
                select_model
            fi
            install_ollama
            install_launcher
            finish "$SELECTED_MODEL"
            return
            ;;
    esac

    header
    preflight
    select_model
    install_ollama
    start_server
    pull_model "$SELECTED_MODEL"
    install_launcher
    finish "$SELECTED_MODEL"
}

main "$@"
