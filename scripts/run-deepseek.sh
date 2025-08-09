#!/bin/bash

# DeepSeek R1 Quick Start Script
# Run this script after completing the setup process

echo "=== DeepSeek R1 Local Runner ==="
echo ""

# Check if we're in Termux
if [ ! -d "/data/data/com.termux" ]; then
    echo "❌ This script must be run in Termux on Android!"
    echo "Please install Termux first and run the setup script."
    exit 1
fi

# Check if Ollama is running
if ! pgrep -f "ollama serve" > /dev/null; then
    echo "🔄 Starting Ollama server..."
    proot-distro login debian -- tmux new-session -d -s ollama 'ollama serve'
    echo "⏳ Waiting for server to start..."
    sleep 5
    echo "✅ Ollama server started!"
else
    echo "✅ Ollama server is already running!"
fi

echo ""
echo "🚀 Starting DeepSeek R1..."
echo "💡 Tips:"
echo "   - Type your questions and press Enter"
echo "   - Use Ctrl+C to stop the model"
echo "   - Use Ctrl+D to exit"
echo "   - The model will remember conversation context"
echo ""

# Run DeepSeek R1
proot-distro login debian -- ollama run deepseek-r1:1.5b
