#!/bin/bash
# =====================================================================
#   Test Script for MLX-LM + LiteLLM Setup
#   Verifies both servers are working correctly
# =====================================================================

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

MLX_PORT=8080
LITELLM_PORT=4000

echo -e "${BLUE}${BOLD}Testing MLX-LM + LiteLLM Setup${RESET}\n"

# Test 1: Check if ports are listening
echo -e "${YELLOW}[1/5]${RESET} Checking if servers are running..."
if lsof -Pi :$MLX_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${RESET} MLX-LM server listening on port $MLX_PORT"
else
    echo -e "  ${RED}✗${RESET} MLX-LM server not running on port $MLX_PORT"
    echo -e "  ${YELLOW}→${RESET} Run './start.sh' first"
    exit 1
fi

if lsof -Pi :$LITELLM_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${RESET} LiteLLM proxy listening on port $LITELLM_PORT"
else
    echo -e "  ${RED}✗${RESET} LiteLLM proxy not running on port $LITELLM_PORT"
    echo -e "  ${YELLOW}→${RESET} Run './start.sh' first"
    exit 1
fi

# Test 2: MLX-LM health check
echo -e "\n${YELLOW}[2/5]${RESET} Testing MLX-LM endpoint..."
MLX_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$MLX_PORT/v1/models" 2>/dev/null)
if [ "$MLX_RESPONSE" = "200" ]; then
    echo -e "  ${GREEN}✓${RESET} MLX-LM /v1/models endpoint responding (HTTP $MLX_RESPONSE)"
else
    echo -e "  ${RED}✗${RESET} MLX-LM endpoint failed (HTTP $MLX_RESPONSE)"
    exit 1
fi

# Test 3: LiteLLM health check
echo -e "\n${YELLOW}[3/5]${RESET} Testing LiteLLM health endpoint..."
LITELLM_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$LITELLM_PORT/health" 2>/dev/null)
if [ "$LITELLM_RESPONSE" = "200" ]; then
    echo -e "  ${GREEN}✓${RESET} LiteLLM /health endpoint responding (HTTP $LITELLM_RESPONSE)"
else
    echo -e "  ${RED}✗${RESET} LiteLLM health check failed (HTTP $LITELLM_RESPONSE)"
    exit 1
fi

# Test 4: LiteLLM models endpoint
echo -e "\n${YELLOW}[4/5]${RESET} Testing LiteLLM models endpoint..."
MODELS_JSON=$(curl -s "http://localhost:$LITELLM_PORT/v1/models" 2>/dev/null)
if echo "$MODELS_JSON" | grep -q "claude-coder-fake"; then
    echo -e "  ${GREEN}✓${RESET} Model 'claude-coder-fake' is available"
    echo -e "  ${BLUE}→${RESET} Models: $(echo "$MODELS_JSON" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | tr '\n' ', ' | sed 's/,$//')"
else
    echo -e "  ${RED}✗${RESET} Model 'claude-coder-fake' not found"
    echo -e "  ${YELLOW}→${RESET} Response: $MODELS_JSON"
    exit 1
fi

# Test 5: Simple completion test
echo -e "\n${YELLOW}[5/5]${RESET} Testing completion endpoint..."
COMPLETION_RESPONSE=$(curl -s -X POST "http://localhost:$LITELLM_PORT/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test" \
  -d '{
    "model": "claude-coder-fake",
    "messages": [{"role": "user", "content": "Say hello in one word"}],
    "max_tokens": 10,
    "temperature": 0.5
  }' 2>/dev/null)

if echo "$COMPLETION_RESPONSE" | grep -q "content"; then
    CONTENT=$(echo "$COMPLETION_RESPONSE" | grep -o '"content":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo -e "  ${GREEN}✓${RESET} Completion successful"
    echo -e "  ${BLUE}→${RESET} Response: $CONTENT"
else
    echo -e "  ${RED}✗${RESET} Completion failed"
    echo -e "  ${YELLOW}→${RESET} Response: $COMPLETION_RESPONSE"
    exit 1
fi

# Summary
echo -e "\n${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  All tests passed! ✓${RESET}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}\n"

echo -e "${BOLD}Configuration for OpenCode:${RESET}"
echo -e "  API Base URL: ${BLUE}http://localhost:$LITELLM_PORT${RESET}"
echo -e "  Model: ${BLUE}claude-coder-fake${RESET}"
echo -e "  API Key: ${BLUE}any-value-works${RESET}"

echo -e "\n${BOLD}Test completion:${RESET}"
echo -e "  ${BLUE}curl -X POST http://localhost:$LITELLM_PORT/v1/chat/completions \\${RESET}"
echo -e "    ${BLUE}-H 'Content-Type: application/json' \\${RESET}"
echo -e "    ${BLUE}-H 'Authorization: Bearer test' \\${RESET}"
echo -e "    ${BLUE}-d '{\"model\":\"claude-coder-fake\",\"messages\":[{\"role\":\"user\",\"content\":\"Write hello world in Python\"}]}'${RESET}"

echo ""
