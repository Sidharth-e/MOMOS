#!/bin/bash
# Run inference using GGML models (no PyTorch needed)

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

# Check if prompt is provided
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 \"<prompt>\" [model-id]"
    echo "Example: $0 \"Hello, how are you?\" phi-2-ggml"
    echo ""
    echo "Available models:"
    echo "  tiny-llama-ggml     - TinyLlama 0.7GB (fastest, smallest)"
    echo "  phi-2-ggml         - Phi-2 1.4GB (good quality, medium speed)"
    echo "  gpt4all-j-ggml     - GPT4All-J 1.2GB (balanced)"
    echo "  llama-2-7b-ggml    - Llama-2 7B 4.0GB (best quality, slower)"
    exit 1
fi

PROMPT=$1
MODEL_ID=${2:-$(grep DEFAULT_MODEL .env 2>/dev/null | cut -d'=' -f2 || echo "tiny-llama-ggml")}

# Check if we're in the right directory
if [[ ! -f ".env" ]]; then
    error "Not in MOMOS project directory! Please run this from the MOMOS root folder."
    exit 1
fi

# Source environment variables
source .env

# Check if config file exists
CONFIG_FILE="config/models-lightweight.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Lightweight configuration file not found! Run setup-lightweight.sh first."
    exit 1
fi

# Check if models directory exists
if [[ ! -d "$MOMOS_MODELS_DIR" ]]; then
    error "Models directory not found! Run setup-lightweight.sh first."
    exit 1
fi

log "Running GGML inference with model: $MODEL_ID"
log "Prompt: $PROMPT"
echo ""

# Python inference script
python3 -c "
import json
import os
import sys
from pathlib import Path

def run_ggml_inference(prompt, model_id):
    try:
        # Load configuration
        config_file = Path('config/models-lightweight.json')
        if not config_file.exists():
            print('❌ Lightweight configuration file not found!')
            print('   Run: ./scripts/setup-lightweight.sh')
            return False
        
        with open(config_file) as f:
            config = json.load(f)
        
        if model_id not in config['available_models']:
            print(f'❌ Model {model_id} not found in lightweight configuration!')
            print('   Available models: {list(config[\"available_models\"].keys())}')
            return False
        
        model_info = config['available_models'][model_id]
        model_dir = Path(f'{os.environ.get(\"MOMOS_MODELS_DIR\", \"./models/\")}{model_id}')
        
        if not model_dir.exists():
            print(f'❌ Model {model_id} is not installed!')
            print(f'   Run: ./scripts/install-lightweight-model.sh {model_id}')
            return False
        
        print(f'🚀 Running GGML inference with {model_info[\"name\"]}...')
        print(f'📝 Prompt: {prompt}')
        print(f'💾 Model: {model_id}')
        print(f'📁 Location: {model_dir}')
        print('─' * 50)
        
        # Try multiple inference methods with fallbacks
        inference_success = False
        
        # Method 1: Try ctransformers
        if not inference_success:
            try:
                from ctransformers import AutoModelForCausalLM
                print('🔧 Using ctransformers for inference...')
                
                # Find the GGML model file
                model_files = list(model_dir.glob('*.ggml*.bin')) + list(model_dir.glob('*.gguf'))
                if not model_files:
                    print('❌ No GGML/GGUF model files found!')
                    print(f'   Expected in: {model_dir}')
                    return False
                
                model_file = model_files[0]
                print(f'📄 Using model file: {model_file.name}')
                
                # Load and run the model
                llm = AutoModelForCausalLM.from_pretrained(
                    str(model_dir),
                    model_type='llama',  # Most GGML models are llama-based
                    gpu_layers=0,  # CPU only for mobile
                    lib='avx2'  # Use appropriate CPU optimization
                )
                
                print('✅ Model loaded successfully!')
                print('🤖 Generating response...')
                
                # Generate response
                response = llm(prompt, max_new_tokens=128, temperature=0.7)
                print('\\n💬 Response:')
                print('─' * 30)
                print(response)
                print('─' * 30)
                inference_success = True
                
            except ImportError:
                print('⚠️  ctransformers not available, trying next method...')
            except Exception as e:
                print(f'❌ ctransformers failed: {e}')
                print('   Trying next method...')
        
        # Method 2: Try llama-cpp-python
        if not inference_success:
            try:
                from llama_cpp import Llama
                print('🔧 Using llama-cpp-python for inference...')
                
                # Find the GGML model file
                model_files = list(model_dir.glob('*.ggml*.bin')) + list(model_dir.glob('*.gguf'))
                if not model_files:
                    print('❌ No GGML/GGUF model files found!')
                    return False
                
                model_file = model_files[0]
                print(f'📄 Using model file: {model_file.name}')
                
                # Load and run the model
                llm = Llama(
                    model_path=str(model_file),
                    n_ctx=128,  # Small context for mobile
                    n_threads=1,  # Single thread for mobile
                    n_gpu_layers=0  # CPU only
                )
                
                print('✅ Model loaded successfully!')
                print('🤖 Generating response...')
                
                # Generate response
                response = llm(prompt, max_tokens=128, temperature=0.7)
                print('\\n💬 Response:')
                print('─' * 30)
                print(response['choices'][0]['text'])
                print('─' * 30)
                inference_success = True
                
            except ImportError:
                print('⚠️  llama-cpp-python not available, trying fallback...')
            except Exception as e:
                print(f'❌ llama-cpp-python failed: {e}')
                print('   Trying fallback...')
        
        # Method 3: Fallback - show model info and instructions
        if not inference_success:
            print('\\n⚠️  No ML inference libraries available!')
            print('\\nThis is common in Termux. Here are your options:')
            print('\\n1. Install missing libraries manually:')
            print('   pip install ctransformers')
            print('   pip install llama-cpp-python')
            print('\\n2. Use cloud inference instead:')
            print('   - HuggingFace Inference API')
            print('   - Google Colab (free)')
            print('   - OpenAI API (paid)')
            print('\\n3. Download pre-built binaries:')
            print('   - Check if your model has pre-built inference tools')
            print('   - Look for ARM64/Android versions')
            print('\\n4. Use the model with external tools:')
            print(f'   Model location: {model_dir}')
            print(f'   Model files: {list(model_dir.glob(\"*.bin\")) + list(model_dir.glob(\"*.gguf\"))}')
            print('\\nFor now, showing model information:')
            print(f'📊 Model: {model_info[\"name\"]}')
            print(f'💾 Size: {model_info[\"size_gb\"]}GB')
            print(f'📋 Format: {model_info.get(\"format\", \"ggml\")}')
            print(f'📝 Notes: {model_info.get(\"notes\", \"No additional notes\")}')
            return False
        
        return True
        
    except Exception as e:
        print(f'❌ Unexpected error: {e}')
        return False

# Run inference
success = run_ggml_inference('$PROMPT', '$MODEL_ID')
if success:
    print('\\n🎉 Inference completed successfully!')
else:
    print('\\n❌ Inference failed. Check the messages above for solutions.')
    sys.exit(1)
"

# Check if Python script succeeded
if [[ $? -eq 0 ]]; then
    success "Inference completed!"
else
    error "Inference failed! Check the error messages above."
    exit 1
fi
