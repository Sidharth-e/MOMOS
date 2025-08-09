# MOMOS (Mobile Open-source Model Operating Script)

A streamlined solution for running open-source AI models on Android devices using Termux.

## 🎯 What is MOMOS?

MOMOS is a collection of shell scripts designed specifically for Termux on Android to:
- Set up lightweight AI model environments
- Configure models for mobile device optimization
- Run inference with minimal setup hassle
- Troubleshoot common Termux issues

## 🚀 Features

- **Termux-optimized**: Built specifically for Android Termux environment
- **Lightweight setup**: No heavy PyTorch dependencies
- **Smart troubleshooting**: Built-in diagnostics for Termux issues
- **Mobile-optimized**: Pre-configured for mobile device constraints
- **One-command setup**: Run a single script to get everything working

## 📱 Supported Platform

- **Android**: Termux terminal emulator only

## 🛠️ Quick Start

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

### Termux Setup

#### Recommended: Lightweight Setup
```bash
# Use lightweight setup (no PyTorch needed)
./scripts/setup-lightweight.sh
```

#### Alternative: Full Termux Setup
```bash
# If lightweight fails, use full setup
./scripts/setup-termux.sh
```

#### Troubleshooting
```bash
# Run the troubleshooting script if you have issues
./scripts/termux-troubleshoot.sh
```

## 🔧 Troubleshooting

### Common Termux Issues
1. **Package installation fails**: This is normal - use lightweight setup
2. **Out of memory**: Close other apps and use smaller models
3. **Permission denied**: Make sure scripts are executable with `chmod +x`
4. **Storage issues**: Check available space with `df -h`

### Getting Help
- Run `./scripts/termux-troubleshoot.sh` for diagnostics
- Check the Termux guide: `cat TERMUX-QUICK-START.md`
- Open an issue on GitHub

## 📊 Performance Tips

- Use lightweight setup for better performance
- Close other apps to free up memory
- Use external storage if available
- Keep Termux updated

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

**Made with ❤️ for the Termux mobile AI community**
