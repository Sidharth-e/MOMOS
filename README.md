# MOMOS - Modern AI for Termux 🚀

A beautiful and modern UI implementation for running multiple AI models locally on Termux (Android), including DeepSeek R1, Llama 3, Mistral, and more.

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

## 🎨 UI Elements

- **Color-coded status messages** (Green for success, Red for errors, etc.)
- **Unicode symbols** and emojis for visual appeal
- **Progress bars** for installation steps
- **Box-drawing characters** for headers and menus
- **Interactive menus** with numbered options
- **Clear visual hierarchy** for better readability
- **Current model display** in header

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

- **Termux** (Android terminal emulator)
- **Android 7.0+** (API level 24+)
- **Internet connection** for downloads
- **At least 2GB free storage** for models
- **3GB+ RAM** recommended for larger models

## 🚀 Quick Start

### 1. Install DeepSeek R1

```bash
# Make the script executable
chmod +x scripts/install_deepseek.sh

# Run the installation
bash scripts/install_deepseek.sh
```

The installation script will:
- Update Termux packages
- Install PRoot-Distro
- Install Debian 12
- Install Ollama
- Download DeepSeek R1 1.5B model

### 2. Launch the Multi-Model Launcher

```bash
# Make the launcher executable
chmod +x scripts/deepseek_launcher.sh

# Run the launcher
bash scripts/deepseek_launcher.sh
```

## 🎯 Launcher Features

The enhanced launcher provides a beautiful interface with:

1. **Start AI Chat** - Begin chatting with your selected model
2. **Select/Download Model** - Choose from various AI models
3. **Manage Ollama Server** - Start/stop/check server status
4. **Check Model Status** - Verify model availability
5. **Manage Models** - List, remove, and get model info
6. **System Information** - View Termux and system details
7. **Exit** - Clean exit from the launcher

## 🔄 Model Selection & Management

### Choosing a Model
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

## 🎨 UI Customization

The scripts use ANSI color codes and Unicode characters. You can customize:

- **Colors**: Modify the color variables at the top of each script
- **Symbols**: Change Unicode characters for different visual styles
- **Layout**: Adjust box-drawing characters for different terminal widths
- **Model defaults**: Change the default model in the launcher

## 📊 Progress Indicators

- **Step-by-step progress** with clear headers
- **Progress bars** for package updates
- **Animated dots** for long installations
- **Download progress** for model downloads
- **Status messages** for each operation

## 🛡️ Error Handling

- **Graceful fallbacks** for failed operations
- **Clear error messages** with visual indicators
- **Installation verification** before proceeding
- **Termux environment detection**
- **Model availability checks**

## 🔍 Troubleshooting

### Common Issues

1. **"Permission denied"** - Make scripts executable with `chmod +x`
2. **"Not found" errors** - Ensure you're running in Termux
3. **Installation fails** - Check internet connection and storage space
4. **Model not found** - Use the launcher to download models
5. **Out of memory** - Choose smaller models (1.5B, 7B, 8B)

### Model Selection Tips

- **Start with 1.5B/7B models** for mobile devices
- **8B models** offer good balance of quality and performance
- **14B+ models** require significant RAM and storage
- **Use model management** to remove unused models

### Debug Mode

For troubleshooting, you can modify the scripts to show verbose output by removing `> /dev/null 2>&1` from commands.

## 📱 Termux Compatibility

- **Tested on**: Android 10+ with Termux
- **Architecture**: ARM64, ARM32, x86_64
- **Storage**: Requires at least 2GB free space
- **Memory**: Minimum 3GB RAM recommended
- **Models**: All Ollama-supported models

## 🎉 Success Indicators

- ✅ Green checkmarks for completed steps
- 🎉 Celebration emojis for completion
- 🚀 Rocket emojis for successful launches
- 💬 Chat bubbles for interactive elements
- 🤖 Robot emojis for model selection

## 🔄 Updates

To update your installation:

```bash
# Update Termux packages
apt update && apt upgrade -y

# Update Debian packages
proot-distro login debian -- bash -c "apt update && apt upgrade -y"

# Update Ollama
proot-distro login debian -- bash -c "curl -fsSL https://ollama.ai/install.sh | sh"

# Update models (optional)
proot-distro login debian -- bash -c "ollama pull deepseek-r1:1.5b"
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

---

**Enjoy your modern multi-model AI experience on Termux! 🧠✨🤖**


