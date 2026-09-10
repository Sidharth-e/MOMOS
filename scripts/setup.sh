#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

LOG_DIR="$HOME/.momos"
LOG_FILE="$LOG_DIR/setup.log"

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
    echo -e "${CYAN}║${NC}   ${WHITE}${BOLD}MOMOS Setup${NC} — ${DIM}Termux Quick Start${NC}            ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${DIM}Prepares your Termux for MOMOS in one command${NC}"
    echo ""
}

check_termux() {
    if [ ! -d "/data/data/com.termux" ]; then
        fail "Not running inside Termux."
        echo ""
        echo -e "${WHITE}Install Termux from:${NC}"
        echo -e "  ${CYAN}Google Play Store${NC}"
        echo -e "  ${CYAN}F-Droid:${NC}  https://f-droid.org/packages/com.termux/"
        echo -e "  ${CYAN}GitHub:${NC}   https://github.com/termux/termux-app/releases"
        exit 1
    fi
    success "Termux environment detected"
}

check_internet() {
    if ping -c 1 -W 3 google.com > /dev/null 2>&1; then
        return 0
    elif ping -c 1 -W 3 1.1.1.1 > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

setup_storage() {
    if [ -d "$HOME/storage" ]; then
        success "Storage access already configured"
        return 0
    fi

    info "Setting up storage access..."
    echo -e "${YELLOW}  A permission dialog may appear — tap ${BOLD}Allow${NC}"
    termux-setup-storage
    sleep 2

    if [ -d "$HOME/storage" ]; then
        success "Storage access granted"
    else
        warn "Storage setup skipped or denied — you can run 'termux-setup-storage' later"
    fi
}

update_packages() {
    run_or_fail "Updating package lists" pkg update -y
    run_or_fail "Upgrading installed packages" pkg upgrade -y
}

install_essentials() {
    local packages=(curl wget git)
    local missing=()

    for pkg_name in "${packages[@]}"; do
        if command -v "$pkg_name" > /dev/null 2>&1; then
            success "$pkg_name already installed"
        else
            missing+=("$pkg_name")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        run_or_fail "Installing ${missing[*]}" pkg install -y "${missing[@]}"
    fi
}

update_momos() {
    header
    info "Updating MOMOS..."
    curl -fsSL https://raw.githubusercontent.com/Sidharth-e/MOMOS/main/scripts/momos.sh -o /tmp/momos.sh && bash /tmp/momos.sh --update
}

uninstall_momos() {
    header
    echo -e "${YELLOW}Uninstalling MOMOS...${NC}"
    echo ""
    read -rp "$(echo -e "${YELLOW}Are you sure you want to uninstall MOMOS? This will remove all downloaded models and Debian container [y/N]: ${NC}")" confirm < /dev/tty
    case "$confirm" in
        [yY]|[yY][eE][sS])
            info "Stopping Ollama server..."
            proot-distro login debian --shared-tmp -- tmux kill-session -t ollama_server 2>/dev/null || true
            pkill -f "ollama" 2>/dev/null || true
            info "Removing Debian container..."
            proot-distro remove debian 2>/dev/null || true
            info "Removing MOMOS configuration and state..."
            rm -rf "$LOG_DIR"
            info "Removing launcher..."
            rm -f "$PREFIX/bin/momos"
            success "MOMOS has been completely uninstalled."
            exit 0
            ;;
        *)
            echo "Uninstall cancelled."
            exit 0
            ;;
    esac
}

prompt_momos() {
    echo ""
    echo -e "${WHITE}${BOLD}Termux is ready!${NC}"
    echo ""
    echo -e "${DIM}────────────────────────────────────${NC}"
    if [ -f "$PREFIX/bin/momos" ]; then
        echo -e "  MOMOS is already installed."
        echo ""
        echo -e "  ${CYAN}[1]${NC} Update MOMOS"
        echo -e "  ${CYAN}[2]${NC} Reinstall / configure MOMOS"
        echo -e "  ${CYAN}[3]${NC} Uninstall MOMOS"
        echo -e "  ${CYAN}[4]${NC} Exit"
        echo ""
        read -rp "$(echo -e "${YELLOW}Choice [1-4] (default=1): ${NC}")" choice < /dev/tty
        choice="${choice:-1}"
        case "$choice" in
            1) update_momos ;;
            2)
                curl -fsSL https://raw.githubusercontent.com/Sidharth-e/MOMOS/main/scripts/momos.sh -o /tmp/momos.sh && bash /tmp/momos.sh
                ;;
            3) uninstall_momos ;;
            *) finish_standalone ;;
        esac
    else
        echo -e "  Want to install ${CYAN}MOMOS${NC} now?"
        echo -e "  ${DIM}(Run AI models locally on your phone)${NC}"
        echo ""
        echo -e "  ${CYAN}[1]${NC} Yes — install MOMOS now"
        echo -e "  ${CYAN}[2]${NC} No  — just finish setup"
        echo ""
        read -rp "$(echo -e "${YELLOW}Choice [1-2] (default=1): ${NC}")" choice < /dev/tty
        choice="${choice:-1}"

        if [ "$choice" = "1" ]; then
            echo ""
            info "Launching MOMOS installer..."
            echo ""
            curl -fsSL https://raw.githubusercontent.com/Sidharth-e/MOMOS/main/scripts/momos.sh -o /tmp/momos.sh && bash /tmp/momos.sh
        else
            finish_standalone
        fi
    fi
}

finish_standalone() {
    echo ""
    echo -e "${GREEN}${BOLD}✅ Termux setup complete!${NC}"
    echo ""
    echo -e "  ${WHITE}Installed:${NC}"
    echo -e "    ${GREEN}✓${NC} Package updates"
    echo -e "    ${GREEN}✓${NC} Storage access"
    echo -e "    ${GREEN}✓${NC} curl, wget, git"
    echo ""
    echo -e "  ${WHITE}To install MOMOS later:${NC}"
    echo -e "    ${CYAN}curl -fsSL https://raw.githubusercontent.com/Sidharth-e/MOMOS/main/scripts/momos.sh -o /tmp/momos.sh && bash /tmp/momos.sh${NC}"
    echo ""
    echo -e "  ${DIM}Logs: $LOG_FILE${NC}"
    echo ""
}

main() {
    local action="${1:-}"
    case "$action" in
        --uninstall|uninstall)
            uninstall_momos
            return
            ;;
        --update|update)
            update_momos
            return
            ;;
    esac

    header

    echo -e "${BLUE}Pre-flight checks${NC}"
    echo -e "${DIM}────────────────────────────────────${NC}"

    check_termux

    if ! check_internet; then
        fail "No internet connection. Connect to Wi-Fi or mobile data and retry."
        exit 1
    fi
    success "Internet connectivity"

    echo ""
    echo -e "${BLUE}Setting up Termux${NC}"
    echo -e "${DIM}────────────────────────────────────${NC}"

    setup_storage
    update_packages
    install_essentials

    prompt_momos
}

main "$@"
