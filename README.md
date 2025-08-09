# MOMOS (Mobile Open-source Model Operating Script)

A streamlined solution for running open-source AI models on mobile devices without the usual setup complexity.

## 🎯 What is MOMOS?

MOMOS is a collection of shell scripts and tools designed to make it easy to:
- Download and set up open-source AI models
- Configure them for mobile device optimization
- Run inference with minimal setup hassle
- Manage model versions and updates

## 🚀 Features

- **One-command setup**: Run a single script to get everything working
- **Mobile-optimized**: Pre-configured for mobile device constraints
- **Model variety**: Support for multiple popular open-source models
- **Cross-platform**: Works on Android (Termux), iOS (iSH), and Linux
- **Resource management**: Automatic memory and storage optimization
- **Termux-optimized**: Enhanced lightweight setup with fallback methods
- **Smart troubleshooting**: Built-in diagnostics and problem-solving tools

## 📱 Supported Platforms

- **Android**: Termux, UserLAnd, or similar terminal emulators
- **iOS**: iSH, a-Shell, or similar terminal apps
- **Linux**: Native Linux distributions
- **Windows**: WSL2 or Git Bash

## 🛠️ Quick Start

### Prerequisites
- Terminal/Shell access on your mobile device
- Internet connection for model downloads
- At least 2GB free storage space
- Python 3.8+ (will be installed automatically if needed)

### Installation
```bash
# Clone or download the project
git clone https://github.com/Sidharth-e/momos.git
cd momos

# Make scripts executable
chmod +x scripts/*.sh

# Choose your setup method:
# Standard setup (Linux/Windows)
./scripts/setup.sh

# Lightweight setup (Termux/Android - recommended)
./scripts/setup-lightweight.sh

# Termux-specific setup (if lightweight fails)
./scripts/setup-termux.sh
```

### Platform-Specific Setup

#### For Termux (Android) - Recommended
```bash
# Use lightweight setup (no PyTorch needed)
./scripts/setup-lightweight.sh

# If you encounter issues, run troubleshooting:
./scripts/termux-troubleshoot.sh
```

#### For Linux/Windows
```bash
# Use standard setup
./scripts/setup.sh
```

### Basic Usage
```bash
# List available models
./scripts/list-models.sh

# Install a specific model
./scripts/install-model.sh llama-2-7b

# Run inference
./scripts/run-inference.sh "Hello, how are you?"

# Check system status
./scripts/status.sh
```

## 📋 Available Models

- **LLaMA 2** (7B, 13B variants)
- **Mistral** (7B, Mixtral variants)
- **Phi-2** (Microsoft's lightweight model)
- **Gemma** (Google's open models)
- **Custom models** (add your own!)

## ⚙️ Configuration

Models can be configured in `config/models.json`:
- Model size and type
- Memory allocation
- Performance settings
- Custom parameters

## 🔧 Troubleshooting

### Common Issues
1. **Out of memory**: Reduce model size in config
2. **Slow performance**: Enable GPU acceleration if available
3. **Download fails**: Check internet connection and try again
4. **Package installation fails** (Termux): This is normal - use lightweight setup

### Platform-Specific Help

#### Termux (Android)
```bash
# Run the troubleshooting script
./scripts/termux-troubleshoot.sh

# Use lightweight setup (recommended)
./scripts/setup-lightweight.sh

# Check the Termux guide
cat TERMUX-QUICK-START.md
```

#### Linux/Windows
```bash
# Run debug script
./scripts/debug.sh

# Check system requirements
./scripts/check-requirements.sh
```

### Getting Help
- Check the logs in `logs/` directory
- Run `./scripts/debug.sh` for system diagnostics
- For Termux: Run `./scripts/termux-troubleshoot.sh`
- Open an issue on GitHub

## 📊 Performance Tips

- Use smaller models (7B parameters) for mobile devices
- Enable quantization for faster inference
- Close other apps to free up memory
- Use SSD storage when possible

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
- Mobile development community
- Terminal app developers

---

**Made with ❤️ for the mobile AI community**
