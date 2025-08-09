#!/data/data/com.termux/files/usr/bin/bash

# DeepSeek R1 Launcher Script for Termux
# Beautiful launcher interface with multiple options
# Run this after successful installation

set -e

# Color definitions for modern UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Unicode characters for modern UI
CHECK_MARK="✓"
CROSS_MARK="✗"
ARROW="→"
STAR="★"
ROCKET="🚀"
GEAR="⚙️"
DOWNLOAD="📥"
SUCCESS="🎉"
WAITING="⏳"
BRAIN="🧠"
CHAT="💬"
SETTINGS="🔧"
EXIT="🚪"
MODEL="🤖"

# Default model
CURRENT_MODEL="deepseek-r1:1.5b"

# Function to print colored text
print_status() {
    local status=$1
    local message=$2
    case $status in
        "info") echo -e "${BLUE}${ARROW}${NC} ${message}" ;;
        "success") echo -e "${GREEN}${CHECK_MARK}${NC} ${message}" ;;
        "warning") echo -e "${YELLOW}${STAR}${NC} ${message}" ;;
        "error") echo -e "${RED}${CROSS_MARK}${NC} ${message}" ;;
        "step") echo -e "${PURPLE}${GEAR}${NC} ${message}" ;;
        "download") echo -e "${CYAN}${DOWNLOAD}${NC} ${message}" ;;
    esac
}

# Function to print header
print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${WHITE}DeepSeek R1 Launcher${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}              ${YELLOW}Your Local AI Assistant${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Current Model: ${CYAN}${CURRENT_MODEL}${NC}"
    echo ""
}

# Function to check if Debian and Ollama are available
check_installation() {
    print_status "step" "Checking installation status..."
    
    # Check for proot-distro with multiple methods
    local proot_found=false
    
    # Method 1: Check if command exists
    if command -v proot-distro &> /dev/null; then
        proot_found=true
        print_status "success" "PRoot-Distro found via command -v"
    fi
    
    # Method 2: Check common paths
    if [ ! "$proot_found" = true ]; then
        for path in "/data/data/com.termux/files/usr/bin/proot-distro" "/usr/bin/proot-distro" "$HOME/.local/bin/proot-distro"; do
            if [ -f "$path" ]; then
                proot_found=true
                print_status "success" "PRoot-Distro found at: $path"
                break
            fi
        done
    fi
    
    # Method 3: Check if we can run it
    if [ ! "$proot_found" = true ]; then
        if proot-distro --help &> /dev/null; then
            proot_found=true
            print_status "success" "PRoot-Distro found via execution test"
        fi
    fi
    
    if [ ! "$proot_found" = true ]; then
        print_status "error" "PRoot-Distro not found. Please run the installation script first."
        echo ""
        echo -e "${YELLOW}Troubleshooting:${NC}"
        echo -e "${CYAN}1.${NC} Run: ${WHITE}pkg install proot-distro -y${NC}"
        echo -e "${CYAN}2.${NC} Run: ${WHITE}bash scripts/install_deepseek.sh${NC}"
        echo -e "${CYAN}3.${NC} Check if Termux packages are updated: ${WHITE}pkg update${NC}"
        return 1
    fi
    
    # Check if Debian is installed
    print_status "step" "Checking Debian installation..."
    
    # Try to list distributions
    local debian_found=false
    
    # Method 1: Check if proot-distro list works
    if proot-distro list &> /dev/null; then
        if proot-distro list | grep -q "debian"; then
            debian_found=true
            print_status "success" "Debian found via proot-distro list"
        fi
    fi
    
    # Method 2: Check if we can access Debian directly
    if [ ! "$debian_found" = true ]; then
        if proot-distro login debian --shared-tmp -- bash -c "echo 'Debian access test'" &> /dev/null; then
            debian_found=true
            print_status "success" "Debian found via direct access test"
        fi
    fi
    
    # Method 3: Check common Debian paths
    if [ ! "$debian_found" = true ]; then
        for path in "/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/debian" "$HOME/.local/share/proot-distro/installed-rootfs/debian"; do
            if [ -d "$path" ]; then
                debian_found=true
                print_status "success" "Debian found at: $path"
                break
            fi
        done
    fi
    
    if [ ! "$debian_found" = true ]; then
        print_status "error" "Debian not found. Please install it first."
        echo ""
        echo -e "${YELLOW}Options to install Debian:${NC}"
        echo -e "${CYAN}1.${NC} Run the full installation script: ${WHITE}bash scripts/install_deepseek.sh${NC}"
        echo -e "${CYAN}2.${NC} Install Debian manually: ${WHITE}proot-distro install debian${NC}"
        echo -e "${CYAN}3.${NC} Check available distributions: ${WHITE}proot-distro list${NC}"
        echo ""
        
        # Offer to install Debian automatically
        read -p "$(echo -e "${YELLOW}Would you like to install Debian now? (y/N): ${NC}")" -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "step" "Installing Debian..."
            print_status "info" "This may take several minutes..."
            
            if proot-distro install debian; then
                print_status "success" "Debian installed successfully!"
                debian_found=true
            else
                print_status "error" "Failed to install Debian automatically."
                echo -e "${YELLOW}Please try: ${WHITE}proot-distro install debian${NC}"
                return 1
            fi
        else
            return 1
        fi
    fi
    
    # Check if Ollama is available in Debian
    print_status "step" "Checking Ollama installation..."
    if proot-distro login debian --shared-tmp -- bash -c "command -v ollama &> /dev/null"; then
        print_status "success" "Ollama found in Debian!"
    else
        print_status "warning" "Ollama not found in Debian. Installing now..."
        
        if proot-distro login debian --shared-tmp -- bash -c "
            apt update > /dev/null 2>&1
            apt install curl -y > /dev/null 2>&1
            curl -fsSL https://ollama.ai/install.sh | sh > /dev/null 2>&1
        "; then
            print_status "success" "Ollama installed successfully!"
        else
            print_status "error" "Failed to install Ollama automatically."
            echo -e "${YELLOW}Please run the installation script: ${WHITE}bash scripts/install_deepseek.sh${NC}"
            return 1
        fi
    fi
    
    print_status "success" "Installation check passed!"
    return 0
}

# Function to start Ollama server
start_ollama_server() {
    print_status "step" "Starting Ollama server..."
    
    # Check if server is already running
    if proot-distro login debian --shared-tmp -- bash -c "tmux has-session -t ollama_server 2>/dev/null"; then
        print_status "success" "Ollama server is already running!"
        print_status "info" "You can attach to it with: tmux attach-session -t ollama_server"
        print_status "info" "Press CTRL+B then D to detach and leave it running"
    else
        print_status "info" "Starting Ollama server in background TMUX session..."
        proot-distro login debian --shared-tmp -- bash -c "
            tmux new-session -d -s ollama_server 'ollama serve'
        "
        
        # Wait a moment for server to start
        sleep 2
        
        # Verify server started successfully
        if proot-distro login debian --shared-tmp -- bash -c "tmux has-session -t ollama_server 2>/dev/null"; then
            print_status "success" "Ollama server started successfully in TMUX session!"
            print_status "info" "Session name: ollama_server"
            print_status "info" "To attach: tmux attach-session -t ollama_server"
            print_status "info" "To detach: Press CTRL+B then D"
        else
            print_status "error" "Failed to start Ollama server!"
            return 1
        fi
    fi
}

# Function to check and ensure Ollama server is running
ensure_ollama_server() {
    print_status "step" "Ensuring Ollama server is running..."
    
    # Check if server is running
    if proot-distro login debian --shared-tmp -- bash -c "tmux has-session -t ollama_server 2>/dev/null"; then
        print_status "success" "Ollama server is already running!"
        return 0
    else
        print_status "warning" "Ollama server not running. Starting it now..."
        start_ollama_server
        return $?
    fi
}

# Function to run selected model
run_model() {
    print_status "step" "Launching ${CURRENT_MODEL}..."
    echo ""
    print_status "info" "Starting interactive chat session..."
    print_status "info" "Type 'exit' to return to the launcher"
    echo ""
    
    proot-distro login debian --shared-tmp -- bash -c "
        echo '${GREEN}${BRAIN} ${CURRENT_MODEL} is ready! Start chatting below:${NC}'
        echo '${YELLOW}${STAR} Model: ${CURRENT_MODEL}${NC}'
        echo '${CYAN}${CHAT} Type your message and press Enter:${NC}'
        echo ''
        ollama run ${CURRENT_MODEL}
    "
}

# Function to check model status
check_model_status() {
    print_status "step" "Checking ${CURRENT_MODEL} status..."
    
    if proot-distro login debian --shared-tmp -- bash -c "ollama list | grep -q '${CURRENT_MODEL}'"; then
        print_status "success" "${CURRENT_MODEL} is available!"
        
        # Get model size
        local model_size=$(proot-distro login debian --shared-tmp -- bash -c "ollama list | grep '${CURRENT_MODEL}' | awk '{print \$3}'")
        print_status "info" "Model size: ${model_size}"
    else
        print_status "warning" "${CURRENT_MODEL} not found. Downloading now..."
        proot-distro login debian --shared-tmp -- bash -c "ollama pull ${CURRENT_MODEL}"
        print_status "success" "Model downloaded successfully!"
    fi
}

# Function to show available models
show_available_models() {
    print_status "step" "Available models in Ollama library:"
    echo ""
    
    # Popular model suggestions
    echo -e "${WHITE}Popular Models:${NC}"
    echo -e "${CYAN}1.${NC} ${WHITE}deepseek-r1:1.5b${NC} (Fast, lightweight)"
    echo -e "${CYAN}2.${NC} ${WHITE}deepseek-r1:8b${NC} (Balanced performance)"
    echo -e "${CYAN}3.${NC} ${WHITE}deepseek-r1:14b${NC} (High quality, more RAM)"
    echo -e "${CYAN}4.${NC} ${WHITE}deepseek-r1:32b${NC} (Best quality, high RAM)"
    echo -e "${CYAN}5.${NC} ${WHITE}deepseek-r1:70b${NC} (Ultra quality, very high RAM)"
    echo ""
    echo -e "${WHITE}Other Popular Models:${NC}"
    echo -e "${CYAN}6.${NC} ${WHITE}llama3:8b${NC} (Meta's Llama 3)"
    echo -e "${CYAN}7.${NC} ${WHITE}llama3:70b${NC} (Meta's Llama 3 large)"
    echo -e "${CYAN}8.${NC} ${WHITE}mistral:7b${NC} (Mistral AI model)"
    echo -e "${CYAN}9.${NC} ${WHITE}codellama:7b${NC} (Code-focused model)"
    echo -e "${CYAN}10.${NC} ${WHITE}custom${NC} (Enter custom model name)"
    echo ""
}

# Function to select and download model
select_model() {
    while true; do
        clear
        print_header
        show_available_models
        
        read -p "$(echo -e "${YELLOW}Enter your choice (1-10): ${NC}")" choice
        
        case $choice in
            1) CURRENT_MODEL="deepseek-r1:1.5b" ;;
            2) CURRENT_MODEL="deepseek-r1:8b" ;;
            3) CURRENT_MODEL="deepseek-r1:14b" ;;
            4) CURRENT_MODEL="deepseek-r1:32b" ;;
            5) CURRENT_MODEL="deepseek-r1:70b" ;;
            6) CURRENT_MODEL="llama3:8b" ;;
            7) CURRENT_MODEL="llama3:70b" ;;
            8) CURRENT_MODEL="mistral:7b" ;;
            9) CURRENT_MODEL="codellama:7b" ;;
            10)
                read -p "$(echo -e "${YELLOW}Enter custom model name (e.g., llama3:13b): ${NC}")" custom_model
                if [ ! -z "$custom_model" ]; then
                    CURRENT_MODEL="$custom_model"
                fi
                ;;
            *)
                print_status "error" "Invalid choice. Please try again."
                sleep 2
                continue
                ;;
        esac
        
        # Confirm model selection
        echo ""
        print_status "info" "Selected model: ${CYAN}${CURRENT_MODEL}${NC}"
        read -p "$(echo -e "${YELLOW}Do you want to download this model? (y/N): ${NC}")" -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "download" "Downloading ${CURRENT_MODEL}..."
            
            # Show download progress
            proot-distro login debian --shared-tmp -- bash -c "
                echo '${CYAN}${DOWNLOAD} Downloading ${CURRENT_MODEL}...${NC}'
                echo '${YELLOW}${STAR} This may take several minutes depending on model size and internet speed${NC}'
                echo ''
                ollama pull ${CURRENT_MODEL}
                echo '${GREEN}${CHECK_MARK} Download complete!${NC}'
            "
            
            print_status "success" "${CURRENT_MODEL} downloaded successfully!"
            read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")"
            break
        else
            print_status "info" "Model selection cancelled."
            sleep 2
        fi
    done
}

# Function to manage installed models
manage_models() {
    while true; do
        clear
        print_header
        echo -e "${PURPLE}╭─ Model Management${NC}"
        echo -e "${PURPLE}╰─ Choose an option:${NC}"
        echo ""
        echo -e "${CYAN}1.${NC} ${WHITE}List installed models${NC}"
        echo -e "${CYAN}2.${NC} ${WHITE}Remove a model${NC}"
        echo -e "${CYAN}3.${NC} ${WHITE}Show model info${NC}"
        echo -e "${CYAN}4.${NC} ${WHITE}Back to main menu${NC}"
        echo ""
        
        read -p "$(echo -e "${YELLOW}Enter your choice (1-4): ${NC}")" choice
        
        case $choice in
            1)
                print_status "step" "Installed models:"
                proot-distro login debian --shared-tmp -- bash -c "ollama list"
                echo ""
                read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")"
                ;;
            2)
                print_status "step" "Installed models:"
                proot-distro login debian --shared-tmp -- bash -c "ollama list"
                echo ""
                read -p "$(echo -e "${YELLOW}Enter model name to remove: ${NC}")" model_to_remove
                if [ ! -z "$model_to_remove" ]; then
                    print_status "step" "Removing ${model_to_remove}..."
                    proot-distro login debian --shared-tmp -- bash -c "ollama rm ${model_to_remove}"
                    print_status "success" "Model removed successfully!"
                fi
                read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")"
                ;;
            3)
                print_status "step" "Model information:"
                proot-distro login debian --shared-tmp -- bash -c "ollama show ${CURRENT_MODEL}"
                echo ""
                read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")"
                ;;
            4)
                break
                ;;
            *)
                print_status "error" "Invalid choice. Please try again."
                sleep 2
                ;;
        esac
    done
}

# Function to manage Ollama server
manage_server() {
    while true; do
        clear
        print_header
        echo -e "${PURPLE}╭─ Ollama Server Management${NC}"
        echo -e "${PURPLE}╰─ Choose an option:${NC}"
        echo ""
        echo -e "${CYAN}1.${NC} ${WHITE}Start server${NC}"
        echo -e "${CYAN}2.${NC} ${WHITE}Stop server${NC}"
        echo -e "${CYAN}3.${NC} ${WHITE}Check server status${NC}"
        echo -e "${CYAN}4.${NC} ${WHITE}View server logs${NC}"
        echo -e "${CYAN}5.${NC} ${WHITE}Attach to server session${NC}"
        echo -e "${CYAN}6.${NC} ${WHITE}Restart server${NC}"
        echo -e "${CYAN}7.${NC} ${WHITE}Back to main menu${NC}"
        echo ""
        
        read -p "$(echo -e "${YELLOW}Enter your choice (1-7): ${NC}")" choice
        
        case $choice in
            1)
                start_ollama_server
                read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")"
                ;;
            2)
                print_status "step" "Stopping Ollama server..."
                proot-distro login debian --shared-tmp -- bash -c "tmux kill-session -t ollama_server 2>/dev/null || true"
                print_status "success" "Server stopped!"
                read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")"
                ;;
            3)
                print_status "step" "Checking server status..."
                if proot-distro login debian --shared-tmp -- bash -c "tmux has-session -t ollama_server 2>/dev/null"; then
                    print_status "success" "Ollama server is running!"
                    print_status "info" "Session name: ollama_server"
                    print_status "info" "To attach: tmux attach-session -t ollama_server"
                    print_status "info" "To detach: Press CTRL+B then D"
                    
                    # Show session info
                    echo ""
                    echo -e "${WHITE}Session Information:${NC}"
                    proot-distro login debian --shared-tmp -- bash -c "tmux list-sessions | grep ollama_server"
                else
                    print_status "warning" "Ollama server is not running."
                    print_status "info" "Use option 1 to start the server"
                fi
                read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")"
                ;;
            4)
                print_status "step" "Showing server logs..."
                if proot-distro login debian --shared-tmp -- bash -c "tmux has-session -t ollama_server 2>/dev/null"; then
                    echo -e "${WHITE}Recent server logs:${NC}"
                    proot-distro login debian --shared-tmp -- bash -c "tmux capture-pane -pt ollama_server -S -50 || echo 'No logs available'"
                else
                    print_status "warning" "Server not running. Start it first to view logs."
                fi
                read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")"
                ;;
            5)
                print_status "step" "Attaching to server session..."
                if proot-distro login debian --shared-tmp -- bash -c "tmux has-session -t ollama_server 2>/dev/null"; then
                    print_status "info" "Attaching to ollama_server session..."
                    print_status "info" "Press CTRL+B then D to detach and return to launcher"
                    echo ""
                    proot-distro login debian --shared-tmp -- bash -c "tmux attach-session -t ollama_server"
                else
                    print_status "warning" "Server not running. Start it first to attach."
                fi
                read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")"
                ;;
            6)
                print_status "step" "Restarting Ollama server..."
                proot-distro login debian --shared-tmp -- bash -c "tmux kill-session -t ollama_server 2>/dev/null || true"
                sleep 1
                start_ollama_server
                read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")"
                ;;
            7)
                break
                ;;
            *)
                print_status "error" "Invalid choice. Please try again."
                sleep 2
                ;;
        esac
    done
}

# Function to show TMUX session tips
show_tmux_tips() {
    print_status "step" "TMUX Session Management Tips"
    echo ""
    echo -e "${WHITE}=== Ollama Server TMUX Session ===${NC}"
    echo ""
    echo -e "${CYAN}Session Name:${NC} ollama_server"
    echo ""
    echo -e "${WHITE}Useful Commands:${NC}"
    echo -e "${CYAN}• Attach to session:${NC} ${WHITE}tmux attach-session -t ollama_server${NC}"
    echo -e "${CYAN}• List sessions:${NC} ${WHITE}tmux list-sessions${NC}"
    echo -e "${CYAN}• Kill session:${NC} ${WHITE}tmux kill-session -t ollama_server${NC}"
    echo ""
    echo -e "${WHITE}TMUX Shortcuts (when attached):${NC}"
    echo -e "${CYAN}• Detach:${NC} ${WHITE}CTRL+B, then D${NC}"
    echo -e "${CYAN}• Split pane:${NC} ${WHITE}CTRL+B, then %${NC}"
    echo -e "${CYAN}• Switch panes:${NC} ${WHITE}CTRL+B, then arrow keys${NC}"
    echo -e "${CYAN}• New window:${NC} ${WHITE}CTRL+B, then c${NC}"
    echo -e "${CYAN}• Switch windows:${NC} ${WHITE}CTRL+B, then n/p${NC}"
    echo ""
    echo -e "${WHITE}Why Use TMUX?${NC}"
    echo -e "${CYAN}• Keep Ollama running${NC} when you close Termux"
    echo -e "${CYAN}• Background processing${NC} without blocking terminal"
    echo -e "${CYAN}• Easy session management${NC} and monitoring"
    echo ""
    read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")"
}

# Function to show system info
show_system_info() {
    print_status "step" "Gathering system information..."
    echo ""
    
    echo -e "${WHITE}Termux Information:${NC}"
    echo -e "${CYAN}  Version:${NC} $(pkg list-installed | grep termux-api || echo "Not installed")"
    echo -e "${CYAN}  Architecture:${NC} $(uname -m)"
    echo -e "${CYAN}  PATH:${NC} $PATH"
    echo ""
    
    echo -e "${WHITE}PRoot-Distro Information:${NC}"
    if command -v proot-distro &> /dev/null; then
        echo -e "${CYAN}  Location:${NC} $(which proot-distro)"
        echo -e "${CYAN}  Version:${NC} $(proot-distro --version 2>/dev/null || echo "Version info not available")"
    else
        echo -e "${RED}  Not found in PATH${NC}"
    fi
    echo ""
    
    echo -e "${WHITE}Available Linux Distributions:${NC}"
    if command -v proot-distro &> /dev/null; then
        proot-distro list
    else
        echo "Cannot list distributions - proot-distro not found"
    fi
    echo ""
    
    echo -e "${WHITE}TMUX Sessions:${NC}"
    if command -v proot-distro &> /dev/null; then
        if proot-distro login debian --shared-tmp -- bash -c "command -v tmux &> /dev/null"; then
            echo -e "${CYAN}  Active TMUX sessions:${NC}"
            proot-distro login debian --shared-tmp -- bash -c "tmux list-sessions 2>/dev/null || echo 'No active sessions'"
            
            # Check Ollama server session specifically
            if proot-distro login debian --shared-tmp -- bash -c "tmux has-session -t ollama_server 2>/dev/null"; then
                echo -e "${GREEN}  ✓ Ollama server session: ollama_server${NC}"
            else
                echo -e "${RED}  ✗ Ollama server session: Not running${NC}"
            fi
        else
            echo "TMUX not installed in Debian"
        fi
    else
        echo "Cannot check TMUX - proot-distro not found"
    fi
    echo ""
    
    echo -e "${WHITE}Ollama Models:${NC}"
    if command -v proot-distro &> /dev/null; then
        if proot-distro login debian --shared-tmp -- bash -c "command -v ollama &> /dev/null"; then
            proot-distro login debian --shared-tmp -- bash -c "ollama list 2>/dev/null || echo 'No models found'"
        else
            echo "Ollama not installed in Debian"
        fi
    else
        echo "Cannot check Ollama - proot-distro not found"
    fi
    
    echo ""
    read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")"
}

# Function to run diagnostics
run_diagnostics() {
    print_status "step" "Running system diagnostics..."
    echo ""
    
    echo -e "${WHITE}=== System Information ===${NC}"
    echo -e "${CYAN}Termux Version:${NC} $(pkg list-installed | grep termux-api || echo "Not installed")"
    echo -e "${CYAN}Architecture:${NC} $(uname -m)"
    echo -e "${CYAN}Android Version:${NC} $(getprop ro.build.version.release 2>/dev/null || echo "Unknown")"
    echo -e "${CYAN}Available Storage:${NC} $(df -h . | tail -1 | awk '{print $4}')"
    echo -e "${CYAN}Available RAM:${NC} $(free -h | grep Mem | awk '{print $7}')"
    echo ""
    
    echo -e "${WHITE}=== PRoot-Distro Status ===${NC}"
    if command -v proot-distro &> /dev/null; then
        echo -e "${GREEN}✓ PRoot-Distro found at: $(which proot-distro)${NC}"
        echo -e "${CYAN}Version:${NC} $(proot-distro --version 2>/dev/null || echo "Version info not available")"
        
        echo -e "${CYAN}Available distributions:${NC}"
        if proot-distro list &> /dev/null; then
            proot-distro list
        else
            echo -e "${RED}✗ Cannot list distributions${NC}"
        fi
    else
        echo -e "${RED}✗ PRoot-Distro not found in PATH${NC}"
        echo -e "${CYAN}PATH:${NC} $PATH"
        
        # Check common locations
        echo -e "${CYAN}Checking common locations:${NC}"
        for path in "/data/data/com.termux/files/usr/bin/proot-distro" "/usr/bin/proot-distro" "$HOME/.local/bin/proot-distro"; do
            if [ -f "$path" ]; then
                echo -e "${GREEN}✓ Found at: $path${NC}"
            else
                echo -e "${RED}✗ Not found at: $path${NC}"
            fi
        done
    fi
    echo ""
    
    echo -e "${WHITE}=== Debian Status ===${NC}"
    if command -v proot-distro &> /dev/null; then
        # Check if Debian is listed
        if proot-distro list | grep -q "debian"; then
            echo -e "${GREEN}✓ Debian is listed in proot-distro${NC}"
            
            # Check if we can access it
            if proot-distro login debian --shared-tmp -- bash -c "echo 'Debian access test successful'" &> /dev/null; then
                echo -e "${GREEN}✓ Can access Debian environment${NC}"
                
                # Check Ollama
                if proot-distro login debian --shared-tmp -- bash -c "command -v ollama &> /dev/null"; then
                    echo -e "${GREEN}✓ Ollama is installed in Debian${NC}"
                    echo -e "${CYAN}Ollama version:${NC} $(proot-distro login debian --shared-tmp -- bash -c "ollama --version 2>/dev/null || echo 'Version not available'")"
                else
                    echo -e "${RED}✗ Ollama not found in Debian${NC}"
                fi
            else
                echo -e "${RED}✗ Cannot access Debian environment${NC}"
            fi
        else
            echo -e "${RED}✗ Debian not found in proot-distro list${NC}"
            
            # Check common Debian paths
            echo -e "${CYAN}Checking Debian paths:${NC}"
            for path in "/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/debian" "$HOME/.local/share/proot-distro/installed-rootfs/debian"; do
                if [ -d "$path" ]; then
                    echo -e "${GREEN}✓ Debian directory found at: $path${NC}"
                else
                    echo -e "${RED}✗ Debian directory not found at: $path${NC}"
                fi
            done
        fi
    else
        echo -e "${RED}✗ Cannot check Debian - proot-distro not available${NC}"
    fi
    echo ""
    
    echo -e "${WHITE}=== Recommendations ===${NC}"
    if ! command -v proot-distro &> /dev/null; then
        echo -e "${YELLOW}1. Install proot-distro: ${WHITE}pkg install proot-distro -y${NC}"
    elif ! proot-distro list | grep -q "debian"; then
        echo -e "${YELLOW}1. Install Debian: ${WHITE}proot-distro install debian${NC}"
    elif ! proot-distro login debian --shared-tmp -- bash -c "command -v ollama &> /dev/null"; then
        echo -e "${YELLOW}1. Install Ollama in Debian: ${WHITE}proot-distro login debian -- bash -c 'curl -fsSL https://ollama.ai/install.sh | sh'${NC}"
    else
        echo -e "${GREEN}✓ All components are properly installed!${NC}"
    fi
    
    echo ""
    read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")"
}

# Main menu function
main_menu() {
    while true; do
        print_header
        
        # Check installation status
        if ! check_installation; then
            echo ""
            echo -e "${YELLOW}${STAR} Troubleshooting Steps:${NC}"
            echo -e "${CYAN}1.${NC} Update Termux: ${WHITE}pkg update && pkg upgrade -y${NC}"
            echo -e "${CYAN}2.${NC} Install proot-distro: ${WHITE}pkg install proot-distro -y${NC}"
            echo -e "${CYAN}3.${NC} Run installation script: ${WHITE}bash scripts/install_deepseek.sh${NC}"
            echo -e "${CYAN}4.${NC} Check PATH: ${WHITE}echo \$PATH${NC}"
            echo ""
            read -p "$(echo -e "${GREEN}Press Enter to exit...${NC}")"
            exit 1
        fi
        
        echo -e "${PURPLE}╭─ Main Menu${NC}"
        echo -e "${PURPLE}╰─ Choose an option:${NC}"
        echo ""
        echo -e "${CYAN}1.${NC} ${WHITE}${BRAIN} Start ${CURRENT_MODEL} Chat${NC}"
        echo -e "${CYAN}2.${NC} ${WHITE}${MODEL} Select/Download Model${NC}"
        echo -e "${CYAN}3.${NC} ${WHITE}${GEAR} Manage Ollama Server${NC}"
        echo -e "${CYAN}4.${NC} ${WHITE}${DOWNLOAD} Check Model Status${NC}"
        echo -e "${CYAN}5.${NC} ${WHITE}${SETTINGS} Manage Models${NC}"
        echo -e "${CYAN}6.${NC} ${WHITE}${SETTINGS} System Information${NC}"
        echo -e "${CYAN}7.${NC} ${WHITE}🔍 Run Diagnostics${NC}"
        echo -e "${CYAN}8.${NC} ${WHITE}📚 TMUX Tips${NC}"
        echo -e "${CYAN}9.${NC} ${WHITE}${EXIT} Exit${NC}"
        echo ""
        
        read -p "$(echo -e "${YELLOW}Enter your choice (1-9): ${NC}")" choice
        
        case $choice in
            1)
                ensure_ollama_server
                check_model_status
                run_model
                ;;
            2)
                select_model
                ;;
            3)
                manage_server
                ;;
            4)
                check_model_status
                read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")"
                ;;
            5)
                manage_models
                ;;
            6)
                show_system_info
                ;;
            7)
                run_diagnostics
                ;;
            8)
                show_tmux_tips
                ;;
            9)
                print_status "info" "Thank you for using DeepSeek R1 Launcher!"
                echo -e "${GREEN}${ROCKET} Goodbye!${NC}"
                exit 0
                ;;
            *)
                print_status "error" "Invalid choice. Please try again."
                sleep 2
                ;;
        esac
    done
}

# Check if running in Termux
if [ ! -d "/data/data/com.termux" ]; then
    echo -e "${RED}${CROSS_MARK} This script is designed for Termux on Android.${NC}"
    echo -e "${RED}Please run this script in Termux.${NC}"
    exit 1
fi

# Run main menu
main_menu
