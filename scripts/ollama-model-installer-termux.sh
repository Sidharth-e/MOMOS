#!/data/data/com.termux/files/usr/bin/bash

# DeepSeek R1 Installation Script for Termux (Debian via Proot-Distro + Ollama)
# Modern UI with colors, progress bars, and interactive elements
# Tested for DeepSeek R1 1.5B model on Android with Termux

set -e

# Color definitions for modern UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Unicode characters for modern UI
CHECK_MARK="✓"
CROSS_MARK="✗"
ARROW="→"
STAR="★"
ROCKET="🚀"
GEAR="⚙️"
DOWNLOAD="📥"
SUCCESS="🎉"
WAITING="⏳"

# Function to print colored text
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

# Function to show progress bar
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

# Function to print header
print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${WHITE}DeepSeek R1 Installer${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}              ${YELLOW}Modern AI for Termux${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to print step header
print_step_header() {
    local step_num=$1
    local step_title=$2
    echo -e "${PURPLE}╭─ Step ${step_num}: ${step_title}${NC}"
}

# Function to print step footer
print_step_footer() {
    echo -e "${PURPLE}╰─ Step Complete${NC}"
    echo ""
}

# Function to start Ollama server inside Debian
start_ollama_server() {
    print_step_header "S" "Starting Ollama Server"

    proot-distro login debian --shared-tmp -- bash -c "
        if tmux has-session -t ollama_server 2>/dev/null; then
            echo '${YELLOW}${STAR}${NC} Ollama server already running in TMUX session.'
        else
            echo '${GREEN}${CHECK_MARK}${NC} Starting Ollama server...'
            tmux new-session -d -s ollama_server 'ollama serve'
            echo '${GREEN}${CHECK_MARK}${NC} Ollama server started.'
        fi
    "

    print_status "success" "Ollama server is ready!"
    print_step_footer
}

# Main installation function
main_installation() {
    print_header
    
    print_status "info" "Welcome to the DeepSeek R1 Installation Script!"
    print_status "info" "This will install Debian via Proot-Distro, Ollama, and DeepSeek R1."
    echo ""
    
    read -p "$(echo -e "${YELLOW}Do you want to continue? (y/N): ${NC}")" -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "info" "Installation cancelled. Goodbye!"
        exit 0
    fi
    
    echo ""
    
    # Step 1: Update Termux Packages
    print_step_header "1" "Updating Termux Packages"
    print_status "step" "Updating package lists and upgrading existing packages..."
    apt update > /dev/null 2>&1
    show_progress 1 3
    apt upgrade -y > /dev/null 2>&1
    show_progress 2 3
    print_status "success" "Termux packages updated successfully!"
    show_progress 3 3
    print_step_footer
    
    # Step 2: Install PRoot-Distro
    print_step_header "2" "Installing PRoot-Distro"
    print_status "step" "Installing proot-distro for Linux distribution support..."
    pkg install proot-distro -y > /dev/null 2>&1
    print_status "success" "PRoot-Distro installed successfully!"
    print_step_footer
    
    # Step 3: Install Debian 12
    print_step_header "3" "Installing Debian 12"
    print_status "step" "Installing Debian 12 via proot-distro..."
    print_status "warning" "This step may take several minutes depending on your internet connection."
    
    print_status "download" "Downloading Debian 12..."
    proot-distro install debian > /dev/null 2>&1 &
    local debian_pid=$!
    
    local dots=""
    while kill -0 $debian_pid 2>/dev/null; do
        dots="${dots}."
        printf "\r${CYAN}Installing Debian${dots}${NC}"
        sleep 2
    done
    echo ""
    print_status "success" "Debian 12 installed successfully!"
    print_step_footer
    
    # Step 4: Setup inside Debian
    print_step_header "4" "Configuring Debian Environment"
    print_status "step" "Setting up Debian and installing dependencies..."

    echo -e "${YELLOW}Select the Ollama model to install:${NC}"
    echo "1) deepseek-r1:1.5b   (Smaller, faster)"
    echo "2) deepseek-r1:7b     (Balanced)"
    echo "3) deepseek-r1:32b    (Larger, more accurate)"
    echo "4) llama3:8b          (Alternative)"
    echo "5) gemma:7b           (Alternative)"
    echo ""
    read -p "$(echo -e "${CYAN}Enter choice [1-5]: ${NC}")" model_choice

    case $model_choice in
        1) MODEL_NAME="deepseek-r1:1.5b" ;;
        2) MODEL_NAME="deepseek-r1:7b" ;;
        3) MODEL_NAME="deepseek-r1:32b" ;;
        4) MODEL_NAME="llama3:8b" ;;
        5) MODEL_NAME="gemma:7b" ;;
        *) print_status "warning" "Invalid choice, defaulting to deepseek-r1:1.5b"
           MODEL_NAME="deepseek-r1:1.5b" ;;
    esac
    
    proot-distro login debian --shared-tmp -- bash -c "
        set -e
        apt update > /dev/null 2>&1 && apt upgrade -y > /dev/null 2>&1
        apt install tmux curl -y > /dev/null 2>&1
        curl -fsSL https://ollama.ai/install.sh | sh > /dev/null 2>&1
        tmux new-session -d -s ollama_server 'ollama serve' > /dev/null 2>&1
        ollama pull ${MODEL_NAME} > /dev/null 2>&1
    "
    
    print_status "success" "Debian environment configured successfully!"
    print_step_footer
    
    echo -e "${GREEN}${SUCCESS} Installation Complete! ${SUCCESS}${NC}"
    echo ""
    echo -e "${WHITE}To run your chosen model, use these commands:${NC}"
    echo -e "${CYAN}  proot-distro login debian${NC}"
    echo -e "${CYAN}  ollama run ${MODEL_NAME}${NC}"
    echo ""
    echo -e "${YELLOW}${STAR} Pro tip: Use 'tmux attach -t ollama_server' to manage the Ollama server${NC}"
    echo ""
    echo -e "${GREEN}${ROCKET} Enjoy your local AI assistant!${NC}"

    read -p "$(echo -e "${YELLOW}Do you want to start the Ollama server now? (y/N): ${NC}")" -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        start_ollama_server
        echo -e "${GREEN}${ROCKET} You can attach to the server with:${NC} tmux attach -t ollama_server"
    fi
}

# Error handling
trap 'echo -e "\n${RED}${CROSS_MARK} Installation failed!${NC}"; exit 1' ERR

if [ ! -d "/data/data/com.termux" ]; then
    echo -e "${RED}${CROSS_MARK} This script is designed for Termux on Android.${NC}"
    echo -e "${RED}Please run this script in Termux.${NC}"
    exit 1
fi

# Mode handling: install or just start server
if [[ "$1" == "start-server" ]]; then
    start_ollama_server
    exit 0
fi

main_installation
