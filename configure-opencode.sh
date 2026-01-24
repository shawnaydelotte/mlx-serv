#!/bin/bash
# =====================================================================
#   OpenCode Configuration Script for MLX-LM Local Server
#   Automatically configures OpenCode to use local MLX-LM server
# =====================================================================

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

CHECKMARK="✓"
ARROW="→"

OPENCODE_CONFIG="$HOME/.config/opencode/config.json"
OPENCODE_DIR="$HOME/.config/opencode"
BACKUP_SUFFIX=".backup-$(date +%Y%m%d-%H%M%S)"

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}${BOLD}║  OpenCode Configuration for MLX-LM Server  ║${RESET}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════╝${RESET}"
echo ""

# Check if OpenCode config directory exists
if [ ! -d "$OPENCODE_DIR" ]; then
    echo -e "${YELLOW}${ARROW}${RESET} Creating OpenCode config directory..."
    mkdir -p "$OPENCODE_DIR"
    echo -e "  ${GREEN}${CHECKMARK}${RESET} Directory created: $OPENCODE_DIR"
else
    echo -e "  ${GREEN}${CHECKMARK}${RESET} OpenCode config directory exists"
fi

# Backup existing config if it exists
if [ -f "$OPENCODE_CONFIG" ]; then
    echo -e "\n${YELLOW}${ARROW}${RESET} Backing up existing configuration..."
    cp "$OPENCODE_CONFIG" "${OPENCODE_CONFIG}${BACKUP_SUFFIX}"
    echo -e "  ${GREEN}${CHECKMARK}${RESET} Backup saved: ${OPENCODE_CONFIG}${BACKUP_SUFFIX}"
fi

# Determine which config to use (default or optimized)
USE_OPTIMIZED=false
if [ "$1" = "--optimized" ]; then
    USE_OPTIMIZED=true
    echo -e "\n${BLUE}${ARROW}${RESET} Using optimized settings for code generation"
fi

# Create OpenCode configuration
echo -e "\n${YELLOW}${ARROW}${RESET} Writing OpenCode configuration..."

if [ "$USE_OPTIMIZED" = true ]; then
    # Optimized settings (matches config.optimized.yaml)
    cat > "$OPENCODE_CONFIG" << 'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "anthropic": {
      "options": {
        "baseURL": "http://localhost:4000/v1"
      },
      "models": {
        "claude-coder-fake": {
          "options": {
            "maxTokens": 8192,
            "temperature": 0.3,
            "contextWindow": 32768,
            "topP": 0.9,
            "frequencyPenalty": 0.1,
            "presencePenalty": 0.1
          }
        }
      }
    }
  },
  "model": "anthropic/claude-coder-fake",
  "features": {
    "streaming": true,
    "codeCompletion": true,
    "diagnostics": true
  }
}
EOF
    echo -e "  ${GREEN}${CHECKMARK}${RESET} Optimized configuration written"
else
    # Default settings (matches config.yaml)
    cat > "$OPENCODE_CONFIG" << 'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "anthropic": {
      "options": {
        "baseURL": "http://localhost:4000/v1"
      },
      "models": {
        "claude-coder-fake": {
          "options": {
            "maxTokens": 4096,
            "temperature": 0.7,
            "contextWindow": 32768
          }
        }
      }
    }
  },
  "model": "anthropic/claude-coder-fake",
  "features": {
    "streaming": true,
    "codeCompletion": true
  }
}
EOF
    echo -e "  ${GREEN}${CHECKMARK}${RESET} Default configuration written"
fi

# Verify configuration
echo -e "\n${YELLOW}${ARROW}${RESET} Verifying configuration..."
if [ -f "$OPENCODE_CONFIG" ]; then
    if command -v jq &> /dev/null; then
        if jq empty "$OPENCODE_CONFIG" 2>/dev/null; then
            echo -e "  ${GREEN}${CHECKMARK}${RESET} Configuration is valid JSON"
        else
            echo -e "  ${RED}✗${RESET} Configuration has JSON syntax errors!"
            exit 1
        fi
    else
        echo -e "  ${DIM}Note: Install 'jq' for JSON validation${RESET}"
    fi
    echo -e "  ${GREEN}${CHECKMARK}${RESET} Configuration file exists"
else
    echo -e "  ${RED}✗${RESET} Failed to create configuration file"
    exit 1
fi

# Display configuration summary
echo -e "\n${GREEN}${BOLD}╔════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║  Configuration Complete! ✓                 ║${RESET}"
echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════╝${RESET}"

echo -e "\n${BOLD}Configuration Details:${RESET}"
echo -e "  Location: ${CYAN}$OPENCODE_CONFIG${RESET}"
echo -e "  API URL:  ${CYAN}http://localhost:4000/v1${RESET}"
echo -e "  Model:    ${CYAN}claude-coder-fake${RESET}"

if [ "$USE_OPTIMIZED" = true ]; then
    echo -e "  Profile:  ${CYAN}Optimized for code generation${RESET}"
    echo -e "    • Max Tokens: 8192 (longer outputs)"
    echo -e "    • Temperature: 0.3 (more focused)"
    echo -e "    • Penalties: Reduced repetition"
else
    echo -e "  Profile:  ${CYAN}Default settings${RESET}"
    echo -e "    • Max Tokens: 4096"
    echo -e "    • Temperature: 0.7"
fi

echo -e "\n${BOLD}Model Details:${RESET}"
echo -e "  Base Model: ${DIM}Qwen2.5-Coder-7B-Instruct (4-bit)${RESET}"
echo -e "  Context:    ${DIM}32K tokens${RESET}"
echo -e "  Streaming:  ${DIM}Enabled${RESET}"

echo -e "\n${BOLD}Next Steps:${RESET}"
echo -e "  ${BLUE}1.${RESET} Start the MLX-LM server:"
echo -e "     ${DIM}cd /Users/s/Projects/mlx-serv && ./start.sh${RESET}"
echo -e ""
echo -e "  ${BLUE}2.${RESET} Verify server is running:"
echo -e "     ${DIM}./start.sh --status${RESET}"
echo -e ""
echo -e "  ${BLUE}3.${RESET} Test the connection:"
echo -e "     ${DIM}./test.sh${RESET}"
echo -e ""
echo -e "  ${BLUE}4.${RESET} Launch OpenCode and start coding!"

if [ -f "${OPENCODE_CONFIG}${BACKUP_SUFFIX}" ]; then
    echo -e "\n${DIM}Backup: ${OPENCODE_CONFIG}${BACKUP_SUFFIX}${RESET}"
    echo -e "${DIM}To restore: cp ${OPENCODE_CONFIG}${BACKUP_SUFFIX} ${OPENCODE_CONFIG}${RESET}"
fi

echo -e "\n${BOLD}Troubleshooting:${RESET}"
echo -e "  View config:  ${DIM}cat $OPENCODE_CONFIG${RESET}"
echo -e "  Edit config:  ${DIM}nano $OPENCODE_CONFIG${RESET}"
echo -e "  Check server: ${DIM}curl http://localhost:4000/health${RESET}"

echo ""
