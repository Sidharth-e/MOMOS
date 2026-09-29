#!/data/data/com.termux/files/usr/bin/bash

# DeepSeek R1 Installation Script for Termux (Debian via Proot-Distro + Ollama)
# With Model Selection Menu
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Unicode UI elements
CHECK_MARK="✓"
CROSS_MARK="✗"
ARROW="→"
STAR="★"
ROCKET="🚀"
GEAR="⚙️"
DOWNLOAD="📥"
SUCCESS="🎉"

# Print status messages
print_status() {
    local status=$1
    local message=$2
    case $status in
        "info") echo -e "${BLUE}${ARROW}${NC} ${message}" ;;
        "success") echo -e "${GREEN}${CHECK_MARK}${NC} ${message}" ;;
        "warning") echo -e "${YELLOW}${STAR}${NC} ${message}" ;;
        "error") echo -e "${RED}${CROSS_MARK}${NC} ${message}" ;;
        "step") echo -e "${PURPLE}${GEAR}${NC} ${message}" ;;
        "download") echo -e "${CYAN}${DOWNLOAD}${NC} ${message}" ;;
    esac
}

# Progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    printf "\r${CYAN}[${NC}"
    printf "%${completed}s" | tr ' ' '█'
    printf "%${remaining}s" | tr ' ' '░'
    printf "${CYAN}]${NC} ${WHITE}%d%%${NC}" $percentage
    
    if [ $current -eq $total ]; then
        echo ""
    fi
}

# Header
print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                  ${WHITE}MOMOS Installer${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${YELLOW}MO${NC}bile ${YELLOW}MO${NC}dels ${YELLOW}O${NC}llama ${YELLOW}S${NC}etup for Termux            ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step_header() { echo -e "${PURPLE}╭─ Step $1: $2${NC}"; }
print_step_footer() { echo -e "${PURPLE}╰─ Step Complete${NC}\n"; }

# Main install function
main_installation() {
    print_header
    print_status "info" "Welcome to the DeepSeek Installer!"
    print_status "info" "This will install Debian, Ollama, and your selected model."
    echo ""
    
    read -p "$(echo -e "${YELLOW}Do you want to continue? (y/N): ${NC}")" -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "info" "Installation cancelled."
        exit 0
    fi
    echo ""

    # Step 1: Update Termux
    print_step_header "1" "Updating Termux Packages"
    apt update > /dev/null 2>&1
    show_progress 1 2
    apt upgrade -y > /dev/null 2>&1
    show_progress 2 2
    print_status "success" "Termux updated!"
    print_step_footer

    # Step 2: Install proot-distro
    print_step_header "2" "Installing PRoot-Distro"
    pkg install proot-distro -y > /dev/null 2>&1
    print_status "success" "PRoot-Distro installed."
    print_step_footer

    # Step 3: Install Debian
    print_step_header "3" "Installing Debian 12"
    print_status "warning" "This may take a while..."
    proot-distro install debian > /dev/null 2>&1 &
    pid=$!
    dots=""
    while kill -0 $pid 2>/dev/null; do
        dots="${dots}."
        printf "\r${CYAN}Installing Debian${dots}${NC}"
        sleep 2
    done
    echo ""
    print_status "success" "Debian installed!"
    print_step_footer

    # Step 3.5: Model Selection
    print_step_header "3.5" "Select Ollama Model"
    MODELS=("deepseek-r1:1.5b" "deepseek-l:7b" "gemma:7b" "custom")
    for i in "${!MODELS[@]}"; do
        echo -e "${CYAN}[$((i+1))]${NC} ${WHITE}${MODELS[$i]}${NC}"
    done
    read -p "$(echo -e "${YELLOW}Enter choice [1-${#MODELS[@]}]: ${NC}")" choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#MODELS[@]}" ]; then
        print_status "error" "Invalid choice. Defaulting to deepseek-r1:1.5b."
        SELECTED_MODEL="deepseek-r1:1.5b"
    else
        if [ "${MODELS[$((choice-1))]}" = "custom" ]; then
            read -p "$(echo -e "${YELLOW}Enter custom model name (e.g., llama2:13b): ${NC}")" custom_model
            SELECTED_MODEL="$custom_model"
        else
            SELECTED_MODEL="${MODELS[$((choice-1))]}"
        fi
    fi
    print_status "success" "Selected model: ${SELECTED_MODEL}"
    print_step_footer

    # Step 4: Configure Debian
    print_step_header "4" "Configuring Debian"
    proot-distro login debian --shared-tmp -- bash -c "
        set -e
        apt update > /dev/null 2>&1 && apt upgrade -y > /dev/null 2>&1
        apt install tmux curl -y > /dev/null 2>&1
        curl -fsSL https://ollama.ai/install.sh | sh > /dev/null 2>&1
        tmux kill-session -t ollama_server 2>/dev/null || true
        sleep 2
        tmux new-session -d -s ollama_server 'ollama serve' || true
        sleep 5
        ollama pull ${SELECTED_MODEL} > /dev/null 2>&1
        echo 'Setup complete inside Debian.'
    "
    print_status "success" "Debian configured!"
    print_step_footer

    # Final message
    echo -e "${GREEN}${SUCCESS} Installation Complete!${NC}"
    echo -e "${WHITE}Run:${NC}"
    echo -e "${CYAN}  proot-distro login debian${NC}"
    echo -e "${CYAN}  ollama run ${SELECTED_MODEL}${NC}"
    echo -e "${YELLOW}${STAR} Tip: Use 'tmux attach -t ollama_server' to manage Ollama.${NC}"
    echo -e "${GREEN}${ROCKET} Enjoy your AI assistant!${NC}"
}

trap 'echo -e "\n${RED}${CROSS_MARK} Installation failed!${NC}"; exit 1' ERR

if [ ! -d "/data/data/com.termux" ]; then
    echo -e "${RED}${CROSS_MARK} This script is for Termux on Android.${NC}"
    exit 1
fi

main_installation
