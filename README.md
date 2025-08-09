# MOMOS( Mobile Models Ollama Setup) - Modern AI for Termux 🚀

A beautiful and modern UI implementation for running AI models locally on Termux (Android) using DeepSeek R1, with a comprehensive launcher and installation system.

## 📋 Table of Contents

- [Features](#-features)
- [Requirements](#-requirements)
- [Installation Guide](#-installation-guide)
- [Usage Instructions](#-usage-instructions)
- [Troubleshooting](#-troubleshooting)
- [FAQ](#-faq)

## ✨ Features

- **Modern Terminal UI** with colors, emojis, and progress bars
- **Interactive Installation** with step-by-step progress
- **Beautiful Launcher** with multiple management options
- **DeepSeek R1 Support** - Multiple model sizes available
- **Model Management** - Download, remove, and manage models
- **Ollama Server Management** - Start/stop/check server status
- **TMUX Integration** - Keep Ollama running in background
- **System Diagnostics** - Comprehensive troubleshooting tools
- **Automatic Path Detection** for better compatibility

## 🤖 Supported Models

### DeepSeek R1 Series
- **1.5B** - Fast, lightweight (recommended for mobile)
- **8B** - Balanced performance
- **14B** - High quality, more RAM
- **32B** - Best quality, high RAM
- **70B** - Ultra quality, very high RAM

### Other Popular Models
- **Llama 3** (8B, 70B) - Meta's latest models
- **Mistral 7B** - Efficient French AI model
- **CodeLlama 7B** - Code-focused AI
- **Custom Models** - Any model from Ollama library

## 📱 Requirements

### Minimum Requirements
- **Android 7.0+** (API level 24+)
- **Termux** (latest version from F-Droid or GitHub)
- **2GB free storage** for basic models
- **3GB RAM** minimum

### Recommended Requirements
- **Android 10+** for better performance
- **4GB+ RAM** for larger models
- **5GB+ free storage** for multiple models
- **Snapdragon 8 Gen 1+** or equivalent CPU

### Storage Requirements by Model
- **1.5B models**: ~800MB
- **7B models**: ~4GB
- **8B models**: ~5GB
- **14B models**: ~8GB
- **32B models**: ~20GB
- **70B models**: ~40GB

## 🚀 Installation Guide

### Step 1: Install Termux

**⚠️ IMPORTANT: Do NOT install Termux from Google Play Store**

1. **Download from F-Droid (Recommended):**
   - Install F-Droid first, then search for "Termux"
   - Or download directly: https://f-droid.org/packages/com.termux/

2. **Download from GitHub:**
   - Visit: https://github.com/termux/termux-app/releases
   - Download the latest APK for your architecture

3. **Install the APK** and grant necessary permissions

### Step 2: Setup Termux

```bash
# Update packages
pkg update && pkg upgrade -y

# Install essential tools
pkg install git wget curl -y

# Setup storage access
termux-setup-storage
```

### Step 3: Clone Repository

```bash
# Clone the repository
git clone https://github.com/Sidharth-e/MOMOS.git
cd MOMOS

# Make scripts executable
chmod +x scripts/install_deepseek.sh
chmod +x scripts/deepseek_launcher.sh
```

### Step 4: Run Installation

```bash
# Run the installation script
bash scripts/install_deepseek.sh
```

**Installation Process:**
1. Updates Termux packages
2. Installs PRoot-Distro
3. Installs Debian 12
4. Installs Ollama
5. Downloads DeepSeek R1 1.5B model
6. Sets up TMUX session for background Ollama server

**Expected Time:** 10-30 minutes depending on internet speed

## 🎯 Usage Instructions

### Quick Ollama Server Commands

**If you're having issues with the Ollama server, use these commands:**

```bash
# Start server (recommended)
bash scripts/start_ollama.sh

# Check server status
bash scripts/start_ollama.sh status

# Attach to server session
bash scripts/start_ollama.sh attach

# Restart server
bash scripts/start_ollama.sh restart

# Stop server
bash scripts/start_ollama.sh stop
```

**Manual server management:**
```bash
# Enter Debian environment
proot-distro login debian

# Start server manually
tmux new-session -d -s ollama_server 'ollama serve'

# Check if running
tmux list-sessions
ss -tuln | grep :11434

# Attach to monitor
tmux attach-session -t ollama_server
```

### Starting the Launcher

```bash
# Run the launcher
bash scripts/deepseek_launcher.sh
```

### Launcher Menu Options

1. **Start AI Chat** - Begin chatting with your selected model
2. **Select/Download Model** - Choose from various AI models
3. **Manage Ollama Server** - Start/stop/check server status
4. **Check Model Status** - Verify model availability
5. **Manage Models** - List, remove, and get model info
6. **System Information** - View Termux and system details
7. **Run Diagnostics** - Comprehensive system troubleshooting
8. **TMUX Tips** - Learn TMUX session management
9. **Exit** - Clean exit from the launcher

### Model Selection

- **Pre-built options** for popular models
- **Custom model names** for any Ollama model
- **Size recommendations** based on device capabilities
- **Automatic download** after selection

### Model Management

- **List installed models** with sizes
- **Remove unused models** to free storage
- **Model information** and details
- **Storage optimization** tips

## 🔧 Manual Commands

If you prefer to run commands directly:

```bash
# Enter Debian environment
proot-distro login debian

# Start Ollama server
ollama serve

# In another terminal, run any model
proot-distro login debian
ollama run deepseek-r1:1.5b    # Fast model
ollama run deepseek-r1:8b      # Balanced model
ollama run llama3:8b           # Llama 3 model
ollama run mistral:7b          # Mistral model
```

## 🛠️ Troubleshooting

### Common Installation Issues

#### 1. "Permission denied" errors
```bash
# Solution: Make scripts executable
chmod +x scripts/*.sh

# Check permissions
ls -la scripts/
```

#### 2. "Package not found" errors
```bash
# Solution: Update Termux packages
pkg update && pkg upgrade -y

# Refresh package lists
pkg update
```

#### 3. "Storage access denied"
```bash
# Solution: Setup storage permissions
termux-setup-storage

# Grant permissions in Android Settings > Apps > Termux > Permissions
```

#### 4. "Out of storage space"
```bash
# Check available space
df -h

# Clear Termux cache
pkg clean

# Remove unused packages
pkg autoremove
```

### Launcher Issues

#### 1. "Ollama server not working through scripts" error

**This is a common issue where the Ollama server only works manually but not through automation scripts.**

**Symptoms:**
- Server starts manually but fails when run through scripts
- TMUX sessions not created properly
- Scripts hang or fail silently

**Root Causes:**
- TMUX session creation timing issues
- Insufficient wait time for Ollama to start
- PTY (pseudo-terminal) allocation problems
- Script execution environment differences

**Solutions:**

**A. Use the dedicated startup script:**
```bash
# Run the dedicated startup script
bash scripts/start_ollama.sh

# Check status
bash scripts/start_ollama.sh status

# Attach to session
bash scripts/start_ollama.sh attach
```

**B. Manual TMUX session creation:**
```bash
# Enter Debian environment
proot-distro login debian

# Clean up existing sessions
tmux kill-session -t ollama_server 2>/dev/null || true
sleep 3

# Create new session with proper timing
tmux new-session -d -s ollama_server 'ollama serve'
sleep 5

# Verify session and server
tmux has-session -t ollama_server
ss -tuln | grep :11434
```

**C. Check TMUX and Ollama installation:**
```bash
# Enter Debian environment
proot-distro login debian

# Reinstall TMUX
apt update && apt install tmux -y

# Reinstall Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Test TMUX functionality
tmux new-session -d -s test 'echo test'
tmux has-session -t test
tmux kill-session -t test
```

#### 2. "proot-distro not found" error

**This is the most common issue!** Here are multiple solutions:

**Solution A: Check if proot-distro is installed**
```bash
# Check if proot-distro exists
which proot-distro

# If not found, install it
pkg install proot-distro -y
```

**Solution B: Check PATH variable**
```bash
# View current PATH
echo $PATH

# Check if proot-distro is in common locations
ls -la /data/data/com.termux/files/usr/bin/proot-distro
ls -la $HOME/.local/bin/proot-distro
```

**Solution C: Reinstall proot-distro**
```bash
# Remove and reinstall
pkg remove proot-distro -y
pkg install proot-distro -y

# Verify installation
proot-distro --help
```

**Solution D: Manual path addition**
```bash
# Add to PATH temporarily
export PATH=$PATH:/data/data/com.termux/files/usr/bin

# Add to PATH permanently (add to ~/.bashrc)
echo 'export PATH=$PATH:/data/data/com.termux/files/usr/bin' >> ~/.bashrc
source ~/.bashrc
```

#### 2. "Debian not found" error

```bash
# Check available distributions
proot-distro list

# Install Debian if not present
proot-distro install debian

# Verify installation
proot-distro list | grep debian
```

#### 3. "Ollama not found" error

```bash
# Enter Debian environment
proot-distro login debian

# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Verify installation
ollama --version
```

### Performance Issues

#### 1. Slow model loading
```bash
# Check available RAM
free -h

# Use smaller models for mobile devices
# Recommended: 1.5B, 7B, or 8B models
```

#### 2. High memory usage
```bash
# Monitor memory usage
htop

# Kill unnecessary processes
pkill -f ollama
```

#### 3. Storage space issues
```bash
# Check storage usage
df -h

# Remove unused models
proot-distro login debian -- bash -c "ollama list"
proot-distro login debian -- bash -c "ollama rm model_name"
```

## 🔄 TMUX Session Management

The installation script and launcher automatically start Ollama in a TMUX session named `ollama_server` to keep it running in the background.

### Check if Ollama is Running

```bash
# Enter Debian environment
proot-distro login debian

# Check if TMUX session exists
tmux list-sessions

# Attach to the ollama_server session
tmux attach-session -t ollama_server
```

**To detach and leave Ollama running:** Press `CTRL+B` then `D`

### Start Ollama Server Manually

If the server isn't running, you can start it manually:

```bash
# Enter Debian environment
proot-distro login debian

# Create new TMUX session with Ollama server
tmux new-session -d -s ollama_server 'ollama serve'

# Verify it's running
tmux list-sessions

# Attach to monitor
tmux attach-session -t ollama_server
```

### Fix Ollama Server Script Issues

**If the Ollama server only works manually but not through scripts, try these solutions:**

#### Solution 1: Use the Dedicated Startup Script
```bash
# Make the script executable (if on Linux/Mac)
chmod +x scripts/start_ollama.sh

# Start the server
bash scripts/start_ollama.sh

# Check status
bash scripts/start_ollama.sh status

# Attach to session
bash scripts/start_ollama.sh attach
```

#### Solution 2: Manual TMUX Session Creation
```bash
# Enter Debian environment
proot-distro login debian

# Kill any existing sessions
tmux kill-session -t ollama_server 2>/dev/null || true

# Wait for cleanup
sleep 2

# Create new session with proper error handling
tmux new-session -d -s ollama_server 'ollama serve'

# Verify session was created
tmux has-session -t ollama_server

# Check if Ollama is listening
ss -tuln | grep :11434
```

#### Solution 3: Check TMUX and Ollama Installation
```bash
# Enter Debian environment
proot-distro login debian

# Ensure TMUX is installed
apt update && apt install tmux -y

# Ensure Ollama is properly installed
curl -fsSL https://ollama.ai/install.sh | sh

# Restart the server
tmux kill-session -t ollama_server 2>/dev/null || true
sleep 2
tmux new-session -d -s ollama_server 'ollama serve'
```

### TMUX Session Management

```bash
# List all sessions
tmux list-sessions

# Attach to specific session
tmux attach-session -t ollama_server

# Kill a session
tmux kill-session -t ollama_server

# Create new session
tmux new-session -d -s session_name 'command'
```

### Why Use TMUX?

- **Background Operation**: Ollama keeps running even when you close Termux
- **Easy Monitoring**: Attach/detach to check server status
- **Persistent Sessions**: Server survives terminal restarts
- **Resource Management**: Better control over background processes

## ❓ FAQ

### Q: Why is the launcher showing "proot-distro not found"?
**A:** This is usually a PATH issue. Try:
1. `pkg install proot-distro -y`
2. Check if it's in your PATH: `echo $PATH`
3. Restart Termux completely

### Q: How much storage do I need?
**A:** Minimum 2GB for basic models, 5GB+ recommended for multiple models.

### Q: Can I run multiple models at once?
**A:** Yes, but each model uses significant RAM. Use smaller models for mobile devices.

### Q: Why is the model loading slowly?
**A:** Larger models require more RAM and processing power. Use 1.5B or 7B models for faster loading.

### Q: How do I update models?
**A:** Use the launcher's "Select/Download Model" option or manually run `ollama pull model_name`.

### Q: Can I use this without internet?
**A:** After initial installation and model download, you can use models offline.

### Q: Why is Termux crashing?
**A:** Usually due to insufficient RAM. Use smaller models and close other apps.

### Q: How do I backup my models?
**A:** Models are stored in the Debian environment. You can copy the Ollama directory or use the launcher's model management.

## 🔄 Updates

### Updating Termux
```bash
pkg update && pkg upgrade -y
```

### Updating Debian
```bash
proot-distro login debian -- bash -c "apt update && apt upgrade -y"
```

### Updating Ollama
```bash
proot-distro login debian -- bash -c "curl -fsSL https://ollama.ai/install.sh | sh"
```

### Updating Models
```bash
# Use the launcher's model selection
# Or manually:
proot-distro login debian -- bash -c "ollama pull model_name"
```

## 📞 Support

If you're still having issues:

1. **Check the troubleshooting section** above
2. **Run the system information** option in the launcher
3. **Use the diagnostics tool** (Option 7) for comprehensive troubleshooting
4. **Check Termux logs**: `logcat | grep termux`
5. **Verify your Android version** and Termux compatibility
6. **Try a fresh Termux installation** if all else fails

---

**Enjoy your modern AI experience on Termux! 🧠✨🤖**

*If this README helped you, consider giving it a star! ⭐*


