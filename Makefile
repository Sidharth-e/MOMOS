# MOMOS Makefile
# Mobile Open-source Model Operating Script

.PHONY: help setup install-model run-inference interactive optimize demo status clean

# Default target
help:
	@echo "MOMOS - Mobile Open-source Model Operating Script"
	@echo "=================================================="
	@echo
	@echo "Available commands:"
	@echo "  setup           - Initial setup and installation"
	@echo "  install-model   - Install a specific model (e.g., make install-model MODEL=phi-2)"
	@echo "  run-inference   - Run inference with a prompt (e.g., make run-inference PROMPT='Hello' MODEL=phi-2)"
	@echo "  interactive     - Start interactive chat mode (e.g., make interactive MODEL=phi-2)"
	@echo "  optimize        - Optimize for mobile devices"
	@echo "  demo            - Run the interactive demo"
	@echo "  status          - Check system status"
	@echo "  list-models     - List available models"
	@echo "  monitor         - Monitor system performance"
	@echo "  clean           - Clean temporary files"
	@echo "  help            - Show this help message"
	@echo
	@echo "Examples:"
	@echo "  make setup"
	@echo "  make install-model MODEL=phi-2"
	@echo "  make run-inference PROMPT='Tell me a joke' MODEL=phi-2"
	@echo "  make interactive MODEL=phi-2"
	@echo "  make optimize"
	@echo "  make demo"

# Initial setup
setup:
	@echo "🚀 Setting up MOMOS..."
	@chmod +x scripts/*.sh
	@./scripts/setup.sh

# Install a model
install-model:
	@if [ -z "$(MODEL)" ]; then \
		echo "❌ Error: MODEL parameter required"; \
		echo "Usage: make install-model MODEL=<model-id>"; \
		echo "Example: make install-model MODEL=phi-2"; \
		exit 1; \
	fi
	@echo "📥 Installing model: $(MODEL)"
	@./scripts/download-model.sh $(MODEL)

# Run inference
run-inference:
	@if [ -z "$(PROMPT)" ]; then \
		echo "❌ Error: PROMPT parameter required"; \
		echo "Usage: make run-inference PROMPT='<your prompt>' [MODEL=<model-id>]"; \
		echo "Example: make run-inference PROMPT='Hello, how are you?' MODEL=phi-2"; \
		exit 1; \
	fi
	@echo "🤖 Running inference..."
	@if [ -n "$(MODEL)" ]; then \
		./scripts/run-inference.sh "$(PROMPT)" $(MODEL); \
	else \
		./scripts/run-inference.sh "$(PROMPT)"; \
	fi

# Interactive mode
interactive:
	@if [ -n "$(MODEL)" ]; then \
		echo "💬 Starting interactive chat with $(MODEL)..."; \
		./scripts/run-inference.sh --interactive $(MODEL); \
	else \
		echo "💬 Starting interactive chat with default model..."; \
		./scripts/run-inference.sh --interactive; \
	fi

# Mobile optimization
optimize:
	@echo "📱 Optimizing for mobile devices..."
	@./scripts/optimize-mobile.sh

# Run demo
demo:
	@echo "🎭 Running MOMOS demo..."
	@./scripts/demo.sh

# Check status
status:
	@echo "📊 Checking system status..."
	@./scripts/status.sh

# List models
list-models:
	@echo "📋 Listing available models..."
	@./scripts/list-models.sh

# Monitor performance
monitor:
	@echo "📈 Starting performance monitoring..."
	@./scripts/monitor-performance.sh

# Clean temporary files
clean:
	@echo "🧹 Cleaning temporary files..."
	@rm -f temp_*.py
	@rm -f temp_*.sh
	@find . -name "*.pyc" -delete
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "✅ Cleanup completed"

# Quick start (setup + install default model)
quickstart: setup
	@echo "🚀 Quick start: Installing default model..."
	@make install-model MODEL=phi-2

# Test the system
test: status list-models
	@echo "🧪 Testing inference with a simple prompt..."
	@make run-inference PROMPT="Hello, this is a test" MODEL=phi-2 || echo "⚠️  No models installed yet. Run 'make install-model MODEL=phi-2' first."

# Show project info
info:
	@echo "MOMOS Project Information"
	@echo "========================"
	@echo "Project: Mobile Open-source Model Operating Script"
	@echo "Purpose: Run AI models on mobile devices without hassle"
	@echo "Platforms: Android (Termux), iOS (iSH), Linux, Windows"
	@echo "License: MIT"
	@echo
	@echo "Project Structure:"
	@echo "  scripts/     - Shell scripts and utilities"
	@echo "  config/      - Configuration files"
	@echo "  models/      - Downloaded AI models"
	@echo "  logs/        - System logs"
	@echo "  venv/        - Python virtual environment"
	@echo
	@echo "Key Features:"
	@echo "  • One-command setup"
	@echo "  • Mobile-optimized models"
	@echo "  • Interactive chat mode"
	@echo "  • Performance monitoring"
	@echo "  • Cross-platform support"
