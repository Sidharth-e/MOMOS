#!/data/data/com.termux/files/usr/bin/bash

# DeepSeek R1 Installation Script for Termux (Debian via Proot-Distro + Ollama)
# Tested for DeepSeek R1 1.5B model on Android with Termux
# Author: ChatGPT

set -e

echo "=== DeepSeek R1 Local Installation Script ==="
echo "This will install Debian via Proot-Distro, Ollama, and DeepSeek R1."
sleep 2

# Step 1: Update Termux Packages
echo ">>> Updating Termux packages..."
apt update && apt upgrade -y

# Step 2: Install PRoot-Distro
echo ">>> Installing proot-distro..."
pkg install proot-distro -y

# Step 3: Install Debian 12
echo ">>> Installing Debian 12..."
proot-distro install debian

# Step 4: Enter Debian and install dependencies
echo ">>> Setting up inside Debian..."
proot-distro login debian --shared-tmp -- bash -c "
    set -e
    echo '>>> Updating Debian packages...'
    apt update && apt upgrade -y

    echo '>>> Installing tmux & curl...'
    apt install tmux curl -y

    echo '>>> Installing Ollama...'
    curl -fsSL https://ollama.ai/install.sh | sh

    echo '>>> Starting Ollama server in background tmux session...'
    tmux new-session -d -s ollama_server 'ollama serve'

    echo '>>> Downloading DeepSeek R1 1.5B model...'
    ollama pull deepseek-r1:1.5b

    echo 'Setup complete inside Debian!'
"

echo "=== Installation Complete ==="
echo "To run DeepSeek R1, use:"
echo "  proot-distro login debian"
echo "  ollama run deepseek-r1:1.5b"
