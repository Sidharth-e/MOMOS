# MOMOS (Mobile Open-source Model Operating Script)

A streamlined solution for running open-source AI models on Android devices using Termux, with comprehensive Termux support and lightweight alternatives.

## 🎯 What is MOMOS?

MOMOS is a collection of shell scripts designed specifically for Termux on Android to:
- Set up lightweight AI model environments (no PyTorch needed!)
- Configure models for mobile device optimization
- Run inference with minimal setup hassle
- Troubleshoot common Termux issues
- Provide fallback methods when ML libraries fail

## 🚀 Features

- **Termux-optimized**: Built specifically for Android Termux environment
- **Lightweight setup**: No heavy PyTorch dependencies
- **Smart troubleshooting**: Built-in diagnostics for Termux issues
- **Mobile-optimized**: Pre-configured for mobile device constraints
- **One-command setup**: Run a single script to get everything working
- **Fallback methods**: System works even when ML libraries fail
- **Multiple inference methods**: Tries different approaches for running models

## 📱 Supported Platform

- **Android**: Termux terminal emulator only

## 🛠️ Quick Start (5 Minutes)

### Prerequisites
- Termux app installed on your Android device
- Internet connection for setup
- At least 2GB free storage space

### Installation
```bash
# Clone or download the project
git clone https://github.com/Sidharth-e/momos.git
cd momos

# Make scripts executable
chmod +x scripts/*.sh

# Use lightweight setup (recommended for Termux)
./scripts/setup-lightweight.sh

# If you encounter issues, run troubleshooting:
./scripts/termux-troubleshoot.sh
```

### Step-by-Step Setup

#### Step 1: Clone and Setup
```bash
git clone <your-repo-url>
cd MOMOS
./scripts/setup-lightweight.sh
```

#### Step 2: Activate Environment
```bash
source venv/bin/activate
```

#### Step 3: Install a Model
```bash
./scripts/install-lightweight-model.sh tiny-llama-ggml
```

#### Step 4: Test It
```bash
./scripts/run-ggml-inference.sh "Hello, how are you?"
```

## 🔧 Setup Options

### Recommended: Lightweight Setup
```bash
# Use lightweight setup (no PyTorch needed)
./scripts/setup-lightweight.sh
```

**Why Lightweight is Best for Termux:**
- ✅ **No PyTorch needed** - avoids ARM64 compatibility issues
- ✅ **Smaller models** (0.7-1.4GB vs 2-13GB)
- ✅ **Faster inference** with lower memory usage
- ✅ **Mobile-optimized** configurations
- ✅ **Better error handling** for Termux
- ✅ **Fallback methods** when ML libraries fail

### Alternative: Full Termux Setup
```bash
# If lightweight fails, use full setup
./scripts/setup-termux.sh
```

### Troubleshooting
```bash
# Run the troubleshooting script if you have issues
./scripts/termux-troubleshoot.sh
```

## 📊 Model Recommendations for Termux

| Model | Size | Memory | Speed | Quality | Notes |
|-------|------|--------|-------|---------|-------|
| **TinyLlama** | 0.7GB | 1.0GB | ⚡⚡⚡ | ⭐⭐ | Fastest, smallest, most reliable |
| **GPT4All-J** | 1.2GB | 1.2GB | ⚡⚡ | ⭐⭐⭐ | Good balance of speed/quality |
| **Phi-2** | 1.4GB | 1.5GB | ⚡ | ⭐⭐⭐⭐ | Best overall performance |
| **Llama-2 7B** | 4.0GB | 4.5GB | 🐌 | ⭐⭐⭐⭐⭐ | Best quality, slower |

## ⚠️ What to Expect in Termux

- **Some packages will fail to install** - This is normal and expected!
- **The system will continue working** - Uses fallback methods
- **You can still manage models** - Download, organize, etc.
- **Inference may use alternatives** - Cloud APIs, external tools

## 🔍 Troubleshooting

### Common Termux Issues

#### 1. Package Installation Fails
```bash
# This is normal in Termux! Run troubleshooting:
./scripts/termux-troubleshoot.sh

# Or try manual fixes:
pip install ctransformers
pip install llama-cpp-python
pip install onnxruntime-cpu
```

#### 2. Out of Memory
- Close other apps to free up memory
- Use smaller models (TinyLlama recommended)
- Reduce context length

#### 3. Permission Denied
```bash
# Make sure scripts are executable
chmod +x scripts/*.sh
```

#### 4. Storage Issues
```bash
# Check available space
df -h

# Use external storage if available
# Models can go in /storage/emulated/0/
```

### Getting Help
```bash
# Run diagnostics
./scripts/termux-troubleshoot.sh

# Check logs
tail -f logs/momos.log

# View configuration
cat config/models-lightweight.json
```

## 🌐 Cloud Inference Alternatives

When local inference fails or is too slow:

1. **HuggingFace Inference API** (free tier)
2. **Google Colab** (free)
3. **OpenAI API** (paid)

## 📁 Project Structure

```
MOMOS/
├── venv/                    # Python environment
├── models/                  # Your models go here
├── config/                  # Configuration files
├── scripts/                 # Helper scripts
├── logs/                    # Log files
└── .env                     # Environment variables
```

## 🎯 Next Steps After Setup

1. **Explore models**: `cat config/models-lightweight.json`
2. **Install more models**: Use the install script
3. **Customize settings**: Edit `.env` file
4. **Check logs**: Look in `logs/` directory

## 💡 Pro Tips

1. **Start with TinyLlama** - Fastest, smallest, most reliable
2. **Use external storage** - Models can go in `/storage/emulated/0/`
3. **Close other apps** - Free up memory for inference
4. **Use cloud inference** - When local is too slow
5. **Keep Termux updated** - Run `pkg update` regularly

## 🚨 Common Issues & Quick Fixes

### "Package installation failed"
- This is normal in Termux
- System will use fallback methods
- You can still manage models

### "Model not found"
```bash
# Run: ./scripts/install-lightweight-model.sh <model-name>
# Check: ls models/
```

### "Inference failed"
- Try cloud inference instead
- Use external model runners
- Check model file integrity

## 🔧 Advanced Configuration

### Environment Variables
```bash
# Edit .env file to customize:
MOMOS_MODELS_DIR=./models/
MOMOS_LOG_LEVEL=INFO
MOMOS_DEFAULT_MODEL=tiny-llama-ggml
```

### Custom Model Configuration
```bash
# Edit config/models-lightweight.json to add custom models
# Follow the existing format for new entries
```

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Open-source model developers
- Termux development team
- Mobile AI community

---

## 📱 Termux-Specific Notes

**Remember**: Termux is different from regular Linux. Some things will fail, but the system is designed to handle it gracefully and provide alternatives!

### What Gets Created During Setup

The setup scripts will create:
- `requirements-lightweight.txt` - No PyTorch dependencies
- `config/models-lightweight.json` - Mobile-optimized models
- `scripts/run-ggml-inference.sh` - GGML inference script (with fallbacks)
- `scripts/install-lightweight-model.sh` - Model installation
- `scripts/termux-troubleshoot.sh` - Termux troubleshooting
- `README-LIGHTWEIGHT.md` - Detailed instructions

### Performance Tips

- Use lightweight setup for better performance
- Close other apps to free up memory
- Use external storage if available
- Keep Termux updated
- Use quantized models (int4/int8)
- Limit context to 128-256 tokens

---

**Made with ❤️ for the Termux mobile AI community**
