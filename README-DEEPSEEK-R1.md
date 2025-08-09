# MOMOS - DeepSeek R1 for Termux

A streamlined solution for running DeepSeek R1 AI model on Android devices using Termux, optimized for mobile performance.

## 🎯 What is MOMOS?

MOMOS is a collection of shell scripts designed specifically for Termux on Android to:
- Set up DeepSeek R1 model environment (no PyTorch needed!)
- Configure the model for mobile device optimization
- Run inference with minimal setup hassle
- Provide a focused, single-model solution

## 🚀 Features

- **DeepSeek R1 Focused**: Optimized specifically for DeepSeek R1 model
- **Termux-optimized**: Built specifically for Android Termux environment
- **Lightweight setup**: No heavy PyTorch dependencies
- **Mobile-optimized**: Pre-configured for mobile device constraints
- **One-command setup**: Run a single script to get everything working
- **GGML optimized**: Uses GGML format for best mobile performance

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

# Use DeepSeek R1 setup (recommended for Termux)
./scripts/setup-deepseek-r1.sh

# If you encounter issues, run troubleshooting:
./scripts/termux-troubleshoot.sh
```

### Step-by-Step Setup

#### Step 1: Clone and Setup
```bash
git clone <your-repo-url>
cd MOMOS
./scripts/setup-deepseek-r1.sh
```

#### Step 2: Activate Environment
```bash
source venv/bin/activate
```

#### Step 3: Install DeepSeek R1 Model
```bash
./scripts/install-lightweight-model.sh deepseek-r1-instruct-ggml
```

#### Step 4: Test It
```bash
./scripts/run-ggml-inference.sh "Hello, how are you?"
```

## 📊 DeepSeek R1 Model Specifications

| Feature | Specification | Notes |
|---------|---------------|-------|
| **Model** | DeepSeek R1 Instruct | Latest instruction-tuned model |
| **Size** | 1.8GB | Optimized for mobile devices |
| **Memory** | 2.0GB | Efficient memory usage |
| **Format** | GGML Quantized | Best mobile performance |
| **Context** | 2048 tokens | Good conversation length |
| **Quality** | ⭐⭐⭐⭐⭐ | High-quality responses |
| **Speed** | ⚡⚡⚡ | Fast inference on mobile |

## 🔧 Setup Options

### DeepSeek R1 Setup
```bash
# Use DeepSeek R1 setup (no PyTorch needed)
./scripts/setup-deepseek-r1.sh
```

**Why DeepSeek R1 is Best for Termux:**
- ✅ **No PyTorch needed** - avoids ARM64 compatibility issues
- ✅ **Optimized size** (1.8GB - perfect balance for mobile)
- ✅ **Fast inference** with GGML optimization
- ✅ **Mobile-optimized** for Termux
- ✅ **High quality** - DeepSeek R1 is a powerful model
- ✅ **Context aware** - supports up to 2048 tokens

### Troubleshooting
```bash
# Run the troubleshooting script if you have issues
./scripts/termux-troubleshoot.sh
```

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
```

#### 2. Out of Memory
- Close other apps to free up memory
- DeepSeek R1 is optimized for mobile memory usage
- Context length is already optimized for 2048 tokens

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

1. **Explore DeepSeek R1 config**: `cat config/models-lightweight.json`
2. **Install DeepSeek R1 model**: Use the install script
3. **Customize settings**: Edit `.env` file
4. **Check logs**: Look in `logs/` directory

## 💡 Pro Tips

1. **DeepSeek R1 is optimized** - Perfect balance of size and quality
2. **Use external storage** - Models can go in `/storage/emulated/0/`
3. **Close other apps** - Free up memory for inference
4. **Keep Termux updated** - Run `pkg update` regularly
5. **Use GGML format** - Best performance on mobile devices

## 🚨 Common Issues & Quick Fixes

### "Package installation failed"
- This is normal in Termux
- System will use fallback methods
- You can still manage models

### "Model not found"
```bash
# Run: ./scripts/install-lightweight-model.sh deepseek-r1-instruct-ggml
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
MOMOS_DEFAULT_MODEL=deepseek-r1-instruct-ggml
```

### DeepSeek R1 Configuration
```bash
# Edit config/models-lightweight.json to customize DeepSeek R1 settings
# Adjust memory usage, context length, and other parameters
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

- DeepSeek team for the R1 model
- Open-source model developers
- Termux development team
- Mobile AI community

---

## 📱 Termux-Specific Notes

**Remember**: Termux is different from regular Linux. Some things will fail, but the system is designed to handle it gracefully and provide alternatives!

### What Gets Created During Setup

The setup scripts will create:
- `requirements-lightweight.txt` - No PyTorch dependencies
- `config/models-lightweight.json` - DeepSeek R1 configuration
- `scripts/run-ggml-inference.sh` - GGML inference script
- `scripts/install-lightweight-model.sh` - DeepSeek R1 installation
- `scripts/termux-troubleshoot.sh` - Termux troubleshooting
- `README-LIGHTWEIGHT.md` - Detailed instructions

### Performance Tips

- DeepSeek R1 is optimized for mobile performance
- Close other apps to free up memory
- Use external storage if available
- Keep Termux updated
- GGML format provides best mobile performance
- Context length optimized for 2048 tokens

---

**Made with ❤️ for the Termux mobile AI community - DeepSeek R1 Edition**
