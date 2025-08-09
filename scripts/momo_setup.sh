#!/data/data/com.termux/files/usr/bin/bash

# DeepSeek Installation Script for Termux (Debian via Proot-Distro + Ollama)
# Author: ChatGPT
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

# Icons
CHECK_MARK="✓"
CROSS_MARK="✗"
ARROW="→"
STAR="★"
GEAR="⚙️"
DOWNLOAD="📥"

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

clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                  ${WHITE}MOMOS Installer${NC}                         ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}    ${YELLOW}MO${NC}bile ${YELLOW}MO${NC}dels ${YELLOW}O${NC}llama ${YELLOW}S${NC}etup for Termux            ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
sleep 1

# Step 1: Check if Debian is installed
if [ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/debian" ]; then
    print_status success "Debian is already installed."
    echo -e "${YELLOW}You can run it with:${NC}"
    echo "  proot-distro login debian"
    echo "Then inside Debian:"
    echo "  ollama run <model-name>"
    exit 0
fi

# Step 2: Update Termux Packages
print_status step "Updating Termux packages..."
apt update && apt upgrade -y

# Step 3: Install PRoot-Distro
print_status step "Installing proot-distro..."
pkg install proot-distro -y

# Step 4: Install Debian 12
print_status step "Installing Debian 12..."
proot-distro install debian

# Step 5: Model selection (basic list)
echo -e "\n${YELLOW}Select a model to install:${NC}"
echo "1) deepseek-r1:1.5b"
echo "2) deepseek-r1:7b"
echo "3) deepseek-r1:14b"
echo "4) deepseek-r1:32b"
echo "5) Custom model"
read -p "Enter choice [1-5]: " choice
case $choice in
    1) MODEL_TAG="deepseek-r1:1.5b" ;;
    2) MODEL_TAG="deepseek-r1:7b" ;;
    3) MODEL_TAG="deepseek-r1:14b" ;;
    4) MODEL_TAG="deepseek-r1:32b" ;;
    5) read -p "Enter full model tag: " MODEL_TAG ;;
    *) MODEL_TAG="deepseek-r1:1.5b" ;;
esac

# Step 6: Enter Debian and install Ollama + model
print_status step "Setting up inside Debian..."
proot-distro login debian --shared-tmp -- bash -c "
    set -e
    echo '>>> Updating Debian packages...'
    apt update && apt upgrade -y
    echo '>>> Installing tmux & curl...'
    apt install tmux curl -y
    echo '>>> Installing Ollama...'
    curl -fsSL https://ollama.ai/install.sh | sh
    echo '>>> Starting Ollama server...'
    tmux new-session -d -s ollama_server 'ollama serve'
    echo '>>> Downloading model: $MODEL_TAG'
    ollama pull $MODEL_TAG
    echo 'Setup complete!'
"

print_status success "Installation Complete"
echo "To run the model:"
echo "  proot-distro login debian"
echo "  ollama run $MODEL_TAG"
