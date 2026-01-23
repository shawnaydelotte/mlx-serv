#!/bin/bash
# =====================================================================
#   Enhanced MLX-LM + LiteLLM Startup Script
#   Beautiful status display, health checks, and process management
# =====================================================================

set -e

# ANSI color codes for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Configuration
MLX_PORT=8080
LITELLM_PORT=4000
MODEL_DIR="./qwen-coder-7b-4bit"
VENV_DIR="./mlx-env"
MLX_LOG="mlx_server.log"
LITELLM_LOG="litellm_proxy.log"
PID_FILE=".server_pids"

# Parse command line arguments
FAST_MODE=false
CONFIG_FILE="./config.optimized.yaml"

# Symbols for status
CHECKMARK="✓"
CROSS="✗"
ARROW="→"
ROCKET="🚀"
HOURGLASS="⏳"
WRENCH="🔧"

# Print functions
print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║${RESET}  ${MAGENTA}${BOLD}MLX-LM Local Coding Model Server${RESET}                  ${CYAN}${BOLD}║${RESET}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

print_step() {
    echo -e "${BLUE}${ARROW}${RESET} ${BOLD}$1${RESET}"
}

print_success() {
    echo -e "  ${GREEN}${CHECKMARK}${RESET} $1"
}

print_error() {
    echo -e "  ${RED}${CROSS}${RESET} $1"
}

print_info() {
    echo -e "  ${DIM}$1${RESET}"
}

print_status() {
    echo -e "${YELLOW}${HOURGLASS}${RESET} $1"
}

# Cleanup function
cleanup() {
    echo ""
    print_error "Interrupted! Cleaning up..."
    stop_servers
    exit 1
}

trap cleanup INT TERM

# Function to check if port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to wait for service to be ready
wait_for_service() {
    local url=$1
    local name=$2
    local max_attempts=30
    local attempt=0

    print_status "Waiting for $name to respond..."

    while [ $attempt -lt $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" "$url" > /dev/null 2>&1; then
            print_success "$name is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        echo -ne "  ${DIM}Attempt $attempt/$max_attempts...${RESET}\r"
        sleep 1
    done

    print_error "$name failed to respond within ${max_attempts}s"
    return 1
}

# Function to display live logs with filtering
show_startup_logs() {
    local log_file=$1
    local service_name=$2
    local duration=5

    if [ -f "$log_file" ]; then
        echo -e "\n  ${DIM}━━━━━━ $service_name logs (${duration}s) ━━━━━━${RESET}"
        timeout ${duration}s tail -f "$log_file" 2>/dev/null | while IFS= read -r line; do
            # Highlight errors and important messages
            if echo "$line" | grep -qi "error\|fail\|exception"; then
                echo -e "  ${RED}${line}${RESET}"
            elif echo "$line" | grep -qi "warning\|warn"; then
                echo -e "  ${YELLOW}${line}${RESET}"
            elif echo "$line" | grep -qi "success\|ready\|listening\|started"; then
                echo -e "  ${GREEN}${line}${RESET}"
            else
                echo -e "  ${DIM}${line}${RESET}"
            fi
        done || true
        echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    fi
}

# Function to check system requirements
check_requirements() {
    print_step "Checking system requirements..."

    # Check if running on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script is designed for macOS with Apple Silicon"
        exit 1
    fi
    print_success "Running on macOS"

    # Check for Apple Silicon
    if [[ $(uname -m) != "arm64" ]]; then
        print_error "Apple Silicon (M1/M2/M3) required for MLX"
        exit 1
    fi
    print_success "Apple Silicon detected"

    # Check for Python
    if [ ! -d "$VENV_DIR" ]; then
        print_error "Virtual environment not found: $VENV_DIR"
        print_info "Run setup.sh first to install dependencies"
        exit 1
    fi
    print_success "Virtual environment found"

    # Check for model
    if [ ! -d "$MODEL_DIR" ]; then
        print_error "Model directory not found: $MODEL_DIR"
        print_info "Run setup.sh to download the model"
        exit 1
    fi
    print_success "Model directory found"

    # Check for config
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "Config file not found: $CONFIG_FILE"
        exit 1
    fi
    print_success "Configuration file found"

    # Check available memory (inactive + free pages)
    local page_size=$(vm_stat | head -1 | grep -o '[0-9]*' | tail -1)
    local free_pages=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    local inactive_pages=$(vm_stat | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
    local available_pages=$((free_pages + inactive_pages))
    local available_gb=$((available_pages * page_size / 1024 / 1024 / 1024))
    local total_mem=$(sysctl -n hw.memsize)
    local total_gb=$((total_mem / 1024 / 1024 / 1024))

    if [ $available_gb -lt 4 ]; then
        print_error "Low memory: ${available_gb}GB available of ${total_gb}GB total"
    else
        print_success "Memory: ${available_gb}GB available of ${total_gb}GB total"
    fi
}

# Function to start MLX-LM server
start_mlx_server() {
    print_step "Starting MLX-LM server..."

    # Check if already running
    if check_port $MLX_PORT; then
        print_error "Port $MLX_PORT already in use!"
        print_info "Run '$0 --stop' to stop existing servers"
        exit 1
    fi

    # Activate venv and start
    source "$VENV_DIR/bin/activate"

    # Clear old log
    > "$MLX_LOG"

    # Start server
    nohup python -m mlx_lm.server --model "$MODEL_DIR" --port $MLX_PORT > "$MLX_LOG" 2>&1 &
    local pid=$!
    echo "mlx:$pid" >> "$PID_FILE"

    print_info "PID: $pid"
    print_info "Log: $MLX_LOG"

    # Wait for process to stabilize
    sleep 2
    if ! ps -p $pid > /dev/null 2>&1; then
        print_error "Process died immediately!"
        show_startup_logs "$MLX_LOG" "MLX-LM"
        exit 1
    fi

    print_success "Process started"

    # Show startup logs
    show_startup_logs "$MLX_LOG" "MLX-LM"

    # Health check
    if ! wait_for_service "http://localhost:$MLX_PORT/health" "MLX-LM server"; then
        # Try v1/models endpoint as fallback
        if ! wait_for_service "http://localhost:$MLX_PORT/v1/models" "MLX-LM server"; then
            print_error "Health check failed"
            show_startup_logs "$MLX_LOG" "MLX-LM"
            exit 1
        fi
    fi
}

# Function to start LiteLLM proxy
start_litellm_proxy() {
    print_step "Starting LiteLLM proxy..."

    if [ "$FAST_MODE" = true ]; then
        print_info "Using 3B model (fast mode)"
    else
        print_info "Using 7B model (quality mode)"
    fi

    # Check if already running
    if check_port $LITELLM_PORT; then
        print_error "Port $LITELLM_PORT already in use!"
        exit 1
    fi

    # Clear old log
    > "$LITELLM_LOG"

    # Start proxy
    nohup litellm --config "$CONFIG_FILE" --port $LITELLM_PORT > "$LITELLM_LOG" 2>&1 &
    local pid=$!
    echo "litellm:$pid" >> "$PID_FILE"

    print_info "PID: $pid"
    print_info "Config: $CONFIG_FILE"
    print_info "Log: $LITELLM_LOG"

    # Wait for process to stabilize
    sleep 2
    if ! ps -p $pid > /dev/null 2>&1; then
        print_error "Process died immediately!"
        show_startup_logs "$LITELLM_LOG" "LiteLLM"
        exit 1
    fi

    print_success "Process started"

    # Show startup logs
    show_startup_logs "$LITELLM_LOG" "LiteLLM"

    # Health check
    if ! wait_for_service "http://localhost:$LITELLM_PORT/health" "LiteLLM proxy"; then
        print_error "Health check failed"
        show_startup_logs "$LITELLM_LOG" "LiteLLM"
        exit 1
    fi
}

# Function to display running status
show_status() {
    echo ""
    echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}  ${ROCKET} ${BOLD}Servers Running Successfully!${RESET}                      ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}╠════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}                                                            ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}  ${BOLD}MLX-LM Backend:${RESET}                                         ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}    ${CYAN}http://localhost:$MLX_PORT/v1${RESET}                         ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}                                                            ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}  ${BOLD}LiteLLM Proxy (Anthropic-compatible):${RESET}                  ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}    ${CYAN}http://localhost:$LITELLM_PORT${RESET}                             ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}                                                            ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}  ${BOLD}Model:${RESET} claude-coder-fake                                ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}    ${DIM}(Qwen2.5-Coder-7B-Instruct 4-bit)${RESET}                   ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}                                                            ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}╠════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}  ${WRENCH} ${BOLD}Usage Commands:${RESET}                                      ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}                                                            ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}  View logs:       ${YELLOW}$0 --logs${RESET}                     ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}  Check status:    ${YELLOW}$0 --status${RESET}                   ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}  Stop servers:    ${YELLOW}$0 --stop${RESET}                     ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}  Restart:         ${YELLOW}$0 --restart${RESET}                  ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}  Setup OpenCode:  ${YELLOW}./configure-opencode.sh${RESET}       ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}                                                            ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}╠════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}  ${BOLD}Testing:${RESET}                                                ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}                                                            ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}  ${DIM}curl http://localhost:$LITELLM_PORT/health${RESET}              ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}  ${DIM}curl http://localhost:$LITELLM_PORT/v1/models${RESET}           ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}║${RESET}                                                            ${GREEN}${BOLD}║${RESET}"
    echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

# Function to stop servers
stop_servers() {
    print_step "Stopping servers..."

    if [ -f "$PID_FILE" ]; then
        while IFS=: read -r service pid; do
            if ps -p "$pid" > /dev/null 2>&1; then
                kill "$pid" 2>/dev/null && print_success "Stopped $service (PID: $pid)" || print_error "Failed to stop $service"
            fi
        done < "$PID_FILE"
        rm -f "$PID_FILE"
    fi

    # Fallback: kill by process name
    pkill -f "mlx_lm.server" 2>/dev/null && print_success "Killed mlx_lm.server processes" || true
    pkill -f "litellm.*config" 2>/dev/null && print_success "Killed litellm processes" || true

    print_success "All servers stopped"
}

# Function to show current status
check_status() {
    print_step "Checking server status..."

    local mlx_running=false
    local litellm_running=false

    if check_port $MLX_PORT; then
        print_success "MLX-LM server: Running on port $MLX_PORT"
        mlx_running=true
    else
        print_error "MLX-LM server: Not running"
    fi

    if check_port $LITELLM_PORT; then
        print_success "LiteLLM proxy: Running on port $LITELLM_PORT"
        litellm_running=true
    else
        print_error "LiteLLM proxy: Not running"
    fi

    if [ "$mlx_running" = true ] && [ "$litellm_running" = true ]; then
        echo ""
        print_success "All services operational"

        # Test endpoints
        echo ""
        print_step "Testing endpoints..."

        local mlx_health=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$MLX_PORT/v1/models" 2>/dev/null)
        if [ "$mlx_health" = "200" ]; then
            print_success "MLX-LM endpoint responding"
        else
            print_error "MLX-LM endpoint not responding (HTTP $mlx_health)"
        fi

        local litellm_health=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$LITELLM_PORT/health" 2>/dev/null)
        if [ "$litellm_health" = "200" ]; then
            print_success "LiteLLM endpoint responding"
        else
            print_error "LiteLLM endpoint not responding (HTTP $litellm_health)"
        fi
    else
        echo ""
        print_error "Services not fully operational"
        print_info "Run '$0' to start servers"
    fi
}

# Function to tail logs
tail_logs() {
    print_step "Tailing logs (Ctrl+C to exit)..."
    echo ""

    if [ -f "$MLX_LOG" ] && [ -f "$LITELLM_LOG" ]; then
        tail -f "$MLX_LOG" "$LITELLM_LOG" | while IFS= read -r line; do
            if echo "$line" | grep -q "^==>"; then
                echo -e "\n${CYAN}${BOLD}$line${RESET}"
            elif echo "$line" | grep -qi "error\|fail\|exception"; then
                echo -e "${RED}$line${RESET}"
            elif echo "$line" | grep -qi "warning\|warn"; then
                echo -e "${YELLOW}$line${RESET}"
            else
                echo -e "${DIM}$line${RESET}"
            fi
        done
    else
        print_error "Log files not found. Are servers running?"
        exit 1
    fi
}

# Main function
main() {
    # Parse arguments first
    while [[ $# -gt 0 ]]; do
        case $1 in
            --fast)
                FAST_MODE=true
                CONFIG_FILE="./config.3b.yaml"
                shift
                ;;
            --stop)
                print_header
                stop_servers
                exit 0
                ;;
            --status)
                print_header
                check_status
                exit 0
                ;;
            --logs)
                print_header
                tail_logs
                exit 0
                ;;
            --restart)
                print_header
                stop_servers
                sleep 2
                shift
                # Continue processing remaining arguments
                continue
                ;;
            --configure-opencode)
                if [ -f "./configure-opencode.sh" ]; then
                    ./configure-opencode.sh
                else
                    echo "Error: configure-opencode.sh not found"
                    exit 1
                fi
                exit 0
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  (no args)          Start servers with 7B model (quality)"
                echo "  --fast             Start with 3B model for faster inference"
                echo "  --stop             Stop all servers"
                echo "  --status           Check server status"
                echo "  --logs             Tail server logs"
                echo "  --restart          Restart all servers"
                echo "  --configure-opencode  Configure OpenCode to use local server"
                echo "  --help             Show this help"
                echo ""
                echo "Examples:"
                echo "  $0                 # Start with 7B model (quality)"
                echo "  $0 --fast          # Start with 3B model (speed)"
                echo "  $0 --restart --fast # Restart with 3B model"
                echo ""
                echo "OpenCode Configuration:"
                echo "  Run './configure-opencode.sh' to set up OpenCode"
                echo "  Or run './configure-opencode.sh --optimized' for better code generation"
                exit 0
                ;;
            "")
                # No arguments, continue to start servers
                break
                ;;
            *)
                echo "Unknown option: $1"
                echo "Run '$0 --help' for usage"
                exit 1
                ;;
        esac
    done

    # Set model directory based on selected mode
    if [ "$FAST_MODE" = true ]; then
        MODEL_DIR="./qwen-coder-3b-4bit"
    else
        MODEL_DIR="./qwen-coder-7b-4bit"
    fi

    # Start servers
    print_header
    check_requirements
    echo ""

    # Clean up any stale PID file
    rm -f "$PID_FILE"

    start_mlx_server
    echo ""
    start_litellm_proxy

    show_status
}

# Run main
main "$@"
