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
MOMOS_BRANCH="${MOMOS_BRANCH:-main}"
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

ensure_server() {
    if server_up; then
        return 0
    fi
    echo "Starting Ollama server..."
    nohup ollama serve >> "$SERVER_LOG" 2>&1 &
    if ! wait_for_server 90; then
        echo "Ollama did not start. Check $SERVER_LOG"
        exit 1
    fi
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

install_httpd() {
    local kind
    kind=$(httpd_kind)
    if [ -n "$kind" ]; then
        echo "$kind"
        return 0
    fi

    echo "Installing darkhttpd (static file server, ~1MB)..."
    if pkg install -y darkhttpd >> "$LOG_DIR/install.log" 2>&1 \
        && command -v darkhttpd > /dev/null 2>&1; then
        echo darkhttpd
        return 0
    fi

    echo "darkhttpd is not available — falling back to python (~40MB)."
    if pkg install -y python >> "$LOG_DIR/install.log" 2>&1 \
        && command -v python3 > /dev/null 2>&1; then
        echo python3
        return 0
    fi

    return 1
}

# The page lives on the device so the UI works with no network; a missing file
# is re-fetched from the same ref the rest of the CLI follows.
ensure_ui_files() {
    mkdir -p "$UI_DIR"

    if [ -f "$UI_DIR/index.html" ]; then
        return 0
    fi

    local branch url
    branch=$(cat "$LOG_DIR/branch" 2>/dev/null || echo main)
    branch="${MOMOS_BRANCH:-$branch}"
    url="https://raw.githubusercontent.com/Sidharth-e/MOMOS/${branch}/scripts/ui/index.html"

    echo "Fetching the UI page..."
    if ! curl -fsSL "$url" -o "$UI_DIR/index.html"; then
        rm -f "$UI_DIR/index.html"
        echo "Could not download the UI page:"
        echo "  $url"
        exit 1
    fi
}

# Foreground, so only one extra process is ever running alongside the models.
serve_ui() {
    local kind="$1" port="$2"

    case "$kind" in
        darkhttpd)
            exec darkhttpd "$UI_DIR" --port "$port" --addr 0.0.0.0
            ;;
        python3)
            exec python3 -m http.server "$port" --bind 0.0.0.0 --directory "$UI_DIR"
            ;;
        *)
            echo "No static file server available."
            return 1
            ;;
    esac
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
    echo "  ui [port]             Serve the web UI on your network (default port 8080)"
    echo "  serve                 Run the Ollama server in the foreground"
    echo "  models list           Show all installed models"
    echo "  models pull <name>    Download a new model"
    echo "  models delete <name>  Remove an installed model"
    echo "  logs                  View live Ollama server logs"
    echo "  update                Update MOMOS and Ollama"
    echo "  uninstall             Uninstall MOMOS and remove models"
    echo "  help                  Show this help"
    echo ""
    echo "Examples:"
    echo "  momos chat                       Chat with last used model"
    echo "  momos chat deepseek-r1:1.5b      Chat with a specific model"
    echo "  momos ui                         Serve the web UI on port 8080"
    echo "  momos ui 9000                    Serve it on port 9000 instead"
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
    local port="${1:-8080}"

    if ! valid_port "$port"; then
        echo "Invalid port: ${1:-}"
        echo ""
        echo "Usage: momos ui [port]"
        echo "  port must be 1024-65535 (default 8080)"
        exit 1
    fi

    ensure_ui_files

    local kind
    if ! kind=$(install_httpd); then
        echo "Could not find or install a static file server."
        exit 1
    fi

    local lan
    lan=$(lan_ip || true)

    echo "MOMOS UI"
    echo ""
    echo "  Phone:   http://localhost:${port}"
    if [ -n "$lan" ]; then
        echo "  Network: http://${lan}:${port}   <- open this on your laptop"
    else
        echo "  Network: http://<phone-ip>:${port}   (could not detect this phone's address)"
    fi
    echo ""
    echo "  Anyone on your Wi-Fi can reach this page — it has no login."
    echo "  Ctrl+C to stop."
    echo ""

    # Skip the browser when there is no browser to open: termux-open-url is
    # only present with termux-tools, and tests set MOMOS_UI_NO_OPEN.
    if [ -z "${MOMOS_UI_NO_OPEN:-}" ] && command -v termux-open-url > /dev/null 2>&1; then
        termux-open-url "http://localhost:${port}" > /dev/null 2>&1 || true
    fi

    serve_ui "$kind" "$port"
}

cmd_serve() {
    if server_up; then
        echo "Ollama is already running."
        echo "Use 'momos logs' to follow its output, or stop it with 'momos stop'."
        exit 0
    fi
    echo "Starting Ollama server in the foreground (Ctrl+C to stop)..."
    echo ""
    ollama serve
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

cmd_logs() {
    if [ ! -f "$SERVER_LOG" ]; then
        echo "No server log yet at $SERVER_LOG"
        echo ""
        echo "Start the server first:"
        echo "  momos serve"
        exit 1
    fi
    echo "Following $SERVER_LOG (Ctrl+C to stop)..."
    echo ""
    tail -f "$SERVER_LOG"
}

cmd_update() {
    local branch url
    # Follow whichever ref this install came from, so testing a branch does not
    # silently drop the user back onto main.
    branch=$(cat "$LOG_DIR/branch" 2>/dev/null || echo main)
    branch="${MOMOS_BRANCH:-$branch}"
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
    serve)     cmd_serve ;;
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

    if curl -fsSL "$url" -o "$UI_DIR/index.html"; then
        success "Installed web UI page"
    else
        rm -f "$UI_DIR/index.html"
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
    echo -e "    ${CYAN}momos ui${NC}                  ${DIM}serve the UI to your network${NC}"
    echo -e "    ${CYAN}momos ui 9000${NC}             ${DIM}serve it on another port${NC}"
    echo ""
    echo -e "  ${WHITE}Server:${NC}"
    echo -e "    ${CYAN}momos serve${NC}                ${DIM}run the server in the foreground${NC}"
    echo -e "    ${CYAN}momos stop${NC}                 ${DIM}stop the background server${NC}"
    echo -e "    ${CYAN}momos logs${NC}                 ${DIM}view live server logs${NC}"
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
