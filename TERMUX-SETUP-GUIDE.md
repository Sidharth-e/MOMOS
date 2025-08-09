# MOMOS Termux Setup Guide

## The Problem

The original `setup.sh` script fails in Termux because PyTorch doesn't have official ARM64 builds for Android/Termux. You'll get this error:

```
error: could not find a version that satisfies the requirement torch>=2.0.0
error: no matching distribution found for torch>=2.0.0
```

## Solutions

I've created two alternative setup scripts for Termux:

### Option 1: Termux-Specific Setup (Recommended)
```bash
# In Termux, run:
./scripts/setup-termux.sh
```

This script:
- Detects Termux environment
- Tries PyTorch nightly builds (sometimes works)
- Falls back to PyTorch from source (very slow)
- Creates mobile-optimized configurations
- Provides troubleshooting guide

### Option 2: Lightweight Setup (Best for Mobile)
```bash
# In Termux, run:
./scripts/setup-lightweight.sh
```

This script:
- **Completely avoids PyTorch**
- Uses GGML/GGUF models instead
- Much smaller models (0.7-1.4GB vs 2-13GB)
- Faster inference with lower memory usage
- Perfect for mobile devices

## Quick Fix for Original Script

If you want to try the original script with modifications:

1. **Edit the requirements.txt** to remove PyTorch:
```bash
# Comment out or remove this line:
# torch>=2.0.0
```

2. **Install alternatives manually**:
```bash
pip install onnxruntime ctransformers
```

3. **Use GGML models** instead of full models

## Why PyTorch Fails in Termux

- **Architecture**: Termux runs on ARM64, PyTorch has limited ARM64 support
- **Android**: PyTorch doesn't officially support Android/Termux
- **Dependencies**: Many PyTorch dependencies aren't available in Termux

## Recommended Approach

For Termux, use **Option 2 (Lightweight Setup)** because:

✅ **No PyTorch needed**  
✅ **Smaller models** (0.7-1.4GB)  
✅ **Faster inference**  
✅ **Lower memory usage**  
✅ **Mobile-optimized**  

## Model Recommendations for Termux

1. **Phi-2 GGML** (1.4GB) - Best overall performance
2. **TinyLlama GGML** (0.7GB) - Fastest, smallest  
3. **GPT4All-J GGML** (1.2GB) - Good balance

## Installation Steps in Termux

```bash
# 1. Clone the repository
git clone <your-repo-url>
cd MOMOS

# 2. Run lightweight setup (recommended)
./scripts/setup-lightweight.sh

# 3. Activate virtual environment
source venv/bin/activate

# 4. Install a lightweight model
./scripts/install-lightweight-model.sh phi-2-ggml

# 5. Run inference
./scripts/run-ggml-inference.sh "Hello, world!"
```

## Troubleshooting

### If you still get errors:
```bash
# Install dependencies manually
pip install ctransformers llama-cpp-python onnxruntime

# Check available packages
pkg list-installed | grep python
```

### Memory issues:
- Close other apps
- Use smaller models
- Reduce context length

### Performance tips:
- Use quantized models (int4/int8)
- Limit context to 128-256 tokens
- Use external storage for large models

## Alternative: Cloud Inference

If local inference is too slow:
- Use HuggingFace Inference API
- Try Google Colab (free tier)
- Use cloud-based inference services

## Files Created

The setup scripts will create:
- `requirements-lightweight.txt` - No PyTorch dependencies
- `config/models-lightweight.json` - Mobile-optimized models
- `scripts/run-ggml-inference.sh` - GGML inference script
- `scripts/install-lightweight-model.sh` - Model installation
- `README-LIGHTWEIGHT.md` - Detailed instructions
- `TROUBLESHOOTING-TERMUX.md` - Common issues and solutions

## Next Steps

1. **Choose your setup**: Lightweight (recommended) or Termux-specific
2. **Run the setup script** in Termux
3. **Install a lightweight model**
4. **Test inference**
5. **Check the troubleshooting guide** if you have issues

The lightweight approach will give you a working MOMOS setup in Termux without the PyTorch headaches!
