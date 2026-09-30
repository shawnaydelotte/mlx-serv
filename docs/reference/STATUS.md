# MLX-Serv Project Status

**Last Updated:** 2026-01-24
**Version:** 1.0.0 (project status doc); `ralph_loop.__version__` is `0.1.0`
**Status:** ✅ Production Ready (with documented limitations)

## What Works

### ✅ Core Infrastructure
- **MLX-LM Server:** Serves Qwen2.5-Coder models locally via MLX
- **LiteLLM Proxy:** Anthropic-compatible API on port 4000
- **Model Support:** Both 7B (quality) and 3B (speed) models
- **Auto Switching:** `./start.sh --fast` for 3B model

### ✅ Ralph Loop Engine
- **Autonomous Iteration:** Plan → Execute → Review → Refine cycles
- **Model Selection:** Auto-selects 3B vs 7B based on task complexity
- **State Persistence:** Iteration state in `.ralph/state.json` (re-run continues counting; no `--resume` flag)
- **CLI Interface:** `./ralph-loop.sh "task description"`
- **Test Coverage:** 43/43 tests passing

### ✅ MCP Servers
- **Web Search:** DuckDuckGo integration with rate limiting
- **Git Intelligence:** Repository analysis, co-change detection
- **Base Infrastructure:** Common MCP server framework

### ✅ Documentation
- Complete setup guides (README, QUICKSTART, USAGE-GUIDE)
- Ralph Loop tutorial with examples
- Implementation summaries with metrics
- Troubleshooting guides

## Known Limitations

### Ralph Loop (Documented)
1. **Simulation Mode:** Execute phase logs intent but doesn't modify files
2. **No Tool Calling:** Can't actually run git, tests, or read files
3. **No Codebase Context:** Doesn't analyze project structure

**Future:** Integrate OpenCode tool calling for real execution.

### MCP Servers
- **Not integrated with Ralph Loop:** MCP servers exist but Ralph Loop doesn't use them yet

**Future:** Connect Ralph Loop to MCP servers for web search and git intelligence.

## Performance

**Model Inference (M2 Max):**
- 7B model: ~170 tok/s (quality mode)
- 3B model: ~300-400 tok/s (speed mode)

**Ralph Loop Iteration:**
- Simple tasks: 1-2 iterations (< 2 min with 3B)
- Medium tasks: 2-4 iterations (< 5 min with 7B)
- Complex tasks: 3-5 iterations (< 8 min with 7B)

## Usage

### Quick Start
```bash
# First time setup
./setup.sh

# Start servers (7B model)
./start.sh

# Start with 3B model (faster)
./start.sh --fast

# Use Ralph Loop
./ralph-loop.sh "task description"

# Verify everything works
./verify.sh
```

### Common Operations
```bash
# Check server status
./start.sh --status

# Restart with different model
./start.sh --restart --fast

# Stop servers
./start.sh --stop

# Run health checks
./test.sh

# Run tests
source mlx-env/bin/activate
PYTHONPATH=. pytest tests/ -v
```

## Project Structure

```
mlx-serv/
├── ralph_loop/          # Ralph Loop engine (759 LOC)
├── mcp_servers/         # MCP infrastructure + servers
├── tests/               # Test suite (43 pytest functions)
├── docs/                # Documentation (1200+ LOC)
├── *.sh                 # Scripts (setup, start, ralph-loop, verify, test)
└── config*.yaml         # LiteLLM configurations
```

## Dependencies

**Runtime:**
- Python 3.12+
- MLX framework (Apple Silicon only)
- Anthropic SDK
- LiteLLM
- MCP SDK

**All installed by `./setup.sh`**

## Future Enhancements

### Short-term
1. Integrate Ralph Loop with MCP servers
2. Add real file execution to Ralph Loop
3. Improve error messages and user prompts

### Medium-term
4. Web dashboard for monitoring
5. Enhanced setup with hardware detection
6. Iteration logging to files

### Long-term
7. Multi-file awareness and dependency graphs
8. Learning from failures across iterations
9. Parallel execution of independent steps

## Support

- **Documentation:** See `README.md`, `docs/USAGE-GUIDE.md`
- **Issues:** File in project repository
- **Tests:** Run `./verify.sh` to check system health

## Version History

**v1.0.0** (2026-01-24)
- ✅ Ralph Loop Engine complete
- ✅ Dual model support (3B/7B)
- ✅ MCP servers (web-search, git-intel)
- ✅ Complete documentation
- ✅ 43/43 tests passing
