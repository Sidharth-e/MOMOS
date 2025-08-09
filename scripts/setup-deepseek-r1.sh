#!/bin/bash

# MOMOS - DeepSeek R1 Setup Script for Termux
# This script automates the complete setup process for running DeepSeek R1 locally on Android devices

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running in Termux
check_termux() {
    if [ ! -d "/data/data/com.termux" ]; then
        print_error "This script must be run in Termux on Android!"
        print_error "Please install Termux first and then run this script."
        exit 1
    fi
    print_success "Termux environment detected"
}

# Function to check system requirements
check_requirements() {
    print_status "Checking system requirements..."
    
    # Check available storage (minimum 12GB)
    available_storage=$(df /data | awk 'NR==2 {print $4}')
    available_storage_gb=$((available_storage / 1024 / 1024))
    
    if [ $available_storage_gb -lt 12 ]; then
        print_warning "Available storage: ${available_storage_gb}GB"
        print_warning "Recommended: At least 12GB free space"
        print_warning "You may experience issues with larger models"
    else
        print_success "Available storage: ${available_storage_gb}GB ✓"
    fi
    
    # Check available RAM
    total_ram=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')
    total_ram_gb=$((total_ram / 1024 / 1024))
    
    if [ $total_ram_gb -lt 8 ]; then
        print_warning "Total RAM: ${total_ram_gb}GB"
        print_warning "Recommended: At least 8GB RAM"
        print_warning "Performance may be limited"
    else
        print_success "Total RAM: ${total_ram_gb}GB ✓"
    fi
}

# Function to setup Termux repository
setup_termux_repo() {
    print_status "Setting up Termux repository..."
    
    if ! command -v termux-change-repo &> /dev/null; then
        print_error "termux-change-repo command not found"
        print_error "Please ensure you have the latest version of Termux installed"
        exit 1
    fi
    
    # Change repository to main
    termux-change-repo
    
    print_success "Termux repository configured"
}

# Function to update Termux packages
update_termux() {
    print_status "Updating Termux packages..."
    
    print_status "Running: apt update && apt upgrade -y"
    apt update && apt upgrade -y
    
    print_success "Termux packages updated"
}

# Function to install Proot-Distro and Debian
install_debian() {
    print_status "Installing Proot-Distro and Debian..."
    
    # Install proot-distro
    print_status "Installing proot-distro..."
    pkg install proot-distro -y
    
    # Install Debian
    print_status "Installing Debian..."
    proot-distro install debian
    
    print_success "Debian installed successfully"
}

# Function to setup Debian environment
setup_debian() {
    print_status "Setting up Debian environment..."
    
    # Create a setup script for Debian
    cat > /tmp/debian_setup.sh << 'EOF'
#!/bin/bash
set -e

echo "Updating Debian packages..."
apt update && apt upgrade -y

echo "Installing TMUX..."
apt install tmux -y

echo "Installing Ollama..."
curl -fsSL https://ollama.ai/install.sh | sh

echo "Debian setup completed successfully!"
EOF
    
    # Make script executable and run it in Debian
    chmod +x /tmp/debian_setup.sh
    proot-distro login debian -- bash /tmp/debian_setup.sh
    
    print_success "Debian environment configured"
}

# Function to install and run DeepSeek R1
install_deepseek() {
    print_status "Installing DeepSeek R1..."
    
    # Create a script to run in Debian
    cat > /tmp/install_deepseek.sh << 'EOF'
#!/bin/bash
set -e

echo "Starting Ollama server in TMUX..."
tmux new-session -d -s ollama 'ollama serve'

echo "Waiting for Ollama server to start..."
sleep 5

echo "Installing DeepSeek R1 1.5B model..."
ollama pull deepseek-r1:1.5b

echo "DeepSeek R1 installation completed!"
echo ""
echo "To run DeepSeek R1:"
echo "1. Open new TMUX session: tmux new-session -s deepseek"
echo "2. Run the model: ollama run deepseek-r1:1.5b"
echo "3. Use Ctrl+C to stop, Ctrl+D to exit"
echo ""
echo "TMUX shortcuts:"
echo "- Ctrl+B then % : Split vertically"
echo "- Ctrl+B then \" : Split horizontally"
echo "- Ctrl+B then arrow keys : Navigate between panes"
echo "- Ctrl+B then d : Detach session"
echo "- tmux attach -t ollama : Reattach to Ollama session"
EOF
    
    # Make script executable and run it in Debian
    chmod +x /tmp/install_deepseek.sh
    proot-distro login debian -- bash /tmp/install_deepseek.sh
    
    print_success "DeepSeek R1 installed successfully"
}

# Function to create usage script
create_usage_script() {
    print_status "Creating usage script..."
    
    cat > /data/data/com.termux/files/home/run-deepseek.sh << 'EOF'
#!/bin/bash

echo "=== DeepSeek R1 Local Runner ==="
echo ""

# Check if Ollama is running
if ! pgrep -f "ollama serve" > /dev/null; then
    echo "Starting Ollama server..."
    proot-distro login debian -- tmux new-session -d -s ollama 'ollama serve'
    sleep 3
fi

echo "Starting DeepSeek R1..."
echo "Use Ctrl+C to stop the model"
echo "Use Ctrl+D to exit"
echo ""

# Run DeepSeek R1
proot-distro login debian -- ollama run deepseek-r1:1.5b
EOF
    
    chmod +x /data/data/com.termux/files/home/run-deepseek.sh
    
    print_success "Usage script created: ~/run-deepseek.sh"
}

# Function to display final instructions
show_final_instructions() {
    echo ""
    echo "=========================================="
    echo "🎉 DeepSeek R1 Setup Completed! 🎉"
    echo "=========================================="
    echo ""
    echo "📱 To run DeepSeek R1 locally:"
    echo "   ./run-deepseek.sh"
    echo ""
    echo "🔧 Manual commands:"
    echo "   # Start Ollama server:"
    echo "   proot-distro login debian -- tmux new-session -d -s ollama 'ollama serve'"
    echo ""
    echo "   # Run DeepSeek R1:"
    echo "   proot-distro login debian -- ollama run deepseek-r1:1.5b"
    echo ""
    echo "📚 Available models:"
    echo "   - deepseek-r1:1.5b (1.1GB) - Recommended for most devices"
    echo "   - deepseek-r1:7b (4.4GB) - Better performance, requires more resources"
    echo "   - deepseek-r1:8b (4.9GB) - High-end devices only"
    echo ""
    echo "💡 Tips:"
    echo "   - Use TMUX to keep sessions running in background"
    echo "   - Monitor system resources while running models"
    echo "   - Close other apps to free up memory"
    echo ""
    echo "🚀 Happy AI chatting!"
    echo ""
}

# Main execution
main() {
    echo "=========================================="
    echo "🤖 MOMOS - DeepSeek R1 Setup Script"
    echo "=========================================="
    echo ""
    
    print_status "Starting DeepSeek R1 setup process..."
    
    # Check environment
    check_termux
    check_requirements
    
    # Setup process
    setup_termux_repo
    update_termux
    install_debian
    setup_debian
    install_deepseek
    create_usage_script
    
    # Show final instructions
    show_final_instructions
}

# Run main function
main "$@"
