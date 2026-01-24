#!/bin/bash

# Ralph Loop - Autonomous iteration engine entry point

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if virtual environment exists
if [ ! -d "mlx-env" ]; then
    echo -e "${RED}Error: Virtual environment not found${NC}"
    echo "Please run ./setup.sh first"
    exit 1
fi

# Activate virtual environment
source mlx-env/bin/activate

# Check if servers are running
if ! curl -s http://localhost:4000/health > /dev/null 2>&1; then
    echo -e "${YELLOW}Warning: LiteLLM server not running${NC}"
    echo "Starting servers..."
    ./start.sh

    # Wait for server to be ready
    for i in {1..30}; do
        if curl -s http://localhost:4000/health > /dev/null 2>&1; then
            echo -e "${GREEN}Servers ready!${NC}"
            break
        fi
        if [ $i -eq 30 ]; then
            echo -e "${RED}Error: Servers failed to start${NC}"
            exit 1
        fi
        sleep 1
    done
fi

# Run Ralph Loop
python -m ralph_loop.cli "$@"
