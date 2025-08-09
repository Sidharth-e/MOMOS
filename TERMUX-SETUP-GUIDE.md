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

### Option 2: Lightweight Setup (Best for Mobile) ⭐ **UPDATED**
```bash
# In Termux, run:
./scripts/setup-lightweight.sh
```

This script has been **improved for Termux**:
- **Completely avoids PyTorch**
- Uses GGML/GGUF models instead
- Much smaller models (0.7-1.4GB vs 2-13GB)
- Faster inference with lower memory usage
- **Better error handling for Termux**
- **Fallback methods when ML libraries fail**
- **Termux-specific optimizations**

## NEW: Termux Troubleshooting Script

If you encounter issues during setup, use the new troubleshooting script:

```bash
# Run after setup to diagnose issues:
./scripts/termux-troubleshoot.sh
```

This script will:
- Check your Termux environment
- Verify system resources (memory, disk space)
- Test Python packages
- Try to install problematic libraries
- Provide solutions for common issues

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
✅ **Better Termux compatibility**  
✅ **Fallback methods included**  

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

# 3. If you encounter issues, run troubleshooting:
./scripts/termux-troubleshoot.sh

# 4. Activate virtual environment
source venv/bin/activate

# 5. Install a lightweight model
./scripts/install-lightweight-model.sh phi-2-ggml

# 6. Run inference
./scripts/run-ggml-inference.sh "Hello, world!"
```

## What's New in the Updated Lightweight Setup

The lightweight setup script has been enhanced with:

- **Better error handling**: Continues even if some packages fail
- **Fallback installation methods**: Tries alternative ways to install problematic libraries
- **Termux-specific warnings**: Clear information about what to expect
- **Graceful degradation**: System works even when ML libraries fail
- **Multiple inference methods**: Tries different approaches for running models
- **Comprehensive fallback**: Provides alternatives when local inference isn't possible

## Troubleshooting

### If you still get errors:
```bash
# Run the troubleshooting script first:
./scripts/termux-troubleshoot.sh

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

If local inference is too slow or fails:
- Use HuggingFace Inference API
- Try Google Colab (free tier)
- Use cloud-based inference services

## Files Created

The setup scripts will create:
- `requirements-lightweight.txt` - No PyTorch dependencies
- `config/models-lightweight.json` - Mobile-optimized models
- `scripts/run-ggml-inference.sh` - GGML inference script (with fallbacks)
- `scripts/install-lightweight-model.sh` - Model installation
- `scripts/termux-troubleshoot.sh` - **NEW** Termux troubleshooting
- `README-LIGHTWEIGHT.md` - Detailed instructions

## Next Steps

1. **Choose your setup**: Lightweight (recommended) or Termux-specific
2. **Run the setup script** in Termux
3. **If issues occur**: Run the troubleshooting script
4. **Install a lightweight model**
5. **Test inference**
6. **Use fallback methods** if needed

The updated lightweight approach will give you a working MOMOS setup in Termux with better error handling and fallback options!
