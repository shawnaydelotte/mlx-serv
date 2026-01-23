#!/bin/bash

# benchmark.sh - Compare 3B vs 7B model performance

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

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
sleep 10

# Warm up
curl -s -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "$PROMPT" > /dev/null

# Benchmark 7B (3 runs)
TIMES_7B=()
for i in {1..3}; do
    START=$(date +%s%N)
    curl -s -X POST http://localhost:4000/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d "$PROMPT" > /tmp/response_7b.json
    END=$(date +%s%N)
    ELAPSED=$(( (END - START) / 1000000 ))
    TIMES_7B+=($ELAPSED)
    echo "Run $i: ${ELAPSED}ms"
done

# Calculate average
AVG_7B=$(( (${TIMES_7B[0]} + ${TIMES_7B[1]} + ${TIMES_7B[2]}) / 3 ))
TOKENS_7B=$(jq '.usage.completion_tokens' /tmp/response_7b.json)
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
sleep 10

# Warm up
curl -s -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "$PROMPT" > /dev/null

# Benchmark 3B (3 runs)
TIMES_3B=()
for i in {1..3}; do
    START=$(date +%s%N)
    curl -s -X POST http://localhost:4000/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d "$PROMPT" > /tmp/response_3b.json
    END=$(date +%s%N)
    ELAPSED=$(( (END - START) / 1000000 ))
    TIMES_3B+=($ELAPSED)
    echo "Run $i: ${ELAPSED}ms"
done

# Calculate average
AVG_3B=$(( (${TIMES_3B[0]} + ${TIMES_3B[1]} + ${TIMES_3B[2]}) / 3 ))
TOKENS_3B=$(jq '.usage.completion_tokens' /tmp/response_3b.json)
TOKPS_3B=$(( TOKENS_3B * 1000 / AVG_3B ))

echo "Average: ${AVG_3B}ms"
echo "Tokens: $TOKENS_3B"
echo "Speed: ${TOKPS_3B} tok/s"
echo ""

# Comparison
SPEEDUP=$(( (AVG_7B * 100) / AVG_3B ))
echo "Summary"
echo "======="
echo "7B Model: ${AVG_7B}ms, ${TOKPS_7B} tok/s"
echo "3B Model: ${AVG_3B}ms, ${TOKPS_3B} tok/s"
echo "Speedup: ${SPEEDUP}% (3B is $(( SPEEDUP - 100 ))% faster)"
echo ""

# Save results
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
