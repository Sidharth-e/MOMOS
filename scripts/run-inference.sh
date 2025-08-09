#!/bin/bash

# MOMOS Inference Script
# Runs inference with downloaded models, optimized for mobile devices

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() { echo -e "${GREEN}[INFERENCE]${NC} $1"; }
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

# Interactive mode
interactive_mode() {
    local model_id=$1
    local model_dir="models/$model_id"
    
    log "Starting interactive chat mode with $model_id..."
    log "Type 'quit' or 'exit' to end the session"
    log "Type 'help' for available commands"
    echo
    
    # Create interactive Python script
    cat > temp_interactive.py << 'EOF'
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
import sys
import os
from pathlib import Path

class MOMOSChat:
    def __init__(self, model_dir):
        self.model_dir = model_dir
        self.tokenizer = None
        self.model = None
        self.conversation_history = []
        self.max_history = 10
        
    def load_model(self):
        try:
            print("Loading tokenizer...")
            self.tokenizer = AutoTokenizer.from_pretrained(self.model_dir)
            
            # Add padding token if not present
            if self.tokenizer.pad_token is None:
                self.tokenizer.pad_token = self.tokenizer.eos_token
            
            print("Loading model...")
            self.model = AutoModelForCausalLM.from_pretrained(
                self.model_dir,
                torch_dtype=torch.float16,
                low_cpu_mem_usage=True,
                device_map="auto"
            )
            
            print("Model loaded successfully!")
            return True
            
        except Exception as e:
            print(f"Error loading model: {e}")
            return False
    
    def generate_response(self, prompt, max_length=100, temperature=0.7):
        try:
            # Prepare input
            inputs = self.tokenizer(prompt, return_tensors="pt", padding=True, truncation=True)
            
            # Generate response
            with torch.no_grad():
                outputs = self.model.generate(
                    inputs.input_ids,
                    max_length=max_length,
                    do_sample=True,
                    temperature=temperature,
                    pad_token_id=self.tokenizer.eos_token_id,
                    eos_token_id=self.tokenizer.eos_token_id,
                    repetition_penalty=1.1
                )
            
            # Decode response
            response = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
            
            # Remove the input prompt from response
            if response.startswith(prompt):
                response = response[len(prompt):].strip()
            
            return response
            
        except Exception as e:
            return f"Error generating response: {e}"
    
    def chat(self):
        print("Chat started! Type your message:")
        print("-" * 50)
        
        while True:
            try:
                user_input = input("\nYou: ").strip()
                
                if user_input.lower() in ['quit', 'exit', 'bye']:
                    print("Goodbye! 👋")
                    break
                elif user_input.lower() == 'help':
                    self.show_help()
                    continue
                elif user_input.lower() == 'clear':
                    self.conversation_history.clear()
                    print("Conversation history cleared.")
                    continue
                elif user_input.lower() == 'history':
                    self.show_history()
                    continue
                elif not user_input:
                    continue
                
                # Add to history
                self.conversation_history.append(f"You: {user_input}")
                if len(self.conversation_history) > self.max_history * 2:
                    self.conversation_history = self.conversation_history[-self.max_history * 2:]
                
                # Generate response
                print("AI: ", end="", flush=True)
                response = self.generate_response(user_input)
                print(response)
                
                # Add response to history
                self.conversation_history.append(f"AI: {response}")
                
            except KeyboardInterrupt:
                print("\n\nGoodbye! 👋")
                break
            except EOFError:
                print("\n\nGoodbye! 👋")
                break
    
    def show_help(self):
        print("\nAvailable commands:")
        print("  help     - Show this help message")
        print("  clear    - Clear conversation history")
        print("  history  - Show conversation history")
        print("  quit     - Exit the chat")
        print("  exit     - Exit the chat")
        print("  bye      - Exit the chat")
    
    def show_history(self):
        if not self.conversation_history:
            print("No conversation history yet.")
            return
        
        print("\nConversation History:")
        print("-" * 30)
        for i, message in enumerate(self.conversation_history[-10:], 1):
            print(f"{i}. {message}")

def main():
    if len(sys.argv) != 2:
        print("Usage: python temp_interactive.py <model_dir>")
        sys.exit(1)
    
    model_dir = sys.argv[1]
    
    if not Path(model_dir).exists():
        print(f"Model directory not found: {model_dir}")
        sys.exit(1)
    
    chat = MOMOSChat(model_dir)
    
    if chat.load_model():
        chat.chat()
    else:
        print("Failed to load model")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF
    
    # Run interactive mode
    if python3 temp_interactive.py "$model_dir"; then
        log "Interactive session ended"
    else
        error "Interactive session failed"
        exit 1
    fi
    
    # Cleanup
    rm -f temp_interactive.py
}

# Single inference mode
single_inference() {
    local prompt=$1
    local model_id=$2
    local model_dir="models/$model_id"
    
    log "Running single inference with $model_id..."
    log "Prompt: $prompt"
    
    # Create single inference Python script
    cat > temp_single.py << 'EOF'
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
import sys
from pathlib import Path

def run_inference(prompt, model_dir):
    try:
        print("Loading tokenizer...")
        tokenizer = AutoTokenizer.from_pretrained(model_dir)
        
        if tokenizer.pad_token is None:
            tokenizer.pad_token = tokenizer.eos_token
        
        print("Loading model...")
        model = AutoModelForCausalLM.from_pretrained(
            model_dir,
            torch_dtype=torch.float16,
            low_cpu_mem_usage=True,
            device_map="auto"
        )
        
        print("Running inference...")
        inputs = tokenizer(prompt, return_tensors="pt", padding=True, truncation=True)
        
        with torch.no_grad():
            outputs = model.generate(
                inputs.input_ids,
                max_length=len(inputs.input_ids[0]) + 100,
                do_sample=True,
                temperature=0.7,
                pad_token_id=tokenizer.eos_token_id,
                eos_token_id=tokenizer.eos_token_id,
                repetition_penalty=1.1
            )
        
        response = tokenizer.decode(outputs[0], skip_special_tokens=True)
        
        # Remove input prompt from response
        if response.startswith(prompt):
            response = response[len(prompt):].strip()
        
        print("\n" + "="*50)
        print("PROMPT:")
        print(prompt)
        print("\nRESPONSE:")
        print(response)
        print("="*50)
        
        return True
        
    except Exception as e:
        print(f"Error during inference: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python temp_single.py <prompt> <model_dir>")
        sys.exit(1)
    
    prompt = sys.argv[1]
    model_dir = sys.argv[2]
    
    success = run_inference(prompt, model_dir)
    sys.exit(0 if success else 1)
EOF
    
    # Run single inference
    if python3 temp_single.py "$prompt" "$model_dir"; then
        log "Inference completed successfully"
    else
        error "Inference failed"
        exit 1
    fi
    
    # Cleanup
    rm -f temp_single.py
}

# Main function
main() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 \"<prompt>\" [model-id] [--interactive]"
        echo "Examples:"
        echo "  $0 \"Hello, how are you?\" phi-2"
        echo "  $0 --interactive phi-2"
        echo "  $0 \"Tell me a joke\""
        echo
        echo "Options:"
        echo "  --interactive  - Start interactive chat mode"
        echo
        echo "Available models:"
        echo "  phi-2        - Microsoft Phi-2 (5.4GB)"
        echo "  mistral-7b   - Mistral 7B (13.1GB)"
        echo "  llama-2-7b   - LLaMA 2 7B (13.5GB)"
        exit 1
    fi
    
    # Check virtual environment
    check_venv
    
    # Parse arguments
    local prompt=""
    local model_id=""
    local interactive=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --interactive)
                interactive=true
                shift
                ;;
            *)
                if [[ -z "$prompt" ]]; then
                    prompt="$1"
                elif [[ -z "$model_id" ]]; then
                    model_id="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Set default model if not specified
    if [[ -z "$model_id" ]]; then
        if [[ -f ".env" ]]; then
            model_id=$(grep DEFAULT_MODEL .env | cut -d'=' -f2)
        else
            model_id="phi-2"  # Default fallback
        fi
        log "Using default model: $model_id"
    fi
    
    # Check if model is installed
    local model_dir="models/$model_id"
    if [[ ! -d "$model_dir" ]]; then
        error "Model '$model_id' is not installed"
        echo "Install it first with: ./scripts/download-model.sh $model_id"
        exit 1
    fi
    
    # Run appropriate mode
    if [[ "$interactive" == true ]]; then
        interactive_mode "$model_id"
    else
        if [[ -z "$prompt" ]]; then
            error "No prompt provided"
            exit 1
        fi
        single_inference "$prompt" "$model_id"
    fi
}

# Run main function
main "$@"
