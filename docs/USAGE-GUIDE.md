# Usage Guide: MLX-Serv with MCP Servers

Quick reference for using the enhanced mlx-serv system with dual model support and MCP servers.

## Quick Start

```bash
# First time setup (downloads models, installs dependencies)
./setup.sh

# Start with 7B model (quality mode - default)
./start.sh

# Start with 3B model (fast mode)
./start.sh --fast

# Check server status
./start.sh --status

# View logs
./start.sh --logs

# Restart servers
./start.sh --restart

# Restart with 3B model
./start.sh --restart --fast

# Stop servers
./start.sh --stop
```

## Model Selection

### When to Use 7B Model (Quality)
- Complex architectural decisions
- Subtle bug debugging
- Code optimization
- API design
- Nuanced refactoring

**Command:** `./start.sh` (default)

**Performance:** ~150-200 tok/s on M2 Max

### When to Use 3B Model (Speed)
- Code completion
- Simple refactoring
- Test generation
- Documentation
- Formatting
- Quick iterations

**Command:** `./start.sh --fast`

**Performance:** ~300-400 tok/s on M2 Max (2-3x faster)

## Benchmarking

Compare 3B vs 7B performance on your system:

```bash
./benchmark.sh
```

This will:
1. Run 3 tests with the 7B model
2. Run 3 tests with the 3B model
3. Calculate averages and speedup
4. Generate `docs/PERFORMANCE.md` with results

**Note:** Takes ~5-10 minutes to complete.

## MCP Servers

MCP (Model Context Protocol) servers extend the local model with additional capabilities.

### Web Search Server

**Location:** `mcp_servers/web-search/server.py`

**Capabilities:**
- Search the web using DuckDuckGo
- Rate limited to 10 requests/minute
- Returns titles, URLs, and snippets

**Tool:** `search(query: str, max_results: int = 5)`

**Example Use Cases:**
- Finding documentation for libraries
- Checking latest package versions
- Researching error messages
- Looking up API references

**Logs:** `~/.ralph/mcp-web-search.log`

### Git Intelligence Server

**Location:** `mcp_servers/git-intel/server.py`

**Capabilities:**
- Analyze commit ranges
- Find files that change together
- Explain specific commits

**Tools:**

1. **analyze_changes(since_commit="HEAD~10")**
   - Analyzes changes in a commit range
   - Returns commit count, files changed, stats, authors

2. **find_related_files(file_path, limit=5)**
   - Finds files that frequently change with the given file
   - Uses co-change graph analysis
   - Useful for impact analysis

3. **explain_commit(sha)**
   - Detailed commit information
   - Per-file statistics and change types

**Example Use Cases:**
- Understanding recent changes before a bug
- Finding which tests to update when modifying a file
- Analyzing commit history for code review
- Impact analysis for refactoring

**Logs:** `~/.ralph/mcp-git-intel.log`

## Running MCP Servers

MCP servers run as separate processes and communicate via stdio or Unix sockets.

**Manual Testing (Web Search):**
```bash
source mlx-env/bin/activate
python mcp_servers/web-search/server.py
```

**Manual Testing (Git Intelligence):**
```bash
source mlx-env/bin/activate
python mcp_servers/git-intel/server.py
```

**With OpenCode:**
MCP servers integrate automatically when OpenCode is configured to use them via `.config/opencode/mcp.json`.

## Configuration Files

### Model Configurations

**config.optimized.yaml** (7B model - quality)
- Max tokens: 8192
- Temperature: 0.3
- Timeout: 300s
- Used by: `./start.sh`

**config.3b.yaml** (3B model - fast)
- Max tokens: 8192
- Temperature: 0.3
- Timeout: 180s (faster model needs less time)
- Used by: `./start.sh --fast`

### MCP Requirements

**mcp_servers/requirements.txt**
- MCP SDK and all server dependencies
- Installed by: `./setup.sh`

**Individual Server Requirements:**
- `mcp_servers/web-search/requirements.txt` - DuckDuckGo search
- `mcp_servers/git-intel/requirements.txt` - Git and graph analysis

## Troubleshooting

### Servers Won't Start

```bash
# Clean restart
./start.sh --stop
sleep 2
./start.sh
```

### Wrong Model Running

Check which config is loaded:
```bash
./start.sh --status
```

Look for "Config: config.optimized.yaml" (7B) or "Config: config.3b.yaml" (3B)

### MCP Server Errors

Check logs:
```bash
cat ~/.ralph/mcp-web-search.log
cat ~/.ralph/mcp-git-intel.log
```

### Out of Memory

1. Stop servers: `./start.sh --stop`
2. Close other apps
3. Use 3B model: `./start.sh --fast`

### Slow Performance

1. Run benchmark: `./benchmark.sh`
2. If 7B is too slow, switch to 3B: `./start.sh --restart --fast`
3. Check system resources with `./start.sh --status`

## API Endpoints

### MLX-LM Server (Backend)
- URL: `http://localhost:8080/v1`
- Format: OpenAI-compatible
- Direct model access

### LiteLLM Proxy (Frontend)
- URL: `http://localhost:4000`
- Format: Anthropic-compatible
- Model routing and aliasing
- Health: `http://localhost:4000/health`
- Models: `http://localhost:4000/v1/models`

### Model Aliases

All these names point to the currently running model:
- `claude-coder-fake` (primary name for 7B)
- `claude-coder-fast` (primary name for 3B)
- `claude-haiku-4-5`
- `claude-3-5-sonnet-20241022`
- `claude-3-5-haiku-20241022`

## Integration with OpenCode

Configure OpenCode to use the local server:

```bash
./configure-opencode.sh --optimized
```

This sets:
- API base: `http://localhost:4000/v1`
- Model: `claude-coder-fake`
- Context window: 8192 tokens

## Advanced Usage

### Switching Models On-The-Fly

```bash
# Currently running 7B, want to switch to 3B
./start.sh --restart --fast

# Switch back to 7B
./start.sh --restart
```

### Custom Benchmarking

Edit `benchmark.sh` to:
- Change the test prompt
- Adjust max_tokens
- Modify number of runs
- Test different scenarios

### MCP Server Development

To add a new MCP server:

1. Create directory: `mcp_servers/my-server/`
2. Add requirements: `mcp_servers/my-server/requirements.txt`
3. Create server: `mcp_servers/my-server/server.py`
4. Extend `BaseMCPServer`
5. Register tools with `@self.server.call_tool()` decorator
6. Update `mcp_servers/requirements.txt`

See existing servers for examples.

## Performance Tips

1. **Keep servers running** between sessions (avoid cold starts)
2. **Use 3B for iteration** when speed matters more than quality
3. **Use 7B for final polish** when quality is critical
4. **Close other apps** if memory is tight
5. **First request is slow** (~30s warm-up) - this is normal

## File Locations

**Configuration:**
- `/Users/s/Projects/mlx-serv/config.optimized.yaml` - 7B config
- `/Users/s/Projects/mlx-serv/config.3b.yaml` - 3B config
- `~/.config/opencode/config.json` - OpenCode config

**Logs:**
- `/Users/s/Projects/mlx-serv/mlx_server.log` - MLX-LM server
- `/Users/s/Projects/mlx-serv/litellm_proxy.log` - LiteLLM proxy
- `~/.ralph/mcp-web-search.log` - Web search MCP
- `~/.ralph/mcp-git-intel.log` - Git intelligence MCP

**Models:**
- `/Users/s/Projects/mlx-serv/qwen-coder-7b-4bit/` - 7B model (~4-5GB)
- `/Users/s/Projects/mlx-serv/qwen-coder-3b-4bit/` - 3B model (~3.2GB)

**Process Tracking:**
- `/Users/s/Projects/mlx-serv/.server_pids` - Running server PIDs

## Getting Help

```bash
# Show all start.sh options
./start.sh --help

# View full documentation
cat README.md

# Quick reference
cat QUICKSTART.md

# OpenCode integration
cat OPENCODE-SETUP.md

# Performance benchmarks
cat docs/PERFORMANCE.md

# Implementation details
cat docs/IMPLEMENTATION-SUMMARY.md
```

## Summary of Commands

```bash
# Setup (one time)
./setup.sh

# Start/Stop
./start.sh              # Start with 7B (quality)
./start.sh --fast       # Start with 3B (speed)
./start.sh --stop       # Stop all servers
./start.sh --restart    # Restart with same model
./start.sh --status     # Check server status
./start.sh --logs       # View server logs

# Testing
./test.sh               # Run health checks
./benchmark.sh          # Performance comparison

# Configuration
./configure-opencode.sh --optimized  # Configure OpenCode

# MCP Servers (manual)
python mcp_servers/web-search/server.py
python mcp_servers/git-intel/server.py
```
