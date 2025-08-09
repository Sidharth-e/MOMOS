#!/bin/bash

# MOMOS - Mobile Open-source Model Operating Script
# Termux-specific setup script for Android/Termux environments

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[MOMOS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running in Termux
check_termux() {
    if [[ -z "$TERMUX_VERSION" ]]; then
        error "This script is designed for Termux only!"
        error "Please use the main setup.sh script for other platforms."
        exit 1
    fi
    
    log "Termux environment detected: $TERMUX_VERSION"
}

# Update Termux packages
update_termux() {
    log "Updating Termux packages..."
    pkg update -y
    pkg upgrade -y
    log "Termux packages updated"
}

# Install system dependencies
install_system_deps() {
    log "Installing system dependencies..."
    
    # Essential packages
    pkg install -y python git wget curl
    
    # Development tools
    pkg install -y build-essential cmake
    
    # Additional libraries that might be needed
    pkg install -y libjpeg-turbo libpng
    
    log "System dependencies installed"
}

# Install Python dependencies for Termux
install_python_deps() {
    log "Installing Python dependencies for Termux..."
    
    # Create virtual environment
    python3 -m venv venv
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install basic dependencies first
    log "Installing basic dependencies..."
    pip install numpy requests tqdm colorama psutil
    
    # Try to install PyTorch alternatives for Termux
    log "Attempting PyTorch installation for Termux..."
    
    # Method 1: Try PyTorch nightly builds (sometimes available for ARM64)
    if pip install --pre torch --index-url https://download.pytorch.org/whl/nightly/cpu; then
        log "PyTorch nightly build installed successfully"
    else
        warn "PyTorch nightly build failed, trying alternative approach..."
        
        # Method 2: Try installing from source (very slow, not recommended)
        warn "PyTorch from source is very slow and may fail on mobile devices"
        read -p "Attempt PyTorch from source? This may take hours! (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Installing PyTorch from source (this will take a very long time)..."
            pip install torch --no-binary torch
        else
            warn "Skipping PyTorch installation"
        fi
    fi
    
    # Install other dependencies
    log "Installing remaining dependencies..."
    pip install transformers accelerate sentencepiece protobuf
    
    log "Python dependencies installation completed"
}

# Create mobile-optimized requirements
create_mobile_requirements() {
    log "Creating mobile-optimized requirements..."
    
    cat > requirements-mobile.txt << 'EOF'
# Mobile-optimized requirements for Termux
# Note: PyTorch installation may fail - see setup instructions

# Core ML libraries (PyTorch alternatives)
numpy>=1.24.0
scipy>=1.10.0

# Text processing
transformers>=4.30.0
tokenizers>=0.13.0
sentencepiece>=0.1.99

# Model optimization
accelerate>=0.20.0
optimum>=1.12.0

# Utilities
requests>=2.28.0
tqdm>=4.64.0
colorama>=0.4.6
psutil>=5.9.0
protobuf>=3.20.0

# Mobile-specific optimizations
onnxruntime>=1.15.0
openvino>=2023.0.0
EOF
    
    log "Mobile requirements file created"
}

# Create mobile-optimized configuration
create_mobile_config() {
    log "Creating mobile-optimized configuration..."
    
    cat > config/models-mobile.json << 'EOF'
{
    "available_models": {
        "phi-2": {
            "name": "Microsoft Phi-2 (Mobile Optimized)",
            "size_gb": 2.7,
            "memory_gb": 2,
            "url": "https://huggingface.co/microsoft/phi-2",
            "quantized": true,
            "mobile_optimized": true,
            "format": "onnx",
            "notes": "Best for mobile devices, very lightweight"
        },
        "tiny-llama": {
            "name": "TinyLlama 1.1B (Mobile Optimized)",
            "size_gb": 2.0,
            "memory_gb": 1.5,
            "url": "https://huggingface.co/TinyLlama/TinyLlama-1.1B-Chat-v1.0",
            "quantized": true,
            "mobile_optimized": true,
            "format": "onnx",
            "notes": "Ultra-lightweight, good for basic tasks"
        },
        "gpt4all-j": {
            "name": "GPT4All-J (Mobile Optimized)",
            "size_gb": 3.9,
            "memory_gb": 2.5,
            "url": "https://huggingface.co/nomic-ai/gpt4all-j",
            "quantized": true,
            "mobile_optimized": true,
            "format": "ggml",
            "notes": "Good balance of performance and size"
        }
    },
    "default_model": "phi-2",
    "settings": {
        "max_memory_usage": 0.6,
        "quantization": "int8",
        "batch_size": 1,
        "max_length": 256,
        "use_onnx": true,
        "use_ggml": true
    }
}
EOF
    
    log "Mobile configuration created"
}

# Create mobile-optimized scripts
create_mobile_scripts() {
    log "Creating mobile-optimized scripts..."
    
    # Mobile-optimized inference script
    cat > scripts/run-mobile-inference.sh << 'EOF'
#!/bin/bash
# Mobile-optimized inference script for Termux

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 \"<prompt>\" [model-id]"
    echo "Example: $0 \"Hello, how are you?\" phi-2"
    exit 1
fi

PROMPT=$1
MODEL_ID=${2:-$(grep DEFAULT_MODEL .env | cut -d'=' -f2)}

source .env

python3 -c "
import json
import os
from pathlib import Path

def run_mobile_inference(prompt, model_id):
    config_file = Path('config/models-mobile.json')
    if not config_file.exists():
        print('Mobile configuration file not found!')
        return
    
    with open(config_file) as f:
        config = json.load(f)
    
    if model_id not in config['available_models']:
        print(f'Model {model_id} not found in mobile configuration!')
        return
    
    model_info = config['available_models'][model_id]
    model_dir = Path(f'{os.environ[\"MOMOS_MODELS_DIR\"]}{model_id}')
    
    if not model_dir.exists():
        print(f'Model {model_id} is not installed!')
        print(f'Run: ./scripts/install-mobile-model.sh {model_id}')
        return
    
    print(f'Running mobile inference with {model_info[\"name\"]}...')
    print(f'Prompt: {prompt}')
    print('-' * 50)
    
    # Mobile-optimized inference logic
    try:
        if model_info.get('format') == 'onnx':
            print('Using ONNX Runtime for inference...')
            # ONNX inference code would go here
            print('ONNX inference placeholder - implement actual logic')
        elif model_info.get('format') == 'ggml':
            print('Using GGML for inference...')
            # GGML inference code would go here
            print('GGML inference placeholder - implement actual logic')
        else:
            print('Using standard transformers for inference...')
            # Standard inference code would go here
            print('Standard inference placeholder - implement actual logic')
    except Exception as e:
        print(f'Inference failed: {e}')
        print('This may be due to PyTorch installation issues in Termux')

run_mobile_inference('$PROMPT', '$MODEL_ID')
"
EOF
    
    # Mobile model installation script
    cat > scripts/install-mobile-model.sh << 'EOF'
#!/bin/bash
# Install mobile-optimized models

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <model-id>"
    echo "Example: $0 phi-2"
    exit 1
fi

MODEL_ID=$1
source .env

python3 -c "
import json
import os
from pathlib import Path

def install_mobile_model(model_id):
    config_file = Path('config/models-mobile.json')
    if not config_file.exists():
        print('Mobile configuration file not found!')
        return
    
    with open(config_file) as f:
        config = json.load(f)
    
    if model_id not in config['available_models']:
        print(f'Model {model_id} not found in mobile configuration!')
        return
    
    model_info = config['available_models'][model_id]
    model_dir = Path(f'{os.environ[\"MOMOS_MODELS_DIR\"]}{model_id}')
    
    if model_dir.exists():
        print(f'Model {model_id} is already installed!')
        return
    
    print(f'Installing mobile model: {model_info[\"name\"]}')
    print(f'Size: {model_info[\"size_gb\"]}GB')
    print(f'Memory required: {model_info[\"memory_gb\"]}GB')
    print(f'Format: {model_info.get(\"format\", \"standard\")}')
    print()
    
    # Check available space
    import shutil
    total, used, free = shutil.disk_usage('.')
    free_gb = free // (1024**3)
    
    if free_gb < model_info['size_gb']:
        print(f'Warning: Only {free_gb}GB free space available')
        print(f'Model requires {model_info[\"size_gb\"]}GB')
        return
    
    # Create model directory
    model_dir.mkdir(parents=True, exist_ok=True)
    print(f'Model directory created: {model_dir}')
    
    print()
    print('Note: This is a placeholder installation.')
    print('For actual model downloads, you can:')
    print('1. Use HuggingFace CLI: huggingface-cli download')
    print('2. Download manually from the provided URL')
    print('3. Use git-lfs if available in Termux')
    print()
    print('Model URL:', model_info['url'])

install_mobile_model('$MODEL_ID')
"
EOF
    
    # Make scripts executable
    chmod +x scripts/*.sh
    
    log "Mobile scripts created successfully"
}

# Create troubleshooting guide
create_troubleshooting() {
    log "Creating troubleshooting guide..."
    
    cat > TROUBLESHOOTING-TERMUX.md << 'EOF'
# MOMOS Troubleshooting Guide for Termux

## PyTorch Installation Issues

If you encounter PyTorch installation errors in Termux, this is normal and expected. PyTorch doesn't have official ARM64 builds for Android/Termux.

### Alternative Solutions:

1. **Use ONNX Runtime** (Recommended)
   - Install: `pip install onnxruntime`
   - Convert models to ONNX format for mobile inference
   - Better performance and smaller size

2. **Use GGML/GGUF Models**
   - Install: `pip install ctransformers`
   - Use quantized models specifically designed for mobile
   - Very lightweight and fast

3. **Use HuggingFace Inference API**
   - No local model installation needed
   - Requires internet connection
   - Good for testing and development

### Model Recommendations for Termux:

- **Phi-2**: 2.7GB, very lightweight
- **TinyLlama**: 2.0GB, ultra-lightweight
- **GPT4All-J**: 3.9GB, good balance

### Performance Tips:

1. Use quantized models (int8 or int4)
2. Limit context length to 256-512 tokens
3. Close other apps to free memory
4. Use external storage for large models

### Common Issues:

1. **Out of Memory**: Reduce batch size and context length
2. **Slow Performance**: Use quantized models and ONNX runtime
3. **Installation Failures**: Try alternative package managers or manual installation

### Getting Help:

- Check the MOMOS logs in the `logs/` directory
- Review model-specific documentation
- Consider using cloud-based inference for development
EOF
    
    log "Troubleshooting guide created"
}

# Main setup function
main() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                MOMOS Termux Setup Script                    ║"
    echo "║         Mobile Open-source Model Operating Script           ║"
    echo "║                    (Android/Termux)                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_termux
    update_termux
    install_system_deps
    create_mobile_requirements
    create_mobile_config
    install_python_deps
    create_mobile_scripts
    create_troubleshooting
    
    echo
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🎉 MOMOS Termux setup completed! 🎉${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo
    echo "Important Notes for Termux:"
    echo "⚠️  PyTorch installation may have failed - this is normal!"
    echo "📱 Use mobile-optimized models and scripts"
    echo "🔧 Check TROUBLESHOOTING-TERMUX.md for solutions"
    echo
    echo "Next steps:"
    echo "1. Activate virtual environment: source venv/bin/activate"
    echo "2. List mobile models: cat config/models-mobile.json"
    echo "3. Install a mobile model: ./scripts/install-mobile-model.sh phi-2"
    echo "4. Run mobile inference: ./scripts/run-mobile-inference.sh \"Hello!\""
    echo
    echo "For PyTorch alternatives, see TROUBLESHOOTING-TERMUX.md"
    echo
}

# Run main function
main "$@"
