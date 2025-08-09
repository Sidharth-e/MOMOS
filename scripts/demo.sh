#!/bin/bash

# MOMOS Demo Script
# Demonstrates the capabilities of the MOMOS system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log() { echo -e "${GREEN}[DEMO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
step() { echo -e "${PURPLE}[STEP]${NC} $1"; }
demo() { echo -e "${CYAN}[DEMO]${NC} $1"; }

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

# Welcome message
show_welcome() {
    clear
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    MOMOS Demo                               ║"
    echo "║         Mobile Open-source Model Operating Script           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
    echo "This demo will showcase the key features of MOMOS:"
    echo "• System setup and configuration"
    echo "• Model management and installation"
    echo "• Mobile optimization"
    echo "• Interactive chat and inference"
    echo "• Performance monitoring"
    echo
    read -p "Press Enter to continue..."
}

# Demo system status
demo_system_status() {
    step "1. Checking system status..."
    echo
    ./scripts/status.sh
    echo
    read -p "Press Enter to continue..."
}

# Demo model listing
demo_model_listing() {
    step "2. Listing available models..."
    echo
    ./scripts/list-models.sh
    echo
    read -p "Press Enter to continue..."
}

# Demo model installation (simulated)
demo_model_installation() {
    step "3. Demonstrating model installation..."
    echo
    info "Note: This is a demonstration. No actual models will be downloaded."
    echo
    
    # Check if any models are already installed
    if [[ -d "models" ]] && [[ "$(ls -A models 2>/dev/null)" ]]; then
        info "Found installed models:"
        ls -la models/
        echo
        info "You can install additional models with: ./scripts/download-model.sh <model-id>"
    else
        info "No models installed yet. You can install one with:"
        echo "  ./scripts/download-model.sh phi-2"
        echo
        info "This will download Microsoft Phi-2 (~5.4GB) optimized for mobile devices."
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Demo mobile optimization
demo_mobile_optimization() {
    step "4. Demonstrating mobile optimization..."
    echo
    info "Mobile optimization includes:"
    echo "• Platform detection (Android Termux, iOS iSH, etc.)"
    echo "• System settings optimization"
    echo "• Model quantization for mobile performance"
    echo "• Memory and resource management"
    echo
    
    if [[ -f "scripts/optimize-mobile.sh" ]]; then
        info "Mobile optimization script is available."
        echo "Run it with: ./scripts/optimize-mobile.sh"
    else
        warn "Mobile optimization script not found. Run setup.sh first."
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Demo inference capabilities
demo_inference() {
    step "5. Demonstrating inference capabilities..."
    echo
    info "MOMOS supports two inference modes:"
    echo "• Single inference: ./scripts/run-inference.sh \"Your prompt\" [model-id]"
    echo "• Interactive chat: ./scripts/run-inference.sh --interactive [model-id]"
    echo
    
    # Check if any models are available for inference
    if [[ -d "models" ]] && [[ "$(ls -A models 2>/dev/null)" ]]; then
        info "Available models for inference:"
        ls -d models/*/ 2>/dev/null | sed 's|models/||' | sed 's|/||' | while read model; do
            echo "  • $model"
        done
        echo
        info "You can test inference with:"
        echo "  ./scripts/run-inference.sh \"Hello, how are you?\""
    else
        info "No models available for inference yet."
        echo "Install a model first with: ./scripts/download-model.sh phi-2"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Demo performance monitoring
demo_performance_monitoring() {
    step "6. Demonstrating performance monitoring..."
    echo
    info "MOMOS includes built-in performance monitoring:"
    echo "• Real-time resource usage tracking"
    echo "• Memory and CPU monitoring"
    echo "• Temperature monitoring (where available)"
    echo "• Process tracking"
    echo
    
    if [[ -f "scripts/monitor-performance.sh" ]]; then
        info "Performance monitoring script is available."
        echo "Usage:"
        echo "  ./scripts/monitor-performance.sh              # Single snapshot"
        echo "  ./scripts/monitor-performance.sh continuous   # Continuous monitoring"
        echo "  ./scripts/monitor-performance.sh continuous 10 # Every 10 seconds"
    else
        warn "Performance monitoring script not found. Run setup.sh first."
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Demo interactive features
demo_interactive_features() {
    step "7. Demonstrating interactive features..."
    echo
    info "MOMOS interactive features include:"
    echo "• Interactive chat mode with conversation history"
    echo "• Command help system"
    echo "• Conversation management (clear, history)"
    echo "• Graceful exit handling"
    echo
    
    info "To start interactive chat:"
    echo "  ./scripts/run-inference.sh --interactive [model-id]"
    echo
    info "Available commands in chat mode:"
    echo "  help     - Show help"
    echo "  clear    - Clear conversation history"
    echo "  history  - Show conversation history"
    echo "  quit     - Exit chat"
    echo
    
    read -p "Press Enter to continue..."
}

# Demo configuration management
demo_configuration() {
    step "8. Demonstrating configuration management..."
    echo
    info "MOMOS uses JSON configuration files:"
    echo "• config/models.json - Model definitions and settings"
    echo "• config/mobile-optimized.json - Mobile-specific settings"
    echo "• .env - Environment variables"
    echo
    
    if [[ -f "config/models.json" ]]; then
        info "Current model configuration:"
        python3 -c "
import json
from pathlib import Path

try:
    with open('config/models.json') as f:
        config = json.load(f)
    
    print(f'Default model: {config.get(\"default_model\", \"Not set\")}')
    print(f'Available models: {len(config.get(\"available_models\", {}))}')
    print(f'Global settings: {list(config.get(\"settings\", {}).keys())}')
    
except Exception as e:
    print(f'Error reading config: {e}')
"
    else
        warn "Configuration file not found. Run setup.sh first."
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Show next steps
show_next_steps() {
    step "9. Next steps and getting started..."
    echo
    echo -e "${GREEN}🎯 Getting Started with MOMOS:${NC}"
    echo
    echo "1. ${CYAN}Initial Setup:${NC}"
    echo "   ./scripts/setup.sh"
    echo
    echo "2. ${CYAN}Install a Model:${NC}"
    echo "   ./scripts/download-model.sh phi-2"
    echo
    echo "3. ${CYAN}Mobile Optimization:${NC}"
    echo "   ./scripts/optimize-mobile.sh"
    echo
    echo "4. ${CYAN}Run Inference:${NC}"
    echo "   ./scripts/run-inference.sh \"Hello, world!\""
    echo
    echo "5. ${CYAN}Interactive Chat:${NC}"
    echo "   ./scripts/run-inference.sh --interactive phi-2"
    echo
    echo "6. ${CYAN}Monitor Performance:${NC}"
    echo "   ./scripts/monitor-performance.sh"
    echo
    echo -e "${GREEN}📚 Additional Resources:${NC}"
    echo "• README.md - Complete documentation"
    echo "• config/ - Configuration files"
    echo "• logs/ - System logs"
    echo "• scripts/ - All available scripts"
    echo
    echo -e "${GREEN}🚀 Ready to run AI models on your mobile device!${NC}"
    echo
}

# Main demo function
main() {
    show_welcome
    demo_system_status
    demo_model_listing
    demo_model_installation
    demo_mobile_optimization
    demo_inference
    demo_performance_monitoring
    demo_interactive_features
    demo_configuration
    show_next_steps
    
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🎉 MOMOS Demo completed! 🎉${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo
    echo "Thank you for exploring MOMOS!"
    echo "Start building amazing mobile AI applications today!"
    echo
}

# Run main function
main "$@"
