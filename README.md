# MLX-LM Local Coding Model Server

🚀 Run local coding models on Apple Silicon with an Anthropic-compatible API for use with OpenCode and other tools.

## Overview

This setup runs **Qwen2.5-Coder** models (4-bit quantized) on Apple Silicon using:
- **MLX**: Apple's ML framework optimized for M-series chips
- **mlx-lm**: Server for running LLMs with MLX
- **LiteLLM**: Proxy that provides Anthropic/OpenAI-compatible API endpoints

### Key Features

- **Dual Model Support**: 7B (quality) and 3B (speed) models with easy switching
- **Ralph Loop**: Autonomous iteration engine for coding tasks
- **MCP Servers**: Web search and git intelligence integrations
- **Complete Testing**: 43 tests covering all components
- **Production Ready**: Fully documented with known limitations

## System Requirements

- **Hardware**: Apple Silicon Mac (M1/M2/M3/M4)
- **Memory**: 8GB+ RAM recommended (model uses ~4GB)
- **OS**: macOS 12.0+ (Monterey or later)
- **Storage**: ~5GB for model and dependencies

## Quick Start

### 1. Initial Setup (One-time)

```bash
# Run the setup script to install dependencies and download model
./setup.sh
```

This will:
- Install Python 3.12 via Homebrew
- Create virtual environment in `./mlx-env`
- Install mlx-lm and litellm packages
- Download and quantize Qwen2.5-Coder-7B model to 4-bit

**Note**: First-time setup takes 15-30 minutes (model download is ~3GB).

### 2. Start Servers

```bash
# Start with beautiful status display
./start.sh
```

You'll see:
- ✓ System requirements check
- ✓ MLX-LM server startup with logs
- ✓ LiteLLM proxy startup with logs
- ✓ Health checks for both services
- 🚀 Ready to use!

### 3. Configure OpenCode

Automatically configure OpenCode to use your local server:

```bash
# Recommended: Use optimized settings for better code generation
./configure-opencode.sh --optimized

# Or use default settings
./configure-opencode.sh
```

This configures OpenCode at `~/.config/opencode/config.json` with:
- API URL: `http://localhost:4000/v1`
- Model: `claude-coder-fake`
- Optimized parameters for code generation

**See [OPENCODE-SETUP.md](OPENCODE-SETUP.md) for detailed integration guide.**

## Commands

```bash
# Server Management
./start.sh                   # Start servers (7B model - quality)
./start.sh --fast            # Start servers (3B model - speed)
./start.sh --status          # Check if servers are running
./start.sh --logs            # View live logs
./start.sh --stop            # Stop all servers
./start.sh --restart         # Restart servers
./start.sh --restart --fast  # Restart with 3B model

# Configuration
./configure-opencode.sh      # Configure OpenCode (default)
./configure-opencode.sh --optimized  # Configure OpenCode (optimized)

# Testing & Verification
./test.sh                    # Run health checks
./verify.sh                  # Integration verification
source mlx-env/bin/activate && PYTHONPATH=/Users/s/Projects/mlx-serv pytest tests/ -v

# Ralph Loop
./ralph-loop.sh "task"       # Autonomous iteration
./ralph-loop.sh --help       # Show Ralph Loop options

# Help
./start.sh --help            # Show help
```

## Endpoints

Once running, you have two endpoints:

| Service | URL | Purpose |
|---------|-----|---------|
| MLX-LM Backend | http://localhost:8080/v1 | Direct model access (OpenAI-compatible) |
| LiteLLM Proxy | http://localhost:4000 | Anthropic-compatible API |

**For OpenCode**: Use `http://localhost:4000` with model `claude-coder-fake`

## Configuration

### Default Config (`config.yaml`)

Basic configuration with conservative settings:
```yaml
max_tokens: 4096
temperature: 0.7
```

### Optimized Config (`config.optimized.yaml`)

Enhanced for code generation:
```yaml
max_tokens: 8192      # Longer outputs
temperature: 0.3      # More focused
streaming: true       # Better UX
timeout: 300          # 5 min for complex tasks
```

To use optimized config:
```bash
# Replace config.yaml with optimized version
cp config.optimized.yaml config.yaml
./start.sh --restart
```

## Testing

### Test MLX-LM Backend
```bash
curl http://localhost:8080/v1/models
```

### Test LiteLLM Proxy
```bash
# Health check
curl http://localhost:4000/health

# List models
curl http://localhost:4000/v1/models
```

### Test Completion
```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer dummy-key" \
  -d '{
    "model": "claude-coder-fake",
    "messages": [{"role": "user", "content": "Write a Python function to check if a number is prime"}],
    "max_tokens": 500
  }'
```

## Performance Tips

### Memory Management

The model uses ~4-5GB of RAM. If you experience issues:

1. **Close other applications** before starting
2. **Restart servers** if memory usage grows: `./start.sh --restart`
3. **Monitor memory** in Activity Monitor

### Speed Optimization

1. **Use streaming**: Set `stream: true` in config for faster perceived response
2. **Lower temperature**: 0.2-0.3 for code (faster, more deterministic)
3. **Reduce max_tokens**: Start with 4096, increase only if needed
4. **Keep model warm**: Don't stop/start frequently (cold start is slow)

### Model Selection

This setup uses **Qwen2.5-Coder-7B-4bit** for a good balance:
- **4-bit quantization**: Faster inference, lower memory (~4GB vs 14GB)
- **7B parameters**: Good quality while fitting in consumer hardware
- **Coder variant**: Optimized for programming tasks

To use a different model, edit `setup.sh` line 35:
```bash
mlx_lm.convert --hf-path <model-name> --mlx-path <output-dir> --q-bits 4
```

Popular alternatives:
- `Qwen/Qwen2.5-Coder-14B-Instruct` (needs 16GB+ RAM, better quality)
- `Qwen/Qwen2.5-Coder-3B-Instruct` (needs 2GB RAM, faster but less capable)
- `deepseek-ai/deepseek-coder-6.7b-instruct` (alternative coder model)

## Troubleshooting

### Servers won't start

```bash
# Check if ports are in use
lsof -i :8080
lsof -i :4000

# Kill conflicting processes
./start.sh --stop

# Check logs for errors
cat mlx_server.log
cat litellm_proxy.log
```

### Out of Memory

```bash
# Free up RAM
./start.sh --stop

# Close other apps, then restart
./start.sh
```

### Slow responses

1. First request is slow (model loading) - normal
2. Check CPU usage in Activity Monitor
3. Ensure no other ML workloads running
4. Consider using smaller model (3B variant)

### Connection refused

```bash
# Check if servers are actually running
./start.sh --status

# Restart if needed
./start.sh --restart
```

## Project Structure

```
mlx-serv/
├── setup.sh                   # Initial setup script
├── start.sh                   # Enhanced startup script ⭐
├── run.sh                     # Legacy startup script
├── config.yaml                # LiteLLM configuration
├── config.optimized.yaml      # Optimized config for code
├── qwen-coder-7b-4bit/        # Downloaded model files
├── mlx-env/                   # Python virtual environment
├── mlx_server.log             # MLX-LM logs
├── litellm_proxy.log          # LiteLLM logs
└── .server_pids               # Process IDs (auto-generated)
```

## Advanced Usage

### Custom Model Parameters

Edit `config.yaml` to tune model behavior:

```yaml
temperature: 0.3      # Lower = more focused (0.0-1.0)
top_p: 0.9           # Nucleus sampling (0.0-1.0)
frequency_penalty: 0.1  # Reduce repetition
presence_penalty: 0.1   # Encourage variety
max_tokens: 8192     # Max output length
```

### Multiple Models

To serve multiple models simultaneously:

1. Convert additional models:
```bash
source ./mlx-env/bin/activate
mlx_lm.convert --hf-path <model> --mlx-path ./model2 --q-bits 4
```

2. Start on different port:
```bash
python -m mlx_lm.server --model ./model2 --port 8081 &
```

3. Add to `config.yaml`:
```yaml
model_list:
  - model_name: claude-coder-fake
    litellm_params:
      model: openai/Qwen2.5-Coder-7B-Instruct-4bit
      api_base: http://localhost:8080/v1

  - model_name: model2
    litellm_params:
      model: openai/other-model
      api_base: http://localhost:8081/v1
```

### Monitoring

View real-time logs with color-coded output:
```bash
./start.sh --logs
```

Or manually:
```bash
# MLX-LM only
tail -f mlx_server.log

# LiteLLM only
tail -f litellm_proxy.log

# Both
tail -f mlx_server.log litellm_proxy.log
```

### Auto-start on Boot

To run servers automatically when you log in:

1. Create a launchd plist file
2. Or add to your shell profile:
```bash
# Add to ~/.zshrc or ~/.bashrc
alias start-mlx='cd /path/to/mlx-serv && ./start.sh'
```

## OpenCode Integration

### Setup

1. Install OpenCode (or your preferred tool)
2. Configure to use local endpoint:

**Environment variables:**
```bash
export ANTHROPIC_API_KEY="local"
export ANTHROPIC_BASE_URL="http://localhost:4000"
```

**Or config file:**
```json
{
  "apiProvider": "anthropic",
  "apiBaseUrl": "http://localhost:4000",
  "apiKey": "local",
  "model": "claude-coder-fake"
}
```

### Usage Tips

1. **Start servers first**: Always run `./start.sh` before using OpenCode
2. **Keep warm**: Leave servers running between sessions
3. **Monitor logs**: Use `./start.sh --logs` to debug issues
4. **Restart if stuck**: `./start.sh --restart` if responses hang

## Ralph Loop - Autonomous Iteration

Ralph Loop enables autonomous iteration on coding tasks through Plan → Execute → Review → Refine cycles.

### Quick Start

```bash
# Fix a bug
./ralph-loop.sh "Fix authentication timeout in login.py"

# Generate tests (uses fast 3B model)
./ralph-loop.sh --model 3b "Add unit tests for API endpoints"

# Refactor code (uses quality 7B model)
./ralph-loop.sh --model 7b "Refactor database queries for performance"
```

### How It Works

1. **Plan:** Model analyzes task and generates implementation steps
2. **Execute:** Model executes steps (currently simulation mode)
3. **Review:** Validates results against success criteria
4. **Refine:** If not done, refine plan and iterate (max 5 iterations)

### Features

- **Automatic model selection:** 3B for simple tasks, 7B for complex
- **State persistence:** Resume from checkpoints in `.ralph/` directory
- **User control:** Approval checkpoints every 2 iterations
- **Max iteration safety:** Prevents infinite loops (5 max iterations)
- **Test Coverage:** 43/43 tests passing

### Known Limitations

Ralph Loop currently operates in **simulation mode**:
- Execute phase logs intent but doesn't modify files
- No tool calling (can't run git, tests, or read files)
- No codebase context analysis

**Future:** Integration with OpenCode tool calling for real execution.

See [docs/RALPH-LOOP.md](docs/RALPH-LOOP.md) for complete tutorial and examples.

## MCP Servers - Extended Capabilities

MCP (Model Context Protocol) servers provide additional capabilities to local models.

### Web Search Server

**Location:** `mcp_servers/web-search/server.py`

**Features:**
- DuckDuckGo search integration
- Rate limiting (10 requests/minute)
- Returns titles, URLs, and snippets

**Use Cases:**
- Finding documentation
- Checking package versions
- Researching error messages
- API reference lookup

### Git Intelligence Server

**Location:** `mcp_servers/git-intel/server.py`

**Features:**
- Analyze commit ranges
- Find files that change together (co-change analysis)
- Explain specific commits

**Use Cases:**
- Understanding recent changes
- Impact analysis for refactoring
- Finding related test files
- Code review preparation

**Note:** MCP servers are not yet integrated with Ralph Loop but can be used standalone.

See [docs/USAGE-GUIDE.md](docs/USAGE-GUIDE.md) for complete MCP server documentation.

## FAQ

**Q: Can I use this with Claude Code?**
A: Yes! Configure Claude Code to use `http://localhost:4000` as the API endpoint.

**Q: Does this work offline?**
A: Yes, once the model is downloaded, no internet connection is needed.

**Q: How does this compare to cloud APIs?**
A: Pros: Free, private, offline. Cons: Slower, less capable than Claude/GPT-4.

**Q: Can I use this on Intel Mac?**
A: No, MLX requires Apple Silicon (M1/M2/M3/M4).

**Q: Is my code private?**
A: Yes! Everything runs locally. No data leaves your machine.

**Q: Can I use different models?**
A: Yes! Edit `setup.sh` to download any HuggingFace model compatible with mlx-lm.

## Contributing

To improve this setup:

1. Test different models and document results
2. Optimize configurations for specific use cases
3. Add support for more features (embeddings, function calling)
4. Improve error handling and logging

## License

This setup uses:
- MLX (Apple): MIT License
- mlx-lm: MIT License
- LiteLLM: MIT License
- Qwen2.5-Coder: Apache 2.0 License

## Resources

- [MLX Documentation](https://ml-explore.github.io/mlx/)
- [mlx-lm GitHub](https://github.com/ml-explore/mlx-examples/tree/main/llms)
- [LiteLLM Documentation](https://docs.litellm.ai/)
- [Qwen2.5-Coder Models](https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct)
- [OpenCode Documentation](https://github.com/opencode-ai/opencode)

## Support

Issues? Check:
1. Logs: `cat mlx_server.log litellm_proxy.log`
2. Status: `./start.sh --status`
3. Requirements: Ensure Apple Silicon, 8GB+ RAM, macOS 12+

For bugs in this setup, open an issue with logs attached.

---

**Made with ❤️ for local AI development**
