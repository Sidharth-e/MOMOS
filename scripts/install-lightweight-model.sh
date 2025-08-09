#!/bin/bash
# Install lightweight GGML models for MOMOS

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[MOMOS]${NC} $1"
}

# Error function
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Warning function
warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Success function
success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if model ID is provided
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <model-id>"
    echo ""
    echo "Available models:"
    echo "  tiny-llama-ggml     - TinyLlama 0.7GB (fastest, smallest)"
    echo "  phi-2-ggml         - Phi-2 1.4GB (good quality, medium speed)"
    echo "  gpt4all-j-ggml     - GPT4All-J 1.2GB (balanced)"
    echo "  llama-2-7b-ggml    - Llama-2 7B 4.0GB (best quality, slower)"
    echo ""
    echo "Example: $0 tiny-llama-ggml"
    exit 1
fi

MODEL_ID=$1

# Check if we're in the right directory
if [[ ! -f ".env" ]]; then
    error "Not in MOMOS project directory! Please run this from the MOMOS root folder."
    exit 1
fi

# Source environment variables
source .env

# Check if models directory exists
if [[ ! -d "$MOMOS_MODELS_DIR" ]]; then
    log "Creating models directory..."
    mkdir -p "$MOMOS_MODELS_DIR"
fi

# Check if config file exists
CONFIG_FILE="config/models-lightweight.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Lightweight configuration file not found! Run setup-lightweight.sh first."
    exit 1
fi

# Function to download model
download_model() {
    local model_id=$1
    local url=$2
    local filename=$3
    local expected_size=$4
    
    log "Downloading $model_id..."
    log "URL: $url"
    log "Expected size: $expected_size"
    
    # Create model directory
    local model_dir="$MOMOS_MODELS_DIR$model_id"
    mkdir -p "$model_dir"
    
    # Download the model
    if command -v wget &> /dev/null; then
        wget -O "$model_dir/$filename" "$url" --progress=bar:force:noscroll
    elif command -v curl &> /dev/null; then
        curl -L -o "$model_dir/$filename" "$url" --progress-bar
    else
        error "Neither wget nor curl found! Please install one of them."
        exit 1
    fi
    
    # Check if download was successful
    if [[ $? -eq 0 ]] && [[ -f "$model_dir/$filename" ]]; then
        success "Download completed!"
        
        # Get actual file size
        actual_size=$(du -h "$model_dir/$filename" | cut -f1)
        log "Actual size: $actual_size"
        
        # Verify file integrity (basic check)
        if [[ -s "$model_dir/$filename" ]]; then
            success "File integrity check passed!"
            return 0
        else
            error "Downloaded file is empty or corrupted!"
            rm -f "$model_dir/$filename"
            return 1
        fi
    else
        error "Download failed!"
        return 1
    fi
}

# Function to install model from HuggingFace
install_from_huggingface() {
    local model_id=$1
    local repo_id=$2
    
    log "Installing $model_id from HuggingFace..."
    log "Repository: $repo_id"
    
    # Create model directory
    local model_dir="$MOMOS_MODELS_DIR$model_id"
    mkdir -p "$model_dir"
    
    # Try to use huggingface-hub if available
    if python3 -c "import huggingface_hub" 2>/dev/null; then
        log "Using huggingface-hub to download..."
        python3 -c "
import os
from huggingface_hub import snapshot_download

try:
    snapshot_download(
        repo_id='$repo_id',
        local_dir='$model_dir',
        local_dir_use_symlinks=False,
        allow_patterns=['*.ggml*.bin', '*.gguf', '*.bin'],
        ignore_patterns=['*.safetensors', '*.ckpt', '*.pt', '*.pth']
    )
    print('Download completed successfully!')
except Exception as e:
    print(f'Error: {e}')
    exit(1)
"
        
        if [[ $? -eq 0 ]]; then
            success "HuggingFace download completed!"
            return 0
        else
            warning "HuggingFace download failed, trying manual download..."
        fi
    fi
    
    # Fallback: manual download of common GGML models
    warning "Manual download not implemented for HuggingFace models yet."
    warning "Please download manually from: https://huggingface.co/$repo_id"
    warning "Place the GGML/GGUF files in: $model_dir"
    return 1
}

# Main installation logic
log "Installing model: $MODEL_ID"

# Check if model is already installed
if [[ -d "$MOMOS_MODELS_DIR$MODEL_ID" ]]; then
    warning "Model $MODEL_ID is already installed!"
    echo "Location: $MOMOS_MODELS_DIR$MODEL_ID"
    echo "Contents:"
    ls -la "$MOMOS_MODELS_DIR$MODEL_ID"
    echo ""
    read -p "Do you want to reinstall? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Installation cancelled."
        exit 0
    fi
    log "Removing existing installation..."
    rm -rf "$MOMOS_MODELS_DIR$MODEL_ID"
fi

# Model installation logic based on model ID
case $MODEL_ID in
    "tiny-llama-ggml")
        log "Installing TinyLlama GGML model..."
        # Try direct download first
        if download_model "tiny-llama-ggml" \
            "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGML/resolve/main/tinyllama-1.1b-chat-v1.0.ggmlv3.q4_0.bin" \
            "tinyllama-1.1b-chat-v1.0.ggmlv3.q4_0.bin" \
            "0.7GB"; then
            success "TinyLlama GGML installed successfully!"
        else
            warning "Direct download failed, trying HuggingFace..."
            install_from_huggingface "tiny-llama-ggml" "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGML"
        fi
        ;;
        
    "phi-2-ggml")
        log "Installing Phi-2 GGML model..."
        install_from_huggingface "phi-2-ggml" "TheBloke/phi-2-GGML"
        ;;
        
    "gpt4all-j-ggml")
        log "Installing GPT4All-J GGML model..."
        install_from_huggingface "gpt4all-j-ggml" "TheBloke/gpt4all-j-GGML"
        ;;
        
    "llama-2-7b-ggml")
        log "Installing Llama-2 7B GGML model..."
        install_from_huggingface "llama-2-7b-ggml" "TheBloke/Llama-2-7B-Chat-GGML"
        ;;
        
    *)
        error "Unknown model ID: $MODEL_ID"
        echo ""
        echo "Available models:"
        echo "  tiny-llama-ggml     - TinyLlama 0.7GB"
        echo "  phi-2-ggml         - Phi-2 1.4GB"
        echo "  gpt4all-j-ggml     - GPT4All-J 1.2GB"
        echo "  llama-2-7b-ggml    - Llama-2 7B 4.0GB"
        exit 1
        ;;
esac

# Final verification
if [[ -d "$MOMOS_MODELS_DIR$MODEL_ID" ]]; then
    echo ""
    success "Model installation completed!"
    echo "Model location: $MOMOS_MODELS_DIR$MODEL_ID"
    echo "Contents:"
    ls -la "$MOMOS_MODELS_DIR$MODEL_ID"
    echo ""
    echo "Next steps:"
    echo "1. Test the model: ./scripts/run-ggml-inference.sh \"Hello!\" $MODEL_ID"
    echo "2. Check model info: cat config/models-lightweight.json | grep -A 10 $MODEL_ID"
    echo ""
else
    error "Model installation failed!"
    echo "Please check the error messages above and try again."
    exit 1
fi
