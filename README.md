# MOMOS - Modern AI for Termux 🚀

A beautiful and modern UI implementation for running multiple AI models locally on Termux (Android), including DeepSeek R1, Llama 3, Mistral, and more.

## 📋 Table of Contents

- [Features](#-features)
- [Requirements](#-requirements)
- [Installation Guide](#-installation-guide)
- [Usage Instructions](#-usage-instructions)
- [Troubleshooting](#-troubleshooting)
- [Common Issues](#-common-issues)
- [Advanced Configuration](#-advanced-configuration)
- [Performance Tips](#-performance-tips)
- [FAQ](#-faq)

## ✨ Features

- **Modern Terminal UI** with colors, emojis, and progress bars
- **Interactive Installation** with step-by-step progress
- **Beautiful Launcher** with multiple management options
- **Multi-Model Support** - Choose from various AI models
- **Model Management** - Download, remove, and manage models
- **Progress Indicators** for long-running operations
- **Error Handling** with graceful fallbacks
- **Server Management** for Ollama backend
- **System Information** display
- **Automatic Path Detection** for better compatibility

## 🎨 UI Elements

- **Color-coded status messages** (Green for success, Red for errors, etc.)
- **Unicode symbols** and emojis for visual appeal
- **Progress bars** for installation steps
- **Box-drawing characters** for headers and menus
- **Interactive menus** with numbered options
- **Clear visual hierarchy** for better readability
- **Current model display** in header
- **Enhanced error messages** with troubleshooting steps

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
   ```bash
   # Install F-Droid first, then search for "Termux"
   # Or download directly: https://f-droid.org/packages/com.termux/
   ```

2. **Download from GitHub:**
   ```bash
   # Visit: https://github.com/termux/termux-app/releases
   # Download the latest APK for your architecture
   ```

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

### Step 3: Clone/Download Scripts

```bash
# Option 1: Clone repository
git clone https://github.com/yourusername/MOMOS.git
cd MOMOS

# Option 2: Download manually
# Download the scripts folder to your device
```

### Step 4: Make Scripts Executable

```bash
# Make installation script executable
chmod +x scripts/install_deepseek.sh

# Make launcher executable
chmod +x scripts/deepseek_launcher.sh
```

### Step 5: Run Installation

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

**Expected Time:** 10-30 minutes depending on internet speed

## 🎯 Usage Instructions

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
7. **Exit** - Clean exit from the launcher

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

#### 1. "proot-distro not found" error

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

## 🔍 Advanced Configuration

### Customizing the Launcher

#### Change Default Model
```bash
# Edit the launcher script
nano scripts/deepseek_launcher.sh

# Find this line and change the model:
CURRENT_MODEL="deepseek-r1:1.5b"
```

#### Custom Color Scheme
```bash
# Edit color variables at the top of scripts
# Available colors: RED, GREEN, YELLOW, BLUE, PURPLE, CYAN, WHITE
```

#### Add Custom Models
```bash
# Edit the show_available_models function
# Add your preferred models to the list
```

### Environment Variables

```bash
# Set custom Ollama server URL
export OLLAMA_HOST=0.0.0.0:11434

# Set custom model path
export OLLAMA_MODELS=/path/to/models

# Add to ~/.bashrc for persistence
echo 'export OLLAMA_HOST=0.0.0.0:11434' >> ~/.bashrc
```

### Performance Optimization

#### For Mobile Devices
```bash
# Use smaller models (1.5B, 7B, 8B)
# Close other apps to free RAM
# Enable battery optimization for Termux
```

#### For High-End Devices
```bash
# Use larger models (14B, 32B, 70B)
# Increase swap space if needed
# Monitor temperature during long sessions
```

## 📊 Performance Tips

### Model Selection Guidelines

| Device Type | RAM | Recommended Models | Performance |
|-------------|-----|-------------------|-------------|
| **Low-end** | 2-3GB | 1.5B, 7B | Fast, basic quality |
| **Mid-range** | 4-6GB | 8B, 14B | Balanced, good quality |
| **High-end** | 8GB+ | 32B, 70B | Slow, excellent quality |

### Memory Management

```bash
# Monitor memory usage
watch -n 1 'free -h'

# Clear memory cache
echo 3 > /proc/sys/vm/drop_caches

# Restart Ollama server if memory gets high
proot-distro login debian -- bash -c "pkill ollama && ollama serve"
```

### Storage Optimization

```bash
# Regular cleanup
proot-distro login debian -- bash -c "ollama list"
proot-distro login debian -- bash -c "ollama rm unused_model"

# Compress models (if supported)
# Some models support quantization for smaller size
```

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

## 📄 License

This project is open source. Feel free to modify and distribute according to your needs.

## 🤝 Contributing

Contributions are welcome! Areas for improvement:
- Additional AI models and model families
- More UI themes and customization options
- Performance optimizations for mobile devices
- Better error handling and recovery
- Model performance benchmarking
- Additional troubleshooting guides

## 📞 Support

If you're still having issues:

1. **Check the troubleshooting section** above
2. **Run the system information** option in the launcher
3. **Check Termux logs**: `logcat | grep termux`
4. **Verify your Android version** and Termux compatibility
5. **Try a fresh Termux installation** if all else fails

---

**Enjoy your modern multi-model AI experience on Termux! 🧠✨🤖**

*If this README helped you, consider giving it a star! ⭐*


