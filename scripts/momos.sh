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
LAUNCHER_PATH="$PREFIX/bin/momos"

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

get_ram_mb() {
    local mem
    mem=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print int($2/1024)}' || true)
    echo "${mem:-0}"
}

get_free_storage_mb() {
    local storage
    storage=$(df -m "$HOME" 2>/dev/null | awk 'NR==2{print $4}' || true)
    echo "${storage:-0}"
}

check_internet() {
    if ping -c 1 -W 3 google.com > /dev/null 2>&1; then
        return 0
    elif ping -c 1 -W 3 1.1.1.1 > /dev/null 2>&1; then
        return 0
    fi
    return 1
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

    RAM_MB=$(get_ram_mb)
    if [ "$RAM_MB" -gt 0 ]; then
        success "RAM: ${RAM_MB}MB"
    else
        warn "Could not detect RAM — model recommendations may be inaccurate"
        RAM_MB=3000
    fi

    STORAGE_MB=$(get_free_storage_mb)
    if [ -n "$STORAGE_MB" ] && [ "$STORAGE_MB" -gt 0 ]; then
        success "Free storage: ${STORAGE_MB}MB"
    else
        warn "Could not detect free storage"
        STORAGE_MB=99999
    fi

    echo ""
}

select_model() {
    local recommended=""
    if [ "$RAM_MB" -ge 10000 ]; then
        recommended="3"
    elif [ "$RAM_MB" -ge 4000 ]; then
        recommended="2"
    else
        recommended="1"
    fi

    declare -a NAMES TAGS SIZES RAM_REQS
    NAMES=("DeepSeek R1 1.5B" "DeepSeek R1 7B" "DeepSeek R1 14B" "DeepSeek R1 32B" "Gemma 3 4B" "Llama 3.2 3B" "Custom model")
    TAGS=("deepseek-r1:1.5b" "deepseek-r1:7b" "deepseek-r1:14b" "deepseek-r1:32b" "gemma3:4b" "llama3.2:3b" "")
    SIZES=("~800MB" "~4GB" "~8GB" "~20GB" "~2.5GB" "~2GB" "")
    RAM_REQS=("2GB+" "4GB+" "8GB+" "12GB+" "4GB+" "3GB+" "")

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
        read -rp "$(echo -e "${YELLOW}Enter model tag (e.g. mistral:7b): ${NC}")" custom_tag < /dev/tty
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
        *1.5b*) needed_mb=900 ;;
        *3b*)   needed_mb=2200 ;;
        *4b*)   needed_mb=2800 ;;
        *7b*)   needed_mb=4500 ;;
        *14b*)  needed_mb=9000 ;;
        *32b*)  needed_mb=21000 ;;
    esac

    if [ "$needed_mb" -gt 0 ] && [ "$STORAGE_MB" -lt "$needed_mb" ]; then
        fail "Not enough storage. ${SELECTED_MODEL} needs ~${needed_mb}MB but only ${STORAGE_MB}MB free."
        exit 1
    fi

    echo "$SELECTED_MODEL" > "$STATE_FILE"
    echo ""
    success "Selected: ${SELECTED_MODEL}"
    echo ""
}

install_debian() {
    if [ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/debian" ]; then
        success "Debian already installed — skipping"
        return 0
    fi

    run_or_fail "Updating Termux packages" apt update
    run_or_fail "Upgrading Termux packages" apt upgrade -y
    run_or_fail "Installing proot-distro" pkg install proot-distro -y
    run_or_fail "Installing Debian 12 (this takes a few minutes)" proot-distro install debian
}

configure_debian() {
    local model="$1"

    info "Configuring Debian + Ollama + model pull (this is the longest step)"

    proot-distro login debian --shared-tmp -- bash -c "
        set -e
        echo '>>> Updating Debian...'
        apt update && apt upgrade -y
        echo '>>> Installing dependencies...'
        apt install tmux curl -y
        echo '>>> Installing Ollama...'
        curl -fsSL https://ollama.ai/install.sh | sh
        echo '>>> Starting Ollama server...'
        tmux kill-session -t ollama_server 2>/dev/null || true
        sleep 1
        tmux new-session -d -s ollama_server 'ollama serve'
        sleep 5
        echo '>>> Pulling model: $model'
        ollama pull '$model'
        echo '>>> Done!'
    " >> "$LOG_FILE" 2>&1

    if [ $? -ne 0 ]; then
        fail "Debian setup failed. Check $LOG_FILE"
        exit 1
    fi

    success "Debian configured, Ollama installed, model pulled"
}

install_launcher() {
    local model="$1"

    cat > "$LAUNCHER_PATH" << 'LAUNCHER_HEADER'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

STATE_FILE="$HOME/.momos/state"
MODEL=""
if [ -f "$STATE_FILE" ]; then
    MODEL=$(cat "$STATE_FILE")
fi

show_help() {
    echo "╭──────────────────────────────────────────╮"
    echo "│   MOMOS — Mobile Models Ollama Setup     │"
    echo "╰──────────────────────────────────────────╯"
    echo ""
    echo "Usage: momos [command] [options]"
    echo ""
    echo "Commands:"
    echo "  chat [model]          Start chatting (default: last used model)"
    echo "  models list           Show all installed models"
    echo "  models pull <name>    Download a new model"
    echo "  models delete <name>  Remove an installed model"
    echo "  logs                  View live Ollama server logs"
    echo "  help                  Show this help"
    echo ""
    echo "Examples:"
    echo "  momos chat                       Chat with last used model"
    echo "  momos chat deepseek-r1:1.5b      Chat with a specific model"
    echo "  momos models list                See what's installed"
    echo "  momos models pull gemma3:4b      Download Gemma 3 4B"
    echo "  momos models delete llama3.2:3b  Remove a model"
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
    proot-distro login debian --shared-tmp -- bash -c "
        ollama serve > /dev/null 2>&1 &
        sleep 3
        ollama run '$target'
    "
}

cmd_models() {
    local action="${1:-}"

    case "$action" in
        list|ls|"")
            proot-distro login debian --shared-tmp -- bash -c "
                ollama serve > /dev/null 2>&1 &
                sleep 3
                ollama list
            "
            ;;
        pull|add)
            local name="${2:-}"
            if [ -z "$name" ]; then
                echo "Usage: momos models pull <model>"
                echo "Example: momos models pull gemma3:4b"
                echo ""
                echo "Browse models at: https://ollama.com/library"
                exit 1
            fi
            proot-distro login debian --shared-tmp -- bash -c "
                ollama serve > /dev/null 2>&1 &
                sleep 3
                ollama pull '$name'
            "
            ;;
        delete|rm|remove)
            local name="${2:-}"
            if [ -z "$name" ]; then
                echo "Usage: momos models delete <model>"
                echo "Example: momos models delete llama3.2:3b"
                exit 1
            fi
            proot-distro login debian --shared-tmp -- bash -c "
                ollama serve > /dev/null 2>&1 &
                sleep 3
                ollama rm '$name'
            "
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
    echo "Starting Ollama server with live logs (Ctrl+C to stop)..."
    echo ""
    proot-distro login debian --shared-tmp -- ollama serve
}

cmd_menu() {
    echo "╭──────────────────────────╮"
    echo "│   MOMOS — Quick Menu     │"
    echo "╰──────────────────────────╯"
    echo ""
    echo "  [1] Chat with AI"
    echo "  [2] List models"
    echo "  [3] Pull a new model"
    echo "  [4] Delete a model"
    echo "  [5] View server logs"
    echo "  [6] Help"
    echo "  [7] Exit"
    echo ""
    read -rp "Choice [1-7]: " pick
    case "$pick" in
        1) cmd_chat "$@" ;;
        2) cmd_models list ;;
        3)
            read -rp "Model to pull (e.g. gemma3:4b): " pull_name
            if [ -n "$pull_name" ]; then
                cmd_models pull "$pull_name"
            fi
            ;;
        4)
            read -rp "Model to delete: " del_name
            if [ -n "$del_name" ]; then
                cmd_models delete "$del_name"
            fi
            ;;
        5) cmd_logs ;;
        6) show_help ;;
        *) exit 0 ;;
    esac
}

case "${1:-}" in
    chat)   shift; cmd_chat "$@" ;;
    models) shift; cmd_models "$@" ;;
    logs)   cmd_logs ;;
    help|--help|-h) show_help ;;
    *)      cmd_menu "$@" ;;
esac
LAUNCHER_HEADER

    chmod +x "$LAUNCHER_PATH"
    success "Installed 'momos' command"
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
    echo -e "  ${WHITE}Other:${NC}"
    echo -e "    ${CYAN}momos logs${NC}                 ${DIM}view live server logs${NC}"
    echo -e "    ${CYAN}momos help${NC}                 ${DIM}show all commands${NC}"
    echo ""
    echo -e "  ${DIM}Logs: $LOG_FILE${NC}"
    echo ""
}

main() {
    header
    preflight
    select_model
    install_debian
    configure_debian "$SELECTED_MODEL"
    install_launcher "$SELECTED_MODEL"
    finish "$SELECTED_MODEL"
}

main
