#!/bin/bash

# MOMOS - Mobile Open-source Model Operating Script
# Main setup script for initial installation and configuration

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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root. This is not recommended for security reasons."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Detect platform
detect_platform() {
    log "Detecting platform..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            PLATFORM="$ID"
        else
            PLATFORM="linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        PLATFORM="macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        PLATFORM="windows"
    else
        PLATFORM="unknown"
    fi
    
    # Check for mobile-specific environments
    if [[ -n "$TERMUX_VERSION" ]]; then
        PLATFORM="android-termux"
    elif [[ -n "$ISH_VERSION" ]]; then
        PLATFORM="ios-ish"
    fi
    
    log "Detected platform: $PLATFORM"
}

# Check system requirements
check_requirements() {
    log "Checking system requirements..."
    
    # Check available memory
    if command -v free >/dev/null 2>&1; then
        MEMORY_KB=$(free | awk '/^Mem:/{print $2}')
        MEMORY_GB=$((MEMORY_KB / 1024 / 1024))
        log "Available memory: ${MEMORY_GB}GB"
        
        if [[ $MEMORY_GB -lt 2 ]]; then
            warn "Low memory detected (${MEMORY_GB}GB). Some models may not work properly."
        fi
    fi
    
    # Check available disk space
    if command -v df >/dev/null 2>&1; then
        DISK_SPACE=$(df . | awk 'NR==2 {print $4}')
        DISK_SPACE_GB=$((DISK_SPACE / 1024 / 1024))
        log "Available disk space: ${DISK_SPACE_GB}GB"
        
        if [[ $DISK_SPACE_GB -lt 2 ]]; then
            error "Insufficient disk space (${DISK_SPACE_GB}GB). Need at least 2GB."
            exit 1
        fi
    fi
    
    # Check Python
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
        log "Python version: $PYTHON_VERSION"
        
        # Check if version is 3.8+
        PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
        PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
        
        if [[ $PYTHON_MAJOR -lt 3 ]] || [[ $PYTHON_MAJOR -eq 3 && $PYTHON_MINOR -lt 8 ]]; then
            warn "Python 3.8+ required. Found: $PYTHON_VERSION"
            INSTALL_PYTHON=true
        else
            INSTALL_PYTHON=false
        fi
    else
        warn "Python 3 not found. Will install..."
        INSTALL_PYTHON=true
    fi
}

# Install Python if needed
install_python() {
    if [[ "$INSTALL_PYTHON" == true ]]; then
        log "Installing Python 3.8+..."
        
        case "$PLATFORM" in
            "android-termux")
                pkg update -y
                pkg install -y python
                ;;
            "ios-ish")
                apk update
                apk add python3 py3-pip
                ;;
            "ubuntu"|"debian"|"linuxmint")
                sudo apt update
                sudo apt install -y python3 python3-pip python3-venv
                ;;
            "fedora"|"rhel"|"centos")
                sudo dnf install -y python3 python3-pip python3-venv
                ;;
            "arch")
                sudo pacman -S --noconfirm python python-pip python-virtualenv
                ;;
            "macos")
                if command -v brew >/dev/null 2>&1; then
                    brew install python@3.11
                else
                    error "Homebrew not found. Please install Homebrew first."
                    exit 1
                fi
                ;;
            *)
                error "Unsupported platform for Python installation: $PLATFORM"
                exit 1
                ;;
        esac
        
        log "Python installation completed"
    fi
}

# Create project structure
create_structure() {
    log "Creating project structure..."
    
    mkdir -p {models,config,logs,scripts,temp}
    
    # Create config files
    cat > config/models.json << 'EOF'
{
    "available_models": {
        "llama-2-7b": {
            "name": "LLaMA 2 7B",
            "size_gb": 13.5,
            "memory_gb": 8,
            "url": "https://huggingface.co/meta-llama/Llama-2-7b-chat-hf",
            "quantized": true,
            "mobile_optimized": true
        },
        "mistral-7b": {
            "name": "Mistral 7B",
            "size_gb": 13.1,
            "memory_gb": 7,
            "url": "https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.2",
            "quantized": true,
            "mobile_optimized": true
        },
        "phi-2": {
            "name": "Microsoft Phi-2",
            "size_gb": 5.4,
            "memory_gb": 4,
            "url": "https://huggingface.co/microsoft/phi-2",
            "quantized": true,
            "mobile_optimized": true
        }
    },
    "default_model": "phi-2",
    "settings": {
        "max_memory_usage": 0.8,
        "quantization": "int8",
        "batch_size": 1,
        "max_length": 512
    }
}
EOF
    
    # Create environment file
    cat > .env << 'EOF'
# MOMOS Environment Configuration
MOMOS_HOME=$(pwd)
MOMOS_MODELS_DIR=models/
MOMOS_LOGS_DIR=logs/
MOMOS_TEMP_DIR=temp/
MOMOS_CONFIG_DIR=config/

# Model settings
DEFAULT_MODEL=phi-2
MAX_MEMORY_USAGE=0.8
QUANTIZATION=int8

# Logging
LOG_LEVEL=INFO
LOG_FILE=logs/momos.log
EOF
    
    log "Project structure created successfully"
}

# Install Python dependencies
install_dependencies() {
    log "Installing Python dependencies..."
    
    # Create virtual environment
    python3 -m venv venv
    source venv/bin/activate
    
    # Create requirements.txt
    cat > requirements.txt << 'EOF'
torch>=2.0.0
transformers>=4.30.0
accelerate>=0.20.0
sentencepiece>=0.1.99
protobuf>=3.20.0
numpy>=1.24.0
requests>=2.28.0
tqdm>=4.64.0
colorama>=0.4.6
psutil>=5.9.0
EOF
    
    # Install dependencies
    pip install --upgrade pip
    pip install -r requirements.txt
    
    log "Dependencies installed successfully"
}

# Create utility scripts
create_scripts() {
    log "Creating utility scripts..."
    
    # List models script
    cat > scripts/list-models.sh << 'EOF'
#!/bin/bash
# List available models and their status

source .env
python3 -c "
import json
import os
from pathlib import Path

config_file = Path('config/models.json')
if config_file.exists():
    with open(config_file) as f:
        config = json.load(f)
    
    print('Available Models:')
    print('=' * 50)
    
    for model_id, model_info in config['available_models'].items():
        model_path = Path(f'{os.environ[\"MOMOS_MODELS_DIR\"]}{model_id}')
        status = '✓ Installed' if model_path.exists() else '✗ Not installed'
        
        print(f'{model_info[\"name\"]} ({model_id})')
        print(f'  Size: {model_info[\"size_gb\"]}GB')
        print(f'  Memory: {model_info[\"memory_gb\"]}GB')
        print(f'  Status: {status}')
        print()
else:
    print('Configuration file not found!')
"
EOF
    
    # Install model script
    cat > scripts/install-model.sh << 'EOF'
#!/bin/bash
# Install a specific model

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
import requests
from pathlib import Path
from tqdm import tqdm

def download_model(model_id):
    config_file = Path('config/models.json')
    if not config_file.exists():
        print('Configuration file not found!')
        return
    
    with open(config_file) as f:
        config = json.load(f)
    
    if model_id not in config['available_models']:
        print(f'Model {model_id} not found in configuration!')
        return
    
    model_info = config['available_models'][model_id]
    model_dir = Path(f'{os.environ[\"MOMOS_MODELS_DIR\"]}{model_id}')
    
    if model_dir.exists():
        print(f'Model {model_id} is already installed!')
        return
    
    print(f'Installing {model_info[\"name\"]}...')
    print(f'Size: {model_info[\"size_gb\"]}GB')
    print(f'Memory required: {model_info[\"memory_gb\"]}GB')
    
    # This is a simplified download - in practice you'd use HuggingFace's API
    print('Note: This is a placeholder. Implement actual model download logic.')
    print('For now, you can manually download models from HuggingFace.')
    
    # Create model directory
    model_dir.mkdir(parents=True, exist_ok=True)
    print(f'Model directory created: {model_dir}')

download_model('$MODEL_ID')
"
EOF
    
    # Run inference script
    cat > scripts/run-inference.sh << 'EOF'
#!/bin/bash
# Run inference with the specified model

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

def run_inference(prompt, model_id):
    config_file = Path('config/models.json')
    if not config_file.exists():
        print('Configuration file not found!')
        return
    
    with open(config_file) as f:
        config = json.load(f)
    
    if model_id not in config['available_models']:
        print(f'Model {model_id} not found!')
        return
    
    model_info = config['available_models'][model_id]
    model_dir = Path(f'{os.environ[\"MOMOS_MODELS_DIR\"]}{model_id}')
    
    if not model_dir.exists():
        print(f'Model {model_id} is not installed!')
        print(f'Run: ./scripts/install-model.sh {model_id}')
        return
    
    print(f'Running inference with {model_info[\"name\"]}...')
    print(f'Prompt: {prompt}')
    print('-' * 50)
    
    # This is a placeholder - implement actual inference logic
    print('Note: This is a placeholder. Implement actual model inference.')
    print('You can use transformers library to load and run the model.')
    print('Example:')
    print('from transformers import AutoTokenizer, AutoModelForCausalLM')
    print('tokenizer = AutoTokenizer.from_pretrained(model_dir)')
    print('model = AutoModelForCausalLM.from_pretrained(model_dir)')
    print('# ... inference code ...')

run_inference('$PROMPT', '$MODEL_ID')
"
EOF
    
    # Status script
    cat > scripts/status.sh << 'EOF'
#!/bin/bash
# Check system status and model status

source .env

echo "MOMOS System Status"
echo "=================="
echo

# Check Python
if command -v python3 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3 --version 2>&1)
    echo "✓ Python: $PYTHON_VERSION"
else
    echo "✗ Python: Not found"
fi

# Check virtual environment
if [[ -d "venv" ]]; then
    echo "✓ Virtual environment: Active"
else
    echo "✗ Virtual environment: Not found"
fi

# Check available memory
if command -v free >/dev/null 2>&1; then
    MEMORY_KB=$(free | awk '/^Mem:/{print $2}')
    MEMORY_GB=$((MEMORY_KB / 1024 / 1024))
    echo "✓ Available memory: ${MEMORY_GB}GB"
fi

# Check disk space
if command -v df >/dev/null 2>&1; then
    DISK_SPACE=$(df . | awk 'NR==2 {print $4}')
    DISK_SPACE_GB=$((DISK_SPACE / 1024 / 1024))
    echo "✓ Available disk space: ${DISK_SPACE_GB}GB"
fi

echo
echo "Model Status:"
echo "-------------"

python3 -c "
import json
from pathlib import Path

config_file = Path('config/models.json')
if config_file.exists():
    with open(config_file) as f:
        config = json.load(f)
    
    for model_id, model_info in config['available_models'].items():
        model_path = Path(f'models/{model_id}')
        status = '✓' if model_path.exists() else '✗'
        print(f'{status} {model_info[\"name\"]} ({model_id})')
else:
    print('Configuration file not found!')
"
EOF
    
    # Make scripts executable
    chmod +x scripts/*.sh
    
    log "Utility scripts created successfully"
}

# Main setup function
main() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    MOMOS Setup Script                       ║"
    echo "║         Mobile Open-source Model Operating Script           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_root
    detect_platform
    check_requirements
    install_python
    create_structure
    install_dependencies
    create_scripts
    
    echo
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🎉 MOMOS setup completed successfully! 🎉${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo
    echo "Next steps:"
    echo "1. Activate virtual environment: source venv/bin/activate"
    echo "2. List available models: ./scripts/list-models.sh"
    echo "3. Install a model: ./scripts/install-model.sh phi-2"
    echo "4. Run inference: ./scripts/run-inference.sh \"Hello, world!\""
    echo "5. Check status: ./scripts/status.sh"
    echo
    echo "For more information, see README.md"
    echo
}

# Run main function
main "$@"
