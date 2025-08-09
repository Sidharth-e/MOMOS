# MOMOS (Mobile Models Ollama Setup) - Modern AI for Termux 🚀

A comprehensive installer for running AI models locally on Termux (Android) using Debian, Ollama, and various AI models with an interactive setup process.

## 📋 Table of Contents

- [Features](#-features)
- [Requirements](#-requirements)
- [Installation Guide](#-installation-guide)
- [Usage Instructions](#-usage-instructions)
- [Troubleshooting](#-troubleshooting)

## ✨ Features

- **Modern Terminal UI** with colors, emojis, and progress indicators
- **Interactive Installation** with step-by-step progress tracking
- **Automatic Setup** of Debian 12 via PRoot-Distro
- **Ollama Integration** with automatic installation and configuration
- **Model Selection Menu** with popular AI models
- **TMUX Integration** for background Ollama server management
- **Error Handling** with comprehensive error trapping
- **Cross-Platform Compatibility** for Termux on Android

## 🤖 Supported Models

The installer provides a selection menu with these options:

### Pre-configured Models
- **DeepSeek R1 1.5B** - Fast, lightweight (recommended for mobile)
- **DeepSeek R1 7B** - Balanced performance and quality
- **DeepSeek R1 14B** - Higher quality, more resource intensive
- **DeepSeek R1 32B** - High quality, requires significant resources
- **Custom Models** - Any model from the Ollama library

### Model Recommendations by Device Capability
- **Low-end devices (2-3GB RAM)**: 1.5B models
- **Mid-range devices (4-6GB RAM)**: 7B models  
- **High-end devices (8GB+ RAM)**: 14B+ models

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

### Storage Requirements by Model
- **1.5B models**: ~800MB
- **7B models**: ~4GB
- **14B models**: ~8GB
- **32B models**: ~20GB

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

# Choose your setup script:
# For simple setup: chmod +x scripts/momo_setup.sh
# For advanced setup: chmod +x scripts/setup.sh
```

### Step 4: Run the Installer

**Option 1: Simple Setup (momo_setup.sh)**
```bash
# Run the simple setup script
bash scripts/momo_setup.sh
```

**Option 2: Advanced Setup (setup.sh)**
```bash
# Run the advanced setup script with progress bars
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
ollama run deepseek-r1:7b       # Balanced model
ollama run deepseek-r1:14b      # Higher quality model
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


