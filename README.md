# MOMOS (Mobile Models Ollama Setup) - Modern AI for Termux 🚀

A comprehensive and beautiful installer for running AI models locally on Termux (Android) using Debian, Ollama, and various AI models with an interactive setup process.

## 📋 Table of Contents

- [Features](#-features)
- [Requirements](#-requirements)
- [Installation Guide](#-installation-guide)
- [Usage Instructions](#-usage-instructions)
- [Troubleshooting](#-troubleshooting)
- [FAQ](#-faq)

## ✨ Features

- **Modern Terminal UI** with colors, emojis, and progress bars
- **Interactive Installation** with step-by-step progress tracking
- **Automatic Setup** of Debian 12 via PRoot-Distro
- **Ollama Integration** with automatic installation and configuration
- **Model Selection Menu** with popular AI models
- **TMUX Integration** for background Ollama server management
- **Beautiful Progress Indicators** with visual feedback
- **Error Handling** with comprehensive error trapping
- **Cross-Platform Compatibility** for Termux on Android

## 🤖 Supported Models

The installer provides a selection menu with these options:

### Pre-configured Models
- **DeepSeek R1 1.5B** - Fast, lightweight (recommended for mobile)
- **DeepSeek L 7B** - Balanced performance and quality
- **Gemma 7B** - Google's efficient model
- **Custom Models** - Any model from the Ollama library

### Model Recommendations by Device Capability
- **Low-end devices (2-3GB RAM)**: 1.5B models
- **Mid-range devices (4-6GB RAM)**: 7B models  
- **High-end devices (8GB+ RAM)**: Larger models

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

# Make the setup script executable
chmod +x scripts/setup.sh
```

### Step 4: Run the Installer

```bash
# Run the comprehensive setup script
bash scripts/setup.sh
```

**What the Installer Does:**

1. **Updates Termux** packages to latest versions
2. **Installs PRoot-Distro** for Linux distribution support
3. **Installs Debian 12** with progress tracking
4. **Presents Model Selection** menu with options
5. **Configures Debian** environment
6. **Installs Ollama** automatically
7. **Downloads Selected Model** based on your choice
8. **Sets up TMUX Session** for background Ollama server
9. **Provides Usage Instructions** for next steps

**Expected Time:** 15-45 minutes depending on internet speed and model size

## 🎯 Usage Instructions

### After Installation

Once the installer completes, you can use your AI models:

```bash
# Enter the Debian environment
proot-distro login debian

# Start chatting with your selected model
ollama run deepseek-r1:1.5b    # or whatever model you chose
```

### TMUX Session Management

The installer automatically creates a TMUX session for the Ollama server:

```bash
# Enter Debian environment
proot-distro login debian

# Check if TMUX session exists
tmux list-sessions

# Attach to the ollama_server session
tmux attach-session -t ollama_server

# To detach (leave server running): Press CTRL+B then D
```

### Managing Your Models

```bash
# Enter Debian environment
proot-distro login debian

# List installed models
ollama list

# Download additional models
ollama pull llama3:8b
ollama pull mistral:7b

# Remove models to free space
ollama rm model_name

# Get model information
ollama show model_name
```

## 🔧 Manual Commands

If you prefer to run commands directly:

```bash
# Enter Debian environment
proot-distro login debian

# Start Ollama server manually
ollama serve

# In another terminal, run any model
proot-distro login debian
ollama run deepseek-r1:1.5b    # Fast model
ollama run deepseek-l:7b        # Balanced model
ollama run gemma:7b             # Gemma model
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

### Installation-Specific Issues

#### 1. "proot-distro not found" error
```bash
# Check if proot-distro is installed
which proot-distro

# If not found, install it
pkg install proot-distro -y

# Verify installation
proot-distro --help
```

#### 2. "Debian installation failed" error
```bash
# Check available distributions
proot-distro list

# Try installing Debian again
proot-distro install debian

# Check for errors in the process
proot-distro install debian 2>&1 | tee debian_install.log
```

#### 3. "Ollama installation failed" error
```bash
# Enter Debian environment
proot-distro login debian

# Install Ollama manually
curl -fsSL https://ollama.ai/install.sh | sh

# Verify installation
ollama --version
```

#### 4. "Model download failed" error
```bash
# Enter Debian environment
proot-distro login debian

# Check internet connection
ping -c 3 google.com

# Try downloading the model again
ollama pull model_name

# Check available disk space
df -h
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

The installer automatically starts Ollama in a TMUX session named `ollama_server` to keep it running in the background.

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

### Q: Why is the installer showing "proot-distro not found"?
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
**A:** Use `ollama pull model_name` to download the latest version of any model.

### Q: Can I use this without internet?
**A:** After initial installation and model download, you can use models offline.

### Q: Why is Termux crashing?
**A:** Usually due to insufficient RAM. Use smaller models and close other apps.

### Q: How do I backup my models?
**A:** Models are stored in the Debian environment. You can copy the Ollama directory or use `ollama list` to see what you have installed.

### Q: The installer seems stuck, what should I do?
**A:** The Debian installation can take 10-30 minutes. If it's been more than 45 minutes, try:
1. Cancel the installation (Ctrl+C)
2. Check your internet connection
3. Restart Termux and try again
4. Ensure you have enough storage space

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
2. **Verify your Android version** and Termux compatibility
3. **Check Termux logs**: `logcat | grep termux`
4. **Ensure sufficient storage** and RAM
5. **Try a fresh Termux installation** if all else fails
6. **Check your internet connection** during installation

---

**Enjoy your modern AI experience on Termux! 🧠✨🤖**

*If this README helped you, consider giving it a star! ⭐*


