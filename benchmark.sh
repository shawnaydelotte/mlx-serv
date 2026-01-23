#!/bin/bash

# benchmark.sh - Compare 3B vs 7B model performance

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check dependencies
for cmd in curl jq sysctl; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: Required command '$cmd' not found"
        exit 1
    fi
done

# Cleanup on exit
cleanup() {
    rm -f /tmp/response_7b.json /tmp/response_3b.json
}
trap cleanup EXIT

echo "Model Performance Benchmark"
echo "==========================="
echo ""

# Test prompt
PROMPT='{"model": "claude-coder-fake", "messages": [{"role": "user", "content": "Write a Python function that calculates the Fibonacci sequence up to n terms using dynamic programming."}], "max_tokens": 500}'

echo "Testing 7B model..."
echo "-------------------"

# Start 7B
./start.sh --stop > /dev/null 2>&1
./start.sh > /dev/null 2>&1 &
echo "Waiting for server..."
for i in {1..30}; do
    if curl -s http://localhost:4000/health > /dev/null 2>&1; then
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Error: Server failed to start"
        exit 1
    fi
    sleep 1
done

# Warm up
curl -s -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "$PROMPT" > /dev/null || { echo "Error: curl failed"; exit 1; }

# Benchmark 7B (3 runs)
TIMES_7B=()
for i in {1..3}; do
    START=$(date +%s%N)
    curl -s -X POST http://localhost:4000/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d "$PROMPT" > /tmp/response_7b.json || { echo "Error: curl failed"; exit 1; }
    END=$(date +%s%N)
    ELAPSED=$(( (END - START) / 1000000 ))
    TIMES_7B+=($ELAPSED)
    echo "Run $i: ${ELAPSED}ms"
done

# Calculate average
AVG_7B=$(( (${TIMES_7B[0]} + ${TIMES_7B[1]} + ${TIMES_7B[2]}) / 3 ))
TOKENS_7B=$(jq -r '.usage.completion_tokens // empty' /tmp/response_7b.json)
if [ -z "$TOKENS_7B" ] || [ "$TOKENS_7B" = "null" ]; then
    echo "Error: Failed to extract token count from 7B response"
    exit 1
fi
if [ "$AVG_7B" -eq 0 ]; then
    echo "Error: 7B average latency is zero"
    exit 1
fi
TOKPS_7B=$(( TOKENS_7B * 1000 / AVG_7B ))

echo "Average: ${AVG_7B}ms"
echo "Tokens: $TOKENS_7B"
echo "Speed: ${TOKPS_7B} tok/s"
echo ""

echo "Testing 3B model..."
echo "-------------------"

# Start 3B
./start.sh --stop > /dev/null 2>&1
./start.sh --fast > /dev/null 2>&1 &
echo "Waiting for server..."
for i in {1..30}; do
    if curl -s http://localhost:4000/health > /dev/null 2>&1; then
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Error: Server failed to start"
        exit 1
    fi
    sleep 1
done

# Warm up
curl -s -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "$PROMPT" > /dev/null || { echo "Error: curl failed"; exit 1; }

# Benchmark 3B (3 runs)
TIMES_3B=()
for i in {1..3}; do
    START=$(date +%s%N)
    curl -s -X POST http://localhost:4000/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d "$PROMPT" > /tmp/response_3b.json || { echo "Error: curl failed"; exit 1; }
    END=$(date +%s%N)
    ELAPSED=$(( (END - START) / 1000000 ))
    TIMES_3B+=($ELAPSED)
    echo "Run $i: ${ELAPSED}ms"
done

# Calculate average
AVG_3B=$(( (${TIMES_3B[0]} + ${TIMES_3B[1]} + ${TIMES_3B[2]}) / 3 ))
TOKENS_3B=$(jq -r '.usage.completion_tokens // empty' /tmp/response_3b.json)
if [ -z "$TOKENS_3B" ] || [ "$TOKENS_3B" = "null" ]; then
    echo "Error: Failed to extract token count from 3B response"
    exit 1
fi
if [ "$AVG_3B" -eq 0 ]; then
    echo "Error: 3B average latency is zero"
    exit 1
fi
TOKPS_3B=$(( TOKENS_3B * 1000 / AVG_3B ))

echo "Average: ${AVG_3B}ms"
echo "Tokens: $TOKENS_3B"
echo "Speed: ${TOKPS_3B} tok/s"
echo ""

# Comparison
if [ "$AVG_3B" -eq 0 ]; then
    echo "Error: Cannot calculate speedup (3B latency is zero)"
    exit 1
fi
SPEEDUP=$(( (AVG_7B * 100) / AVG_3B ))
echo "Summary"
echo "======="
echo "7B Model: ${AVG_7B}ms, ${TOKPS_7B} tok/s"
echo "3B Model: ${AVG_3B}ms, ${TOKPS_3B} tok/s"
echo "Speedup: ${SPEEDUP}% (3B is $(( SPEEDUP - 100 ))% faster)"
echo ""

# Save results
mkdir -p docs
if [ "$TOKPS_7B" -eq 0 ]; then
    echo "Error: Cannot calculate token speedup (7B tok/s is zero)"
    exit 1
fi
cat > docs/PERFORMANCE.md << EOF
# Performance Benchmarks

Last updated: $(date +%Y-%m-%d)

## Model Comparison

| Metric | 7B Model | 3B Model | Speedup |
|--------|----------|----------|---------|
| Avg Latency | ${AVG_7B}ms | ${AVG_3B}ms | ${SPEEDUP}% |
| Tokens/sec | ${TOKPS_7B} | ${TOKPS_3B} | $(( TOKPS_3B * 100 / TOKPS_7B ))% |
| Memory | ~4GB | ~2GB | 50% |

## Test Configuration

- Prompt: "Write a Python function that calculates the Fibonacci sequence..."
- Max tokens: 500
- Runs per model: 3
- System: $(sysctl -n machdep.cpu.brand_string)
- RAM: $(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)"GB"}')

## Recommendations

**Use 7B when:**
- Complex architectural decisions
- Subtle bug debugging
- Code optimization
- API design

**Use 3B when:**
- Code completion
- Simple refactoring
- Test generation
- Documentation
- Formatting

## Raw Results

### 7B Model
- Run 1: ${TIMES_7B[0]}ms
- Run 2: ${TIMES_7B[1]}ms
- Run 3: ${TIMES_7B[2]}ms

### 3B Model
- Run 1: ${TIMES_3B[0]}ms
- Run 2: ${TIMES_3B[1]}ms
- Run 3: ${TIMES_3B[2]}ms
EOF

echo "Results saved to docs/PERFORMANCE.md"
