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

**See [docs/setup/OPENCODE-SETUP.md](docs/setup/OPENCODE-SETUP.md) for detailed integration guide.**

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
source mlx-env/bin/activate && PYTHONPATH=. pytest tests/ -v

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

**For OpenCode**: Use `http://localhost:4000` (or `/v1`) with model `claude-coder-fake` (7B / default). With `./start.sh --fast`, the primary alias is `claude-coder-fast` (3B).

## Configuration

LiteLLM configs in the repo:

| File | Used when | Primary model alias |
|------|-----------|---------------------|
| `config.optimized.yaml` | `./start.sh` (default) | `claude-coder-fake` → 7B |
| `config.3b.yaml` | `./start.sh --fast` | `claude-coder-fast` → 3B |
| `config.yaml` | setup.sh / manual | `claude-coder-fake` → 7B (conservative) |

All three also expose Claude name aliases (`claude-haiku-4-5`, etc.) that route to the same local model.

### Conservative Config (`config.yaml`)

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
stream: true          # Better UX
timeout: 300          # 5 min for complex tasks
```

`./start.sh` already loads `config.optimized.yaml` by default (7B quality mode).
`./start.sh --fast` loads `config.3b.yaml` (3B speed mode).

To force the conservative `config.yaml` instead:
```bash
# Edit start.sh CONFIG_FILE, or run litellm directly:
# litellm --config config.yaml --port 4000
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
├── setup.sh                   # Initial setup (deps + models)
├── start.sh                   # Start/stop/status/logs/restart
├── configure-opencode.sh      # OpenCode config helper
├── ralph-loop.sh              # Ralph Loop CLI entry point
├── test.sh / verify.sh        # Health checks / integration verify
├── benchmark.sh               # 3B vs 7B performance comparison
├── config.yaml                # Conservative LiteLLM config
├── config.optimized.yaml      # Default for ./start.sh (7B)
├── config.3b.yaml             # Used by ./start.sh --fast (3B)
├── ralph_loop/                # Autonomous iteration engine
├── mcp_servers/               # Web-search + git-intel MCP servers
├── tests/                     # Pytest suite (43 tests)
├── docs/                      # Guides and reference
├── qwen-coder-*-4bit/         # Downloaded models (gitignored)
├── mlx-env/                   # Python venv (gitignored)
└── .ralph/                    # Ralph Loop state (gitignored)
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
2. Configure OpenCode (writes `~/.config/opencode/config.json`):

```bash
./configure-opencode.sh --optimized   # recommended
# or: ./configure-opencode.sh         # default max_tokens/temperature
```

That sets Anthropic `baseURL` to `http://localhost:4000/v1` and model
`anthropic/claude-coder-fake` (maps to the local Qwen 7B via LiteLLM).

**For other Anthropic-compatible clients**, point the base URL at the proxy:
```bash
export ANTHROPIC_API_KEY="local"
export ANTHROPIC_BASE_URL="http://localhost:4000"
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

- **Automatic model selection:** keyword-based (3B for simple tasks, 7B for complex); override with `--model 3b|7b`
- **State persistence:** saves iteration state under `.ralph/state.json` (and `current-plan.md`)
- **CLI flags:** `--max-iterations N` (default 5), `--auto`, `--ralph-dir DIR`
- **Test Coverage:** 43 unit/integration tests under `tests/`

**Model alias note:** Ralph requests `claude-coder-fake` for 7B and `claude-coder-fast` for 3B.
Start the matching server mode (`./start.sh` vs `./start.sh --fast`) so the alias exists in LiteLLM.

### Known Limitations

Ralph Loop currently operates in **simulation mode**:
- Execute phase logs intent but doesn't modify files
- No tool calling (can't run git, tests, or read files)
- No codebase context analysis
- `--auto` / approval checkpoints are accepted by the CLI but interactive approval is not implemented yet (loop continues)

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

## Documentation

Complete documentation is available in the `docs/` directory:

### Setup & Installation
- [Complete Setup Guide](docs/setup/COMPLETE-SETUP.md) - Detailed installation instructions
- [OpenCode Setup](docs/setup/OPENCODE-SETUP.md) - Configuring OpenCode to use local models
- [Setup Complete Reference](docs/setup/SETUP-COMPLETE.md) - Post-installation checklist

### User Guides
- [Quick Start Guide](docs/guides/QUICKSTART.md) - Get up and running in 5 minutes
- [Usage Guide](docs/USAGE-GUIDE.md) - Complete usage documentation
- [Ralph Loop Guide](docs/RALPH-LOOP.md) - Autonomous iteration tutorial

### Reference
- [Architecture Overview](docs/reference/ARCHITECTURE.md) - System architecture and data flow
- [Model Aliases](docs/reference/MODEL-ALIASES.md) - Available model configurations
- [Project Status](docs/reference/STATUS.md) - Current capabilities and roadmap
- [Improvements](docs/reference/IMPROVEMENTS.md) - Enhancement ideas
- [File Inventory](docs/reference/FILES.txt) - Complete file listing

### Implementation Details
- [Ralph Loop Implementation](docs/RALPH-LOOP-IMPLEMENTATION.md) - Engine implementation summary
- [Implementation Summary](docs/IMPLEMENTATION-SUMMARY.md) - Full system implementation
- [Implementation Plans](docs/plans/) - Detailed development plans

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
