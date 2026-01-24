#!/bin/bash

# MLX-Serv Integration Verification

set -e

echo "🔍 MLX-Serv Integration Verification"
echo "======================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Check virtual environment
echo -n "Checking virtual environment... "
if [ -d "mlx-env" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo "Run ./setup.sh first"
    exit 1
fi

# Activate venv
source mlx-env/bin/activate

# Check ralph_loop package
echo -n "Checking ralph_loop package... "
if python -c "import ralph_loop" 2>/dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    exit 1
fi

# Check MCP servers
echo -n "Checking MCP servers... "
if [ -f "mcp_servers/web-search/server.py" ] && [ -f "mcp_servers/git-intel/server.py" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    exit 1
fi

# Check models
echo -n "Checking 7B model... "
if [ -d "qwen-coder-7b-4bit" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC} (optional)"
fi

echo -n "Checking 3B model... "
if [ -d "qwen-coder-3b-4bit" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC} (optional)"
fi

# Run tests
echo -n "Running tests... "
if PYTHONPATH=/Users/s/Projects/mlx-serv pytest tests/ -q >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo "Run: PYTHONPATH=/Users/s/Projects/mlx-serv pytest tests/ -v"
    exit 1
fi

# Check scripts
echo -n "Checking executable scripts... "
if [ -x "start.sh" ] && [ -x "ralph-loop.sh" ] && [ -x "setup.sh" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ All checks passed!${NC}"
echo ""
echo "System ready. Try:"
echo "  ./start.sh              # Start servers"
echo "  ./ralph-loop.sh --help  # See Ralph Loop options"
echo "  ./test.sh               # Run health checks"
