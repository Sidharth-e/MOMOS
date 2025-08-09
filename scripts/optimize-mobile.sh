#!/bin/bash

# MOMOS Mobile Optimization Script
# Optimizes models and system settings for mobile devices

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() { echo -e "${GREEN}[OPTIMIZE]${NC} $1"; }
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

# Detect mobile platform
detect_mobile() {
    log "Detecting mobile platform..."
    
    if [[ -n "$TERMUX_VERSION" ]]; then
        PLATFORM="android-termux"
        log "Detected: Android (Termux)"
    elif [[ -n "$ISH_VERSION" ]]; then
        PLATFORM="ios-ish"
        log "Detected: iOS (iSH)"
    elif [[ -f "/proc/version" ]] && grep -q "Android" /proc/version; then
        PLATFORM="android-native"
        log "Detected: Android (Native)"
    else
        PLATFORM="desktop"
        log "Detected: Desktop/Linux"
    fi
}

# Optimize system settings
optimize_system() {
    log "Optimizing system settings for mobile..."
    
    case "$PLATFORM" in
        "android-termux")
            # Termux-specific optimizations
            log "Applying Termux optimizations..."
            
            # Set process priority
            if command -v renice >/dev/null 2>&1; then
                renice -n -10 -p $$ 2>/dev/null || true
            fi
            
            # Optimize memory management
            if [[ -f "/proc/sys/vm/swappiness" ]]; then
                echo 10 > /proc/sys/vm/swappiness 2>/dev/null || true
            fi
            
            # Set CPU governor to performance if available
            if [[ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]]; then
                echo "performance" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
            fi
            ;;
            
        "ios-ish")
            # iSH-specific optimizations
            log "Applying iSH optimizations..."
            
            # iSH runs on iOS, so we focus on memory efficiency
            export PYTHONUNBUFFERED=1
            export PYTHONDONTWRITEBYTECODE=1
            ;;
            
        "android-native")
            # Native Android optimizations
            log "Applying native Android optimizations..."
            
            # Similar to Termux but with Android-specific paths
            if [[ -f "/proc/sys/vm/swappiness" ]]; then
                echo 10 > /proc/sys/vm/swappiness 2>/dev/null || true
            fi
            ;;
            
        "desktop")
            log "Desktop platform detected. Applying standard optimizations..."
            ;;
    esac
    
    log "System optimization completed"
}

# Quantize models for mobile
quantize_models() {
    log "Checking for models to quantize..."
    
    if [[ ! -d "models" ]]; then
        warn "No models directory found. Run setup.sh first."
        return
    fi
    
    # Find installed models
    local models=($(ls -d models/*/ 2>/dev/null | sed 's|models/||' | sed 's|/||'))
    
    if [[ ${#models[@]} -eq 0 ]]; then
        warn "No models found. Install models first with download-model.sh"
        return
    fi
    
    for model_id in "${models[@]}"; do
        local model_dir="models/$model_id"
        local quantized_dir="models/${model_id}-quantized"
        
        if [[ -d "$quantized_dir" ]]; then
            log "Model $model_id already quantized"
            continue
        fi
        
        log "Quantizing model: $model_id"
        
        # Create quantization script
        cat > temp_quantize.py << 'EOF'
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
import sys
from pathlib import Path

def quantize_model(model_dir, output_dir):
    try:
        print(f"Loading model from {model_dir}...")
        tokenizer = AutoTokenizer.from_pretrained(model_dir)
        
        if tokenizer.pad_token is None:
            tokenizer.pad_token = tokenizer.eos_token
        
        print("Loading model for quantization...")
        model = AutoModelForCausalLM.from_pretrained(
            model_dir,
            torch_dtype=torch.float16,
            low_cpu_mem_usage=True
        )
        
        print("Applying INT8 quantization...")
        # Quantize to INT8 for mobile optimization
        quantized_model = torch.quantization.quantize_dynamic(
            model, 
            {torch.nn.Linear}, 
            dtype=torch.qint8
        )
        
        print(f"Saving quantized model to {output_dir}...")
        quantized_model.save_pretrained(output_dir)
        tokenizer.save_pretrained(output_dir)
        
        print("Quantization completed successfully!")
        return True
        
    except Exception as e:
        print(f"Error during quantization: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python temp_quantize.py <model_dir> <output_dir>")
        sys.exit(1)
    
    model_dir = sys.argv[1]
    output_dir = sys.argv[2]
    
    success = quantize_model(model_dir, output_dir)
    sys.exit(0 if success else 1)
EOF
        
        # Run quantization
        if python3 temp_quantize.py "$model_dir" "$quantized_dir"; then
            log "✅ Model $model_id quantized successfully"
            
            # Calculate size reduction
            local original_size=$(du -sh "$model_dir" | cut -f1)
            local quantized_size=$(du -sh "$quantized_dir" | cut -f1)
            log "Size reduction: $original_size → $quantized_size"
        else
            error "❌ Failed to quantize model $model_id"
        fi
        
        # Cleanup
        rm -f temp_quantize.py
    done
}

# Create mobile-optimized configuration
create_mobile_config() {
    log "Creating mobile-optimized configuration..."
    
    # Create mobile-specific config
    cat > config/mobile-optimized.json << 'EOF'
{
    "mobile_settings": {
        "android_termux": {
            "max_memory_usage": 0.7,
            "quantization": "int8",
            "batch_size": 1,
            "max_length": 256,
            "use_cache": false,
            "low_cpu_mem_usage": true
        },
        "ios_ish": {
            "max_memory_usage": 0.6,
            "quantization": "int8",
            "batch_size": 1,
            "max_length": 128,
            "use_cache": false,
            "low_cpu_mem_usage": true
        },
        "android_native": {
            "max_memory_usage": 0.8,
            "quantization": "int8",
            "batch_size": 1,
            "max_length": 512,
            "use_cache": true,
            "low_cpu_mem_usage": true
        }
    },
    "performance_tips": {
        "close_other_apps": "Close unnecessary apps to free up memory",
        "use_quantized_models": "Quantized models use less memory and are faster",
        "adjust_batch_size": "Reduce batch size if you encounter memory issues",
        "monitor_temperature": "Mobile devices may throttle performance when hot"
    }
}
EOF
    
    log "Mobile configuration created"
}

# Performance monitoring
setup_monitoring() {
    log "Setting up performance monitoring..."
    
    # Create monitoring script
    cat > scripts/monitor-performance.sh << 'EOF'
#!/bin/bash

# MOMOS Performance Monitor
# Monitors system resources during model inference

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[MONITOR]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Monitor CPU and memory
monitor_resources() {
    echo "=== MOMOS Performance Monitor ==="
    echo "Timestamp: $(date)"
    echo
    
    # CPU usage
    if command -v top >/dev/null 2>&1; then
        echo "CPU Usage:"
        top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//'
        echo
    fi
    
    # Memory usage
    if command -v free >/dev/null 2>&1; then
        echo "Memory Usage:"
        free -h | grep -E "^Mem|^Swap"
        echo
    fi
    
    # Disk usage
    if command -v df >/dev/null 2>&1; then
        echo "Disk Usage:"
        df -h . | grep -v "Filesystem"
        echo
    fi
    
    # Temperature (if available)
    if [[ -f "/sys/class/thermal/thermal_zone0/temp" ]]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp_c=$((temp / 1000))
        echo "Temperature: ${temp_c}°C"
        
        if [[ $temp_c -gt 70 ]]; then
            warn "High temperature detected! Performance may be throttled."
        fi
        echo
    fi
    
    # Process info
    echo "MOMOS Processes:"
    ps aux | grep -E "(python|momos)" | grep -v grep || echo "No MOMOS processes running"
}

# Continuous monitoring
continuous_monitor() {
    local interval=${1:-5}
    log "Starting continuous monitoring (every ${interval}s)..."
    log "Press Ctrl+C to stop"
    
    while true; do
        clear
        monitor_resources
        sleep $interval
    done
}

# Main function
main() {
    case "${1:-single}" in
        "continuous"|"-c")
            continuous_monitor "${2:-5}"
            ;;
        "single"|"-s"|"")
            monitor_resources
            ;;
        *)
            echo "Usage: $0 [mode] [interval]"
            echo "Modes:"
            echo "  single      - Single snapshot (default)"
            echo "  continuous  - Continuous monitoring"
            echo "Examples:"
            echo "  $0                    # Single snapshot"
            echo "  $0 continuous         # Continuous, every 5s"
            echo "  $0 continuous 10      # Continuous, every 10s"
            ;;
    esac
}

main "$@"
EOF
    
    chmod +x scripts/monitor-performance.sh
    log "Performance monitoring script created"
}

# Main function
main() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                MOMOS Mobile Optimization                    ║"
    echo "║         Optimizing for mobile device performance           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_venv
    detect_mobile
    optimize_system
    quantize_models
    create_mobile_config
    setup_monitoring
    
    echo
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🎉 Mobile optimization completed! 🎉${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo
    echo "Optimizations applied:"
    echo "✓ System settings optimized for $PLATFORM"
    echo "✓ Models quantized for mobile performance"
    echo "✓ Mobile-specific configuration created"
    echo "✓ Performance monitoring script created"
    echo
    echo "Next steps:"
    echo "1. Monitor performance: ./scripts/monitor-performance.sh"
    echo "2. Run inference with optimized models"
    echo "3. Use quantized models for better performance"
    echo
    echo "Performance tips:"
    echo "- Close other apps to free up memory"
    echo "- Use quantized models (models/*-quantized/)"
    echo "- Monitor temperature to avoid throttling"
    echo "- Adjust batch size if you encounter memory issues"
    echo
}

# Run main function
main "$@"
