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
    if ! command -v proot-distro &> /dev/null; then
        print_status "error" "PRoot-Distro not found. Please run the installation script first."
        return 1
    fi
    
    if ! proot-distro list | grep -q "debian"; then
        print_status "error" "Debian not found. Please run the installation script first."
        return 1
    fi
    
    return 0
}

# Function to start Ollama server
start_ollama_server() {
    print_status "step" "Starting Ollama server..."
    
    # Check if server is already running
    if proot-distro login debian --shared-tmp -- bash -c "tmux has-session -t ollama_server 2>/dev/null"; then
        print_status "success" "Ollama server is already running!"
    else
        proot-distro login debian --shared-tmp -- bash -c "
            tmux new-session -d -s ollama_server 'ollama serve'
        "
        print_status "success" "Ollama server started successfully!"
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
        echo -e "${CYAN}5.${NC} ${WHITE}Back to main menu${NC}"
        echo ""
        
        read -p "$(echo -e "${YELLOW}Enter your choice (1-5): ${NC}")" choice
        
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
                else
                    print_status "warning" "Ollama server is not running."
                fi
                read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")"
                ;;
            4)
                print_status "step" "Showing server logs..."
                proot-distro login debian --shared-tmp -- bash -c "tmux capture-pane -pt ollama_server -S -50 || echo 'No logs available'"
                read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")"
                ;;
            5)
                break
                ;;
            *)
                print_status "error" "Invalid choice. Please try again."
                sleep 2
                ;;
        esac
    done
}

# Function to show system info
show_system_info() {
    print_status "step" "Gathering system information..."
    echo ""
    
    echo -e "${WHITE}Termux Information:${NC}"
    echo -e "${CYAN}  Version:${NC} $(pkg list-installed | grep termux-api || echo "Not installed")"
    echo -e "${CYAN}  Architecture:${NC} $(uname -m)"
    echo ""
    
    echo -e "${WHITE}Available Linux Distributions:${NC}"
    proot-distro list
    echo ""
    
    echo -e "${WHITE}Ollama Models:${NC}"
    if proot-distro login debian --shared-tmp -- bash -c "command -v ollama &> /dev/null"; then
        proot-distro login debian --shared-tmp -- bash -c "ollama list 2>/dev/null || echo 'No models found'"
    else
        echo "Ollama not installed"
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
            echo -e "${RED}${CROSS_MARK} Installation incomplete. Please run the installation script first.${NC}"
            echo ""
            echo -e "${YELLOW}Run: ${CYAN}bash scripts/install_deepseek.sh${NC}"
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
        echo -e "${CYAN}7.${NC} ${WHITE}${EXIT} Exit${NC}"
        echo ""
        
        read -p "$(echo -e "${YELLOW}Enter your choice (1-7): ${NC}")" choice
        
        case $choice in
            1)
                start_ollama_server
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
