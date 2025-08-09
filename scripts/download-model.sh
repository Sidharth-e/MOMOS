#!/bin/bash

# MOMOS Model Download Script
# Downloads models from HuggingFace with progress tracking and verification

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() { echo -e "${GREEN}[DOWNLOAD]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# Check if running in virtual environment
check_venv() {
    if [[ -z "$VIRTUAL_ENV" ]]; then
        warn "Not running in virtual environment. Activating..."
        if [[ -f "venv/bin/activate" ]]; then
            source venv/bin/activate
        else
            error "Virtual environment not found. Run setup.sh first."
            exit 1
        fi
    fi
}

# Download model from HuggingFace
download_hf_model() {
    local model_id=$1
    local model_name=$2
    local model_dir=$3
    
    log "Downloading $model_name from HuggingFace..."
    
    # Create Python script for downloading
    cat > temp_download.py << 'EOF'
import os
import sys
from pathlib import Path
from transformers import AutoTokenizer, AutoModelForCausalLM
from huggingface_hub import snapshot_download
import torch

def download_model(model_name, model_dir):
    try:
        print(f"Downloading {model_name} to {model_dir}...")
        
        # Download tokenizer
        print("Downloading tokenizer...")
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        tokenizer.save_pretrained(model_dir)
        
        # Download model with quantization for mobile
        print("Downloading model (quantized for mobile)...")
        model = AutoModelForCausalLM.from_pretrained(
            model_name,
            torch_dtype=torch.float16,
            low_cpu_mem_usage=True,
            device_map="auto"
        )
        
        # Save model
        model.save_pretrained(model_dir)
        
        print(f"Model downloaded successfully to {model_dir}")
        return True
        
    except Exception as e:
        print(f"Error downloading model: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python temp_download.py <model_name> <model_dir>")
        sys.exit(1)
    
    model_name = sys.argv[1]
    model_dir = sys.argv[2]
    
    success = download_model(model_name, model_dir)
    sys.exit(0 if success else 1)
EOF
    
    # Run download
    if python3 temp_download.py "$model_name" "$model_dir"; then
        log "Model downloaded successfully!"
        rm -f temp_download.py
        return 0
    else
        error "Failed to download model"
        rm -f temp_download.py
        return 1
    fi
}

# Verify model files
verify_model() {
    local model_dir=$1
    local model_id=$2
    
    log "Verifying model files..."
    
    # Check for essential files
    local required_files=("config.json" "tokenizer.json" "pytorch_model.bin")
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$model_dir/$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        error "Missing required files: ${missing_files[*]}"
        return 1
    fi
    
    # Check model size
    local model_size=$(du -sh "$model_dir" | cut -f1)
    log "Model size: $model_size"
    
    # Test model loading
    log "Testing model loading..."
    cat > temp_test.py << 'EOF'
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
from pathlib import Path
import sys

def test_model(model_dir):
    try:
        print("Loading tokenizer...")
        tokenizer = AutoTokenizer.from_pretrained(model_dir)
        
        print("Loading model...")
        model = AutoModelForCausalLM.from_pretrained(
            model_dir,
            torch_dtype=torch.float16,
            low_cpu_mem_usage=True,
            device_map="auto"
        )
        
        print("Testing inference...")
        test_input = "Hello, how are you?"
        inputs = tokenizer(test_input, return_tensors="pt")
        
        with torch.no_grad():
            outputs = model.generate(
                inputs.input_ids,
                max_length=50,
                do_sample=True,
                temperature=0.7,
                pad_token_id=tokenizer.eos_token_id
            )
        
        response = tokenizer.decode(outputs[0], skip_special_tokens=True)
        print(f"Test response: {response}")
        
        print("Model test successful!")
        return True
        
    except Exception as e:
        print(f"Model test failed: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python temp_test.py <model_dir>")
        sys.exit(1)
    
    model_dir = sys.argv[1]
    success = test_model(model_dir)
    sys.exit(0 if success else 1)
EOF
    
    if python3 temp_test.py "$model_dir"; then
        log "Model verification successful!"
        rm -f temp_test.py
        return 0
    else
        error "Model verification failed"
        rm -f temp_test.py
        return 1
    fi
}

# Main function
main() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 <model-id>"
        echo "Example: $0 phi-2"
        echo
        echo "Available models:"
        echo "  phi-2        - Microsoft Phi-2 (5.4GB)"
        echo "  mistral-7b   - Mistral 7B (13.1GB)"
        echo "  llama-2-7b   - LLaMA 2 7B (13.5GB)"
        exit 1
    fi
    
    local model_id=$1
    
    # Check virtual environment
    check_venv
    
    # Load configuration
    if [[ ! -f "config/models.json" ]]; then
        error "Configuration file not found. Run setup.sh first."
        exit 1
    fi
    
    # Get model info from config
    local model_info=$(python3 -c "
import json
import sys

try:
    with open('config/models.json') as f:
        config = json.load(f)
    
    if '$model_id' in config['available_models']:
        model = config['available_models']['$model_id']
        print(f'{model[\"name\"]}|{model[\"url\"]}|{model[\"size_gb\"]}|{model[\"memory_gb\"]}')
    else:
        print('NOT_FOUND')
        sys.exit(1)
except Exception as e:
    print(f'ERROR: {e}')
    sys.exit(1)
")
    
    if [[ $? -ne 0 ]]; then
        error "Failed to read configuration"
        exit 1
    fi
    
    if [[ "$model_info" == "NOT_FOUND" ]]; then
        error "Model '$model_id' not found in configuration"
        exit 1
    fi
    
    # Parse model info
    IFS='|' read -r model_name model_url size_gb memory_gb <<< "$model_info"
    
    # Check if model is already installed
    local model_dir="models/$model_id"
    if [[ -d "$model_dir" ]]; then
        warn "Model '$model_id' is already installed at $model_dir"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Skipping download"
            exit 0
        fi
        rm -rf "$model_dir"
    fi
    
    # Check system requirements
    log "Checking system requirements..."
    
    # Check disk space
    local available_space=$(df . | awk 'NR==2 {print $4}')
    local required_space=$((size_gb * 1024 * 1024 * 2))  # Double the size for safety
    
    if [[ $available_space -lt $required_space ]]; then
        error "Insufficient disk space. Need at least ${size_gb}GB, available: $((available_space / 1024 / 1024))GB"
        exit 1
    fi
    
    # Check memory
    if command -v free >/dev/null 2>&1; then
        local available_memory=$(free | awk '/^Mem:/{print $2}')
        local required_memory=$((memory_gb * 1024 * 1024))
        
        if [[ $available_memory -lt $required_memory ]]; then
            warn "Low memory. Model requires ${memory_gb}GB, available: $((available_memory / 1024 / 1024))GB"
            warn "Model may not work properly or may be very slow"
        fi
    fi
    
    # Create model directory
    mkdir -p "$model_dir"
    
    # Download model
    log "Starting download of $model_name..."
    log "Size: ${size_gb}GB"
    log "Memory required: ${memory_gb}GB"
    log "URL: $model_url"
    
    if download_hf_model "$model_id" "$model_url" "$model_dir"; then
        # Verify model
        if verify_model "$model_dir" "$model_id"; then
            log "🎉 Model '$model_id' installed successfully!"
            log "Location: $model_dir"
            log "You can now use: ./scripts/run-inference.sh \"Your prompt\" $model_id"
        else
            error "Model verification failed. Installation may be incomplete."
            exit 1
        fi
    else
        error "Failed to download model"
        rm -rf "$model_dir"
        exit 1
    fi
}

# Run main function
main "$@"
