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

# Main installation function
main_installation() {
    print_header
    
    print_status "info" "Welcome to the DeepSeek R1 Installation Script!"
    print_status "info" "This will install Debian via Proot-Distro, Ollama, and DeepSeek R1."
    echo ""
    
    # Confirmation
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
    
    # Show progress for Debian installation
    print_status "download" "Downloading Debian 12..."
    proot-distro install debian > /dev/null 2>&1 &
    local debian_pid=$!
    
    # Simple progress animation
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
    
    proot-distro login debian --shared-tmp -- bash -c "
        set -e
        echo '${GREEN}${CHECK_MARK}${NC} Updating Debian packages...'
        apt update > /dev/null 2>&1 && apt upgrade -y > /dev/null 2>&1
        
        echo '${GREEN}${CHECK_MARK}${NC} Installing tmux & curl...'
        apt install tmux curl -y > /dev/null 2>&1
        
        echo '${GREEN}${CHECK_MARK}${NC} Installing Ollama...'
        curl -fsSL https://ollama.ai/install.sh | sh > /dev/null 2>&1
        
        echo '${GREEN}${CHECK_MARK}${NC} Starting Ollama server in background...'
        # Kill any existing session first
        tmux kill-session -t ollama_server 2>/dev/null || true
        sleep 2
        # Create new session with proper error handling
        if tmux new-session -d -s ollama_server 'ollama serve'; then
            echo '${GREEN}${CHECK_MARK}${NC} TMUX session created successfully'
            # Wait for Ollama to start
            sleep 5
            # Verify session exists
            if tmux has-session -t ollama_server 2>/dev/null; then
                echo '${GREEN}${CHECK_MARK}${NC} Ollama server session verified'
            else
                echo '${YELLOW}${STAR} Warning: TMUX session may not have been created properly'
            fi
        else
            echo '${YELLOW}${STAR} Warning: Failed to create TMUX session'
        fi
        
        echo '${GREEN}${CHECK_MARK}${NC} Downloading DeepSeek R1 1.5B model...'
        ollama pull deepseek-r1:1.5b > /dev/null 2>&1
        
        echo '${GREEN}${CHECK_MARK}${NC} Setup complete inside Debian!'
    "
    
    print_status "success" "Debian environment configured successfully!"
    print_step_footer
    
    # Final success message
    echo -e "${GREEN}${SUCCESS} Installation Complete! ${SUCCESS}${NC}"
    echo ""
    echo -e "${WHITE}To run DeepSeek R1, use these commands:${NC}"
    echo -e "${CYAN}  proot-distro login debian${NC}"
    echo -e "${CYAN}  ollama run deepseek-r1:1.5b${NC}"
    echo ""
    echo -e "${YELLOW}${STAR} Pro tip: You can also use 'tmux attach -t ollama_server' to manage the Ollama server${NC}"
    echo ""
    echo -e "${GREEN}${ROCKET} Enjoy your local AI assistant!${NC}"
}

# Error handling
trap 'echo -e "\n${RED}${CROSS_MARK} Installation failed!${NC}"; exit 1' ERR

# Check if running in Termux
if [ ! -d "/data/data/com.termux" ]; then
    echo -e "${RED}${CROSS_MARK} This script is designed for Termux on Android.${NC}"
    echo -e "${RED}Please run this script in Termux.${NC}"
    exit 1
fi

# Run main installation
main_installation
