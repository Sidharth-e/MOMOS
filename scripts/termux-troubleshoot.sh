#!/bin/bash

# MOMOS Termux Troubleshooting Script
# Helps diagnose and fix common issues in Termux

set -e

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

# Check Termux environment
check_termux() {
    if [[ -z "$TERMUX_VERSION" ]]; then
        error "This script is designed for Termux only!"
        exit 1
    fi
    
    log "Termux environment detected: $TERMUX_VERSION"
}

# Check system resources
check_resources() {
    log "Checking system resources..."
    
    # Check available memory
    if command -v free >/dev/null 2>&1; then
        MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
        log "Available memory: ${MEMORY_GB}GB"
        
        if [[ $MEMORY_GB -lt 2 ]]; then
            warn "Low memory detected! Consider using only the smallest models"
        fi
    fi
    
    # Check available disk space
    DISK_FREE=$(df . | awk 'NR==2 {print $4}')
    DISK_FREE_GB=$((DISK_FREE / 1024 / 1024))
    log "Available disk space: ${DISK_FREE_GB}GB"
    
    if [[ $DISK_FREE_GB -lt 3 ]]; then
        warn "Low disk space! You may need to free up space for models"
    fi
    
    # Check external storage
    if [[ -d "/storage/emulated/0" ]]; then
        info "External storage detected at /storage/emulated/0"
        info "Consider using external storage for large models"
    fi
}

# Check Python environment
check_python() {
    log "Checking Python environment..."
    
    # Check Python version
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    log "Python version: $PYTHON_VERSION"
    
    # Check if virtual environment exists
    if [[ -d "venv" ]]; then
        log "Virtual environment found"
        
        # Activate and check packages
        source venv/bin/activate
        
        # Check pip
        PIP_VERSION=$(pip --version 2>&1 | cut -d' ' -f2)
        log "Pip version: $PIP_VERSION"
        
        # Check installed packages
        log "Checking installed packages..."
        pip list | grep -E "(ctransformers|llama-cpp-python|onnxruntime|numpy|scipy)" || {
            warn "Some key packages are missing"
        }
        
        deactivate
    else
        warn "Virtual environment not found. Run setup-lightweight.sh first"
    fi
}

# Try to install problematic packages
install_packages() {
    log "Attempting to install problematic packages..."
    
    if [[ ! -d "venv" ]]; then
        error "Virtual environment not found. Run setup-lightweight.sh first"
        return 1
    fi
    
    source venv/bin/activate
    
    # Try installing packages one by one
    PACKAGES=("ctransformers" "llama-cpp-python" "onnxruntime-cpu")
    
    for package in "${PACKAGES[@]}"; do
        log "Trying to install $package..."
        
        if pip install "$package"; then
            log "✅ $package installed successfully"
        else
            warn "❌ $package failed to install"
            
            # Try alternative installation methods
            case "$package" in
                "ctransformers")
                    log "Trying ctransformers with --no-deps..."
                    pip install --no-deps ctransformers || warn "Alternative method failed"
                    ;;
                "llama-cpp-python")
                    log "Trying llama-cpp-python with specific flags..."
                    pip install llama-cpp-python --no-deps || warn "Alternative method failed"
                    ;;
                "onnxruntime-cpu")
                    log "Trying onnxruntime-cpu..."
                    pip install onnxruntime-cpu || warn "Alternative method failed"
                    ;;
            esac
        fi
    done
    
    deactivate
}

# Check model files
check_models() {
    log "Checking model files..."
    
    if [[ -d "models" ]]; then
        MODEL_COUNT=$(find models -name "*.bin" -o -name "*.ggml*" 2>/dev/null | wc -l)
        log "Found $MODEL_COUNT model files"
        
        if [[ $MODEL_COUNT -eq 0 ]]; then
            info "No models installed yet. Use install-lightweight-model.sh to install one"
        else
            find models -name "*.bin" -o -name "*.ggml*" 2>/dev/null | while read -r model; do
                SIZE=$(du -h "$model" | cut -f1)
                log "Model: $(basename "$model") ($SIZE)"
            done
        fi
    else
        warn "Models directory not found"
    fi
}

# Provide solutions
provide_solutions() {
    log "Providing solutions for common issues..."
    
    echo
    echo -e "${YELLOW}🔧 COMMON SOLUTIONS:${NC}"
    echo
    echo "1. If ML libraries fail to install:"
    echo "   - This is normal in Termux"
    echo "   - Use cloud inference instead"
    echo "   - Try external model runners"
    echo
    echo "2. If you get memory errors:"
    echo "   - Close other apps"
    echo "   - Use smaller models (TinyLlama)"
    echo "   - Reduce context length"
    echo
    echo "3. If you get disk space errors:"
    echo "   - Use external storage"
    echo "   - Remove unused models"
    echo "   - Use cloud inference"
    echo
    echo "4. Alternative inference methods:"
    echo "   - HuggingFace Inference API (free tier)"
    echo "   - Google Colab (free)"
    echo "   - OpenAI API (paid)"
    echo
    echo "5. For model management:"
    echo "   - Use install-lightweight-model.sh"
    echo "   - Download GGML/GGUF models only"
    echo "   - Avoid full PyTorch models"
}

# Main function
main() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              MOMOS Termux Troubleshooting                   ║"
    echo "║         Diagnose and fix common Termux issues               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_termux
    check_resources
    check_python
    check_models
    
    echo
    echo -e "${YELLOW}Would you like to try installing problematic packages? (y/n)${NC}"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        install_packages
    fi
    
    provide_solutions
    
    echo
    echo -e "${GREEN}Troubleshooting completed!${NC}"
    echo "If you still have issues, check the README-LIGHTWEIGHT.md file"
}

# Run main function
main "$@"
