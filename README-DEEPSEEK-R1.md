# MOMOS - DeepSeek R1 for Termux

A comprehensive guide and automated script to run DeepSeek R1 locally on Android devices using Termux.

## 🚀 Quick Start

1. **Install Termux** (see detailed steps below)
2. **Run the setup script:**
   ```bash
   chmod +x scripts/setup-deepseek-r1.sh
   ./scripts/setup-deepseek-r1.sh
   ```
3. **Start using DeepSeek R1:**
   ```bash
   ./run-deepseek.sh
   ```

## 📱 Prerequisites

- **Android device** with Android 7.0 or higher
- **Minimum 8GB RAM** (16GB+ recommended)
- **At least 12GB free storage** (more for larger models)
- **Active internet connection** for initial setup
- **Snapdragon 8 Gen 2 or equivalent** processor (for best performance)

## 🔧 Detailed Installation Steps

### Step 1: Install Termux

#### 1.1 Download Termux
- **Termux is NOT available on Google Play Store**
- Visit the [official GitHub page](https://github.com/termux/termux-app/releases)
- Download from F-Droid section (most reliable)

#### 1.2 Install APK
- Enable "Install from Unknown Sources" in Android settings
- Download and install the latest version (currently 0.119.0-beta.1)
- If you encounter issues, use the stable version 0.118.1

### Step 2: Setup Termux

#### 2.1 Grant Permissions
```bash
termux-change-repo
```
- Select "Main" repository
- Grant storage permissions if prompted

#### 2.2 Update Packages
```bash
apt update && apt upgrade -y
```

### Step 3: Install Debian Environment

#### 3.1 Install Proot-Distro
```bash
pkg install proot-distro -y
```

#### 3.2 Install Debian
```bash
proot-distro install debian
```

#### 3.3 Login to Debian
```bash
proot-distro login debian
```

### Step 4: Install TMUX and Ollama

#### 4.1 Update Debian
```bash
apt update && apt upgrade -y
```

#### 4.2 Install TMUX
```bash
apt install tmux -y
```

#### 4.3 Install Ollama
```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

### Step 5: Install DeepSeek R1

#### 5.1 Start Ollama Server
```bash
tmux ollama serve
```

#### 5.2 Install Model
In a new terminal:
```bash
ollama pull deepseek-r1:1.5b
```

### Step 6: Run DeepSeek R1

#### 6.1 Start the Model
```bash
ollama run deepseek-r1:1.5b
```

#### 6.2 Interact with AI
- Type your questions/prompts
- Press Enter to send
- Use `Ctrl+C` to stop
- Use `Ctrl+D` to exit

## 🤖 Available Models

| Model | Size | RAM Required | Recommended For |
|-------|------|--------------|-----------------|
| **deepseek-r1:1.5b** | 1.1 GB | 2-4 GB | **Most devices** ⭐ |
| deepseek-r1:7b | 4.4 GB | 4-6 GB | Mid-range devices |
| deepseek-r1:8b | 4.9 GB | 6-8 GB | High-end devices |
| deepseek-r1:14b | 9.0 GB | 8+ GB | Flagship devices |
| deepseek-r1:32b | 22 GB | 16+ GB | Desktop/Server only |
| deepseek-r1:70b | 43 GB | 32+ GB | Server only |

## 🎯 TMUX Commands

### Basic TMUX Usage
- **`Ctrl+B` then `"`** - Split horizontally
- **`Ctrl+B` then `%`** - Split vertically
- **`Ctrl+B` then arrow keys** - Navigate between panes
- **`Ctrl+B` then `d`** - Detach session
- **`tmux attach -t ollama`** - Reattach to Ollama session

### Session Management
```bash
# Start new session
tmux new-session -s deepseek

# List sessions
tmux list-sessions

# Attach to session
tmux attach -t session_name

# Kill session
tmux kill-session -t session_name
```

## 📁 File Structure

After running the setup script, you'll have:

```
~/ (home directory)
├── run-deepseek.sh          # Quick start script
└── .ollama/                 # Ollama models and data
    └── models/
        └── deepseek-r1:1.5b/
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Permission Denied
```bash
# Go to Android Settings > Apps > Termux > Permissions
# Enable Storage permission manually
```

#### 2. No Such File or Directory
```bash
# Close and reopen Termux
# Force stop and restart the app
```

#### 3. Package Not Found
```bash
# Update Termux first
apt update && apt upgrade -y
```

#### 4. Low Memory Errors
- Close other apps
- Use the 1.5B model instead of larger ones
- Restart your device

#### 5. Slow Performance
- Ensure you're using the correct model size for your device
- Close background apps
- Check if thermal throttling is active

### Performance Optimization

#### For Low-End Devices
- Use only the 1.5B model
- Close all other apps
- Keep device cool (avoid thermal throttling)
- Use airplane mode if you don't need internet

#### For Mid-Range Devices
- You can try the 7B model
- Keep 2-3GB RAM free
- Monitor device temperature

#### For High-End Devices
- 8B model should work smoothly
- Consider the 14B model if you have 16GB+ RAM
- Monitor performance and adjust accordingly

## 🔄 Alternative Installation Methods

### Method 1: Manual Step-by-Step
Follow the detailed steps above manually if you prefer to understand each step.

### Method 2: Automated Script (Recommended)
Use the provided script for a hands-off installation:
```bash
./scripts/setup-deepseek-r1.sh
```

### Method 3: Pocketpal AI App
If you prefer a GUI solution, consider using the Pocketpal AI app from app stores.

## 📊 System Requirements Summary

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **RAM** | 8 GB | 16 GB+ |
| **Storage** | 12 GB free | 20 GB+ free |
| **Processor** | Snapdragon 8 Gen 2 | Snapdragon 8 Gen 3+ |
| **Android** | 7.0+ | 10.0+ |
| **Internet** | Required for setup | Stable connection |

## 🎉 Success Indicators

You'll know the setup is successful when:

1. ✅ Termux opens without errors
2. ✅ Debian environment is accessible
3. ✅ Ollama server starts successfully
4. ✅ DeepSeek R1 model downloads completely
5. ✅ You can interact with the AI model
6. ✅ Responses are generated within reasonable time

## 🆘 Getting Help

### Before Asking for Help
1. Check the troubleshooting section above
2. Ensure you meet all system requirements
3. Verify your internet connection is stable
4. Check if you have sufficient storage space

### Common Questions

**Q: How long does the setup take?**
A: 15-30 minutes depending on your internet speed and device performance.

**Q: Can I use this offline after setup?**
A: Yes! Once the model is downloaded, you can use it completely offline.

**Q: Will this drain my battery?**
A: Yes, running AI models is CPU-intensive. Keep your device plugged in for extended use.

**Q: Can I use other AI models?**
A: Yes! Ollama supports many models. Check [ollama.ai/library](https://ollama.ai/library) for more options.

## 📝 License

This project is open source. See the LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

---

**Happy AI Chatting! 🚀**

*Built with ❤️ for the Termux community*
