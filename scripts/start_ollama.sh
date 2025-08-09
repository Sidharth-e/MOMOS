#!/data/data/com.termux/files/usr/bin/bash

# Ollama Server Startup Script for Termux
# This script ensures the Ollama server starts properly in a TMUX session

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Unicode characters
CHECK_MARK="✓"
CROSS_MARK="✗"
ARROW="→"
STAR="★"
GEAR="⚙️"

# Function to print colored text
print_status() {
    local status=$1
    local message=$2
    case $status in
        "info") echo -e "${BLUE}${ARROW}${NC} ${message}" ;;
        "success") echo -e "${GREEN}${CHECK_MARK}${NC} ${message}" ;;
        "warning") echo -e "${YELLOW}${STAR}${NC} ${message}" ;;
        "error") echo -e "${RED}${CROSS_MARK}${NC} ${message}" ;;
        "step") echo -e "${CYAN}${GEAR}${NC} ${message}" ;;
    esac
}

# Function to check if running in Termux
check_termux() {
    if [ ! -d "/data/data/com.termux" ]; then
        echo -e "${RED}${CROSS_MARK} This script is designed for Termux on Android.${NC}"
        exit 1
    fi
}

# Function to check if proot-distro is available
check_proot_distro() {
    if ! command -v proot-distro &> /dev/null; then
        print_status "error" "proot-distro not found. Please install it first:"
        echo -e "${CYAN}  pkg install proot-distro -y${NC}"
        exit 1
    fi
    print_status "success" "proot-distro found"
}

# Function to check if Debian is available
check_debian() {
    if ! proot-distro list | grep -q "debian"; then
        print_status "error" "Debian not found. Please install it first:"
        echo -e "${CYAN}  proot-distro install debian${NC}"
        exit 1
    fi
    print_status "success" "Debian found"
}

# Function to check if Ollama is installed in Debian
check_ollama() {
    if ! proot-distro login debian -- bash -c "command -v ollama &> /dev/null"; then
        print_status "error" "Ollama not found in Debian. Please install it first:"
        echo -e "${CYAN}  proot-distro login debian -- bash -c 'curl -fsSL https://ollama.ai/install.sh | sh'${NC}"
        exit 1
    fi
    print_status "success" "Ollama found in Debian"
}

# Function to check if TMUX is installed in Debian
check_tmux() {
    if ! proot-distro login debian -- bash -c "command -v tmux &> /dev/null"; then
        print_status "error" "TMUX not found in Debian. Please install it first:"
        echo -e "${CYAN}  proot-distro login debian -- bash -c 'apt update && apt install tmux -y'${NC}"
        exit 1
    fi
    print_status "success" "TMUX found in Debian"
}

# Function to check if Ollama server is already running
check_server_running() {
    if proot-distro login debian -- bash -c "ss -tuln 2>/dev/null | grep -q ':11434'" 2>/dev/null; then
        print_status "success" "Ollama server is already running on port 11434"
        return 0
    else
        print_status "info" "Ollama server is not running"
        return 1
    fi
}

# Function to start Ollama server
start_ollama_server() {
    print_status "step" "Starting Ollama server..."
    
    # Kill any existing TMUX session
    print_status "info" "Cleaning up any existing TMUX sessions..."
    proot-distro login debian -- bash -c "tmux kill-session -t ollama_server 2>/dev/null || true"
    sleep 3
    
    # Create new TMUX session
    print_status "info" "Creating new TMUX session for Ollama server..."
    
    if proot-distro login debian -- bash -c "
        # Create new TMUX session with Ollama server
        if tmux new-session -d -s ollama_server 'ollama serve'; then
            echo 'TMUX session created successfully'
            # Wait for session to be fully created
            sleep 3
            # Verify session exists
            if tmux has-session -t ollama_server 2>/dev/null; then
                echo 'Session verified successfully'
                exit 0
            else
                echo 'Session verification failed'
                exit 1
            fi
        else
            echo 'Failed to create TMUX session'
            exit 1
        fi
    "; then
        print_status "success" "TMUX session created successfully"
    else
        print_status "error" "Failed to create TMUX session"
        return 1
    fi
    
    # Wait for Ollama to start and listen on port 11434
    print_status "info" "Waiting for Ollama server to start (max 30 seconds)..."
    
    for i in $(seq 1 30); do
        if proot-distro login debian -- bash -c "ss -tuln 2>/dev/null | grep -q ':11434'" 2>/dev/null; then
            print_status "success" "Ollama server started successfully!"
            print_status "info" "Server is listening on port 11434"
            return 0
        fi
        
        # Show progress
        printf "\r${CYAN}Waiting for server... ${i}/30${NC}"
        sleep 1
    done
    
    echo ""  # New line after progress
    print_status "error" "Ollama server failed to start within 30 seconds"
    return 1
}

# Function to show server status
show_server_status() {
    print_status "step" "Checking server status..."
    
    # Check TMUX session
    if proot-distro login debian -- bash -c "tmux has-session -t ollama_server 2>/dev/null"; then
        print_status "success" "TMUX session 'ollama_server' exists"
        
        # Check if Ollama is listening
        if proot-distro login debian -- bash -c "ss -tuln 2>/dev/null | grep -q ':11434'" 2>/dev/null; then
            print_status "success" "Ollama server is listening on port 11434"
        else
            print_status "warning" "TMUX session exists but Ollama is not listening"
        fi
        
        # Show session info
        echo ""
        echo -e "${WHITE}TMUX Session Information:${NC}"
        proot-distro login debian -- bash -c "tmux list-sessions | grep ollama_server"
        
    else
        print_status "warning" "No TMUX session 'ollama_server' found"
    fi
    
    # Check port status
    echo ""
    echo -e "${WHITE}Port Status:${NC}"
    if proot-distro login debian -- bash -c "ss -tuln 2>/dev/null | grep ':11434'" 2>/dev/null; then
        print_status "success" "Port 11434 is open and listening"
    else
        print_status "warning" "Port 11434 is not listening"
    fi
}

# Function to attach to server session
attach_to_session() {
    print_status "step" "Attaching to Ollama server session..."
    
    if proot-distro login debian -- bash -c "tmux has-session -t ollama_server 2>/dev/null"; then
        print_status "info" "Attaching to session 'ollama_server'..."
        print_status "info" "Press CTRL+B then D to detach and return"
        echo ""
        proot-distro login debian -- bash -c "tmux attach-session -t ollama_server"
    else
        print_status "error" "No TMUX session 'ollama_server' found"
        print_status "info" "Start the server first with: bash scripts/start_ollama.sh"
    fi
}

# Function to stop server
stop_server() {
    print_status "step" "Stopping Ollama server..."
    
    if proot-distro login debian -- bash -c "tmux has-session -t ollama_server 2>/dev/null"; then
        proot-distro login debian -- bash -c "tmux kill-session -t ollama_server"
        print_status "success" "Ollama server stopped"
    else
        print_status "warning" "No TMUX session 'ollama_server' found"
    fi
}

# Function to restart server
restart_server() {
    print_status "step" "Restarting Ollama server..."
    stop_server
    sleep 2
    start_ollama_server
}

# Function to show help
show_help() {
    echo -e "${CYAN}Ollama Server Management Script${NC}"
    echo ""
    echo -e "${WHITE}Usage:${NC} bash scripts/start_ollama.sh [OPTION]"
    echo ""
    echo -e "${WHITE}Options:${NC}"
    echo -e "${CYAN}  start${NC}     - Start the Ollama server (default)"
    echo -e "${CYAN}  stop${NC}      - Stop the Ollama server"
    echo -e "${CYAN}  restart${NC}   - Restart the Ollama server"
    echo -e "${CYAN}  status${NC}    - Show server status"
    echo -e "${CYAN}  attach${NC}    - Attach to server session"
    echo -e "${CYAN}  help${NC}      - Show this help message"
    echo ""
    echo -e "${WHITE}Examples:${NC}"
    echo -e "${CYAN}  bash scripts/start_ollama.sh${NC}        # Start server"
    echo -e "${CYAN}  bash scripts/start_ollama.sh status${NC} # Check status"
    echo -e "${CYAN}  bash scripts/start_ollama.sh attach${NC} # Attach to session"
}

# Main function
main() {
    local action=${1:-start}
    
    case $action in
        "start")
            check_termux
            check_proot_distro
            check_debian
            check_ollama
            check_tmux
            
            if check_server_running; then
                print_status "info" "Server is already running"
                show_server_status
            else
                start_ollama_server
                if [ $? -eq 0 ]; then
                    show_server_status
                fi
            fi
            ;;
        "stop")
            check_termux
            check_proot_distro
            check_debian
            stop_server
            ;;
        "restart")
            check_termux
            check_proot_distro
            check_debian
            check_ollama
            check_tmux
            restart_server
            ;;
        "status")
            check_termux
            check_proot_distro
            check_debian
            show_server_status
            ;;
        "attach")
            check_termux
            check_proot_distro
            check_debian
            attach_to_session
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_status "error" "Unknown option: $action"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
