# MOMOS Termux Quick Start Guide

## 🚀 Get MOMOS Running in 5 Minutes (Termux)

### Step 1: Clone and Setup
```bash
git clone <your-repo-url>
cd MOMOS
./scripts/setup-lightweight.sh
```

### Step 2: Activate Environment
```bash
source venv/bin/activate
```

### Step 3: Install a Model
```bash
./scripts/install-lightweight-model.sh tiny-llama-ggml
```

### Step 4: Test It
```bash
./scripts/run-ggml-inference.sh "Hello, how are you?"
```

## ⚠️ What to Expect in Termux

- **Some packages will fail to install** - This is normal!
- **The system will continue working** - Uses fallback methods
- **You can still manage models** - Download, organize, etc.
- **Inference may use alternatives** - Cloud APIs, external tools

## 🔧 If Something Goes Wrong

```bash
# Run the troubleshooting script:
./scripts/termux-troubleshoot.sh

# Or try manual fixes:
pip install ctransformers
pip install llama-cpp-python
pip install onnxruntime-cpu
```

## 📱 Model Recommendations for Termux

| Model | Size | Memory | Speed | Quality |
|-------|------|--------|-------|---------|
| **TinyLlama** | 0.7GB | 1.0GB | ⚡⚡⚡ | ⭐⭐ |
| **GPT4All-J** | 1.2GB | 1.2GB | ⚡⚡ | ⭐⭐⭐ |
| **Phi-2** | 1.4GB | 1.5GB | ⚡ | ⭐⭐⭐⭐ |

## 💡 Pro Tips

1. **Start with TinyLlama** - Fastest, smallest, most reliable
2. **Use external storage** - Models can go in `/storage/emulated/0/`
3. **Close other apps** - Free up memory for inference
4. **Use cloud inference** - When local is too slow

## 🚨 Common Issues & Quick Fixes

### "Package installation failed"
- This is normal in Termux
- System will use fallback methods
- You can still manage models

### "Out of memory"
- Close other apps
- Use smaller models
- Reduce context length

### "Model not found"
- Run: `./scripts/install-lightweight-model.sh <model-name>`
- Check: `ls models/`

### "Inference failed"
- Try cloud inference instead
- Use external model runners
- Check model file integrity

## 🌐 Cloud Inference Alternatives

When local inference fails:

1. **HuggingFace Inference API** (free tier)
2. **Google Colab** (free)
3. **OpenAI API** (paid)

## 📁 What Gets Created

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

## 📞 Need Help?

1. **Run troubleshooting**: `./scripts/termux-troubleshoot.sh`
2. **Check logs**: `tail -f logs/momos.log`
3. **Read full guide**: `TERMUX-SETUP-GUIDE.md`
4. **Check lightweight guide**: `README-LIGHTWEIGHT.md`

---

**Remember**: Termux is different from regular Linux. Some things will fail, but the system is designed to handle it gracefully and provide alternatives!
