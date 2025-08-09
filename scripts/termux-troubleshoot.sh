#!/bin/bash

# MOMOS - Termux Troubleshooting Script for DeepSeek R1
# This script helps diagnose and fix common issues

set -e

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

echo "=========================================="
echo "🔧 MOMOS - Termux Troubleshooting Script"
echo "=========================================="
echo ""

# Check if running in Termux
if [ ! -d "/data/data/com.termux" ]; then
    print_error "This script must be run in Termux on Android!"
    print_error "Please install Termux first and then run this script."
    exit 1
fi

print_success "Termux environment detected"

# Function to check system resources
check_system_resources() {
    print_status "Checking system resources..."
    
    # Check available storage
    available_storage=$(df /data | awk 'NR==2 {print $4}')
    available_storage_gb=$((available_storage / 1024 / 1024))
    
    echo "📱 Available storage: ${available_storage_gb}GB"
    if [ $available_storage_gb -lt 12 ]; then
        print_warning "Low storage! You need at least 12GB for DeepSeek R1"
        print_warning "Consider freeing up space or using external storage"
    else
        print_success "Storage space is sufficient ✓"
    fi
    
    # Check available RAM
    total_ram=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')
    total_ram_gb=$((total_ram / 1024 / 1024))
    
    echo "💾 Total RAM: ${total_ram_gb}GB"
    if [ $total_ram_gb -lt 8 ]; then
        print_warning "Low RAM! You need at least 8GB for optimal performance"
        print_warning "Consider closing other apps or using only the 1.5B model"
    else
        print_success "RAM is sufficient ✓"
    fi
    
    # Check CPU info
    if [ -f "/proc/cpuinfo" ]; then
        cpu_model=$(grep "Hardware" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        echo "🖥️  CPU: $cpu_model"
        
        if [[ "$cpu_model" == *"Snapdragon 8 Gen 2"* ]] || [[ "$cpu_model" == *"Snapdragon 8 Gen 3"* ]]; then
            print_success "High-end processor detected ✓"
        elif [[ "$cpu_model" == *"Snapdragon"* ]]; then
            print_warning "Mid-range processor - performance may vary"
        else
            print_warning "Unknown processor - performance may be limited"
        fi
    fi
}

# Function to check Termux setup
check_termux_setup() {
    print_status "Checking Termux setup..."
    
    # Check if proot-distro is installed
    if command -v proot-distro &> /dev/null; then
        print_success "proot-distro is installed ✓"
    else
        print_error "proot-distro is not installed!"
        echo "Run: pkg install proot-distro -y"
        return 1
    fi
    
    # Check if Debian is installed
    if proot-distro list | grep -q "debian"; then
        print_success "Debian is installed ✓"
    else
        print_error "Debian is not installed!"
        echo "Run: proot-distro install debian"
        return 1
    fi
    
    # Check if Ollama is installed in Debian
    if proot-distro login debian -- command -v ollama &> /dev/null; then
        print_success "Ollama is installed in Debian ✓"
    else
        print_error "Ollama is not installed in Debian!"
        echo "Run the setup script again or install manually:"
        echo "proot-distro login debian"
        echo "curl -fsSL https://ollama.ai/install.sh | sh"
        return 1
    fi
}

# Function to check DeepSeek R1 installation
check_deepseek_installation() {
    print_status "Checking DeepSeek R1 installation..."
    
    # Check if model is downloaded
    if proot-distro login debian -- ollama list | grep -q "deepseek-r1:1.5b"; then
        print_success "DeepSeek R1 1.5B model is installed ✓"
        
        # Get model size
        model_size=$(proot-distro login debian -- ollama list | grep "deepseek-r1:1.5b" | awk '{print $3}')
        echo "📦 Model size: $model_size"
    else
        print_warning "DeepSeek R1 model is not installed"
        echo "To install: ollama pull deepseek-r1:1.5b"
        return 1
    fi
}

# Function to check Ollama server
check_ollama_server() {
    print_status "Checking Ollama server status..."
    
    if pgrep -f "ollama serve" > /dev/null; then
        print_success "Ollama server is running ✓"
        
        # Check if server is responding
        if proot-distro login debian -- timeout 5 ollama list &> /dev/null; then
            print_success "Ollama server is responding ✓"
        else
            print_warning "Ollama server is running but not responding"
            echo "Try restarting: killall ollama && tmux new-session -d -s ollama 'ollama serve'"
        fi
    else
        print_warning "Ollama server is not running"
        echo "To start: tmux new-session -d -s ollama 'ollama serve'"
        return 1
    fi
}

# Function to check network connectivity
check_network() {
    print_status "Checking network connectivity..."
    
    if ping -c 1 8.8.8.8 &> /dev/null; then
        print_success "Internet connection is working ✓"
    else
        print_error "No internet connection!"
        echo "Please check your WiFi or mobile data connection"
        return 1
    fi
    
    # Check if we can reach Ollama.ai
    if curl -s --max-time 10 https://ollama.ai &> /dev/null; then
        print_success "Can reach Ollama.ai ✓"
    else
        print_warning "Cannot reach Ollama.ai - may affect model downloads"
    fi
}

# Function to check TMUX installation
check_tmux() {
    print_status "Checking TMUX installation..."
    
    if proot-distro login debian -- command -v tmux &> /dev/null; then
        print_success "TMUX is installed in Debian ✓"
    else
        print_warning "TMUX is not installed in Debian"
        echo "To install: proot-distro login debian -- apt install tmux -y"
        return 1
    fi
}

# Function to provide fixes
provide_fixes() {
    echo ""
    echo "=========================================="
    echo "🔧 Common Fixes"
    echo "=========================================="
    
    if ! command -v proot-distro &> /dev/null; then
        echo "1. Install proot-distro:"
        echo "   pkg install proot-distro -y"
        echo ""
    fi
    
    if ! proot-distro list | grep -q "debian"; then
        echo "2. Install Debian:"
        echo "   proot-distro install debian"
        echo ""
    fi
    
    if ! proot-distro login debian -- command -v ollama &> /dev/null; then
        echo "3. Install Ollama in Debian:"
        echo "   proot-distro login debian"
        echo "   curl -fsSL https://ollama.ai/install.sh | sh"
        echo ""
    fi
    
    if ! proot-distro login debian -- command -v tmux &> /dev/null; then
        echo "4. Install TMUX in Debian:"
        echo "   proot-distro login debian -- apt install tmux -y"
        echo ""
    fi
    
    if ! pgrep -f "ollama serve" > /dev/null; then
        echo "5. Start Ollama server:"
        echo "   proot-distro login debian -- tmux new-session -d -s ollama 'ollama serve'"
        echo ""
    fi
    
    if ! proot-distro login debian -- ollama list | grep -q "deepseek-r1:1.5b"; then
        echo "6. Install DeepSeek R1 model:"
        echo "   proot-distro login debian -- ollama pull deepseek-r1:1.5b"
        echo ""
    fi
    
    echo "7. If you're still having issues, try:"
    echo "   - Restart Termux completely"
    echo "   - Check Android permissions for Termux"
    echo "   - Ensure you have enough storage and RAM"
    echo "   - Run the setup script again: ./scripts/setup-deepseek-r1.sh"
}

# Function to run basic tests
run_basic_tests() {
    echo ""
    echo "=========================================="
    echo "🧪 Running Basic Tests"
    echo "=========================================="
    
    # Test Debian access
    print_status "Testing Debian access..."
    if proot-distro login debian -- echo "Debian access test" &> /dev/null; then
        print_success "Debian access working ✓"
    else
        print_error "Cannot access Debian environment"
        return 1
    fi
    
    # Test Ollama command
    print_status "Testing Ollama command..."
    if proot-distro login debian -- ollama --version &> /dev/null; then
        print_success "Ollama command working ✓"
    else
        print_error "Ollama command not working"
        return 1
    fi
    
    # Test TMUX
    print_status "Testing TMUX..."
    if proot-distro login debian -- tmux -V &> /dev/null; then
        print_success "TMUX working ✓"
    else
        print_error "TMUX not working"
        return 1
    fi
}

# Main troubleshooting function
main() {
    print_status "Starting comprehensive troubleshooting..."
    
    # Run all checks
    check_system_resources
    echo ""
    
    check_termux_setup
    echo ""
    
    check_deepseek_installation
    echo ""
    
    check_ollama_server
    echo ""
    
    check_network
    echo ""
    
    check_tmux
    echo ""
    
    run_basic_tests
    echo ""
    
    # Provide fixes
    provide_fixes
    
    echo ""
    echo "=========================================="
    echo "📋 Summary"
    echo "=========================================="
    echo "If all checks passed, you should be able to run:"
    echo "  ./run-deepseek.sh"
    echo ""
    echo "If you have issues, try the fixes above or run:"
    echo "  ./scripts/setup-deepseek-r1.sh"
    echo ""
    echo "For additional help, check the README-DEEPSEEK-R1.md file"
}

# Run main function
main "$@"
