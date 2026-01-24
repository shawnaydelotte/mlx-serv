# Local Agentic Coding System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform mlx-serv into a complete local agentic coding environment with Ralph Loop autonomous iteration, MCP servers for web search/git/docs, dual model support (3B/7B), monitoring dashboard, and clone-and-go setup experience.

**Architecture:** Three-layer system: (1) User interfaces (OpenCode, CLI tools), (2) Orchestration layer (Ralph Loop engine, MCP servers, monitoring), (3) Model inference (LiteLLM proxy routing to MLX-LM serving Qwen 3B/7B models). All components communicate via HTTP/Unix sockets, state managed in `.ralph/` directory.

**Tech Stack:** Python 3.11+, MLX, LiteLLM, mlx-lm, MCP Python SDK, rich/textual (TUI), DuckDuckGo API, sentence-transformers, FAISS, OpenCode VS Code extension

---

## Phase 1: Dual Model Support

### Task 1: Download and Configure 3B Model

**Files:**
- Modify: `setup.sh:45-80` (add 3B model download)
- Create: `config.3b.yaml`
- Modify: `.gitignore:15-20` (add 3B model directory)

**Step 1: Update setup.sh to download 3B model**

Add after line 75 (after 7B model download):

```bash
echo ""
echo -e "${BLUE}Downloading Qwen2.5-Coder-3B-Instruct-4bit model...${NC}"
echo "This will take 5-8 minutes depending on connection speed."

if [ ! -d "qwen-coder-3b-4bit" ]; then
    python -c "
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id='mlx-community/Qwen2.5-Coder-3B-Instruct-4bit',
    local_dir='qwen-coder-3b-4bit',
    local_dir_use_symlinks=False
)
print('✓ 3B model downloaded successfully')
"
else
    echo -e "${GREEN}✓ 3B model already exists${NC}"
fi
```

**Step 2: Create config.3b.yaml**

```yaml
model_list:
  - model_name: claude-coder-fast
    litellm_params:
      model: openai/mlx-community/Qwen2.5-Coder-3B-Instruct-4bit
      api_base: http://localhost:8080/v1
      api_key: dummy-key-local
      # Optimized for speed with 3B model
      max_tokens: 8192
      temperature: 0.3
      top_p: 0.95
      frequency_penalty: 0.05
      presence_penalty: 0.05
      timeout: 180
      stream: true
    model_provider: openai
    model_info:
      mode: chat
      supports_function_calling: false
      supports_vision: false
      supports_streaming: true

  # Aliases pointing to 3B model
  - model_name: claude-haiku-4-5
    litellm_params:
      model: openai/mlx-community/Qwen2.5-Coder-3B-Instruct-4bit
      api_base: http://localhost:8080/v1
      api_key: dummy-key-local
      max_tokens: 8192
      temperature: 0.3
      top_p: 0.95
      frequency_penalty: 0.05
      presence_penalty: 0.05
      timeout: 180
      stream: true

  - model_name: claude-3-5-sonnet-20241022
    litellm_params:
      model: openai/mlx-community/Qwen2.5-Coder-3B-Instruct-4bit
      api_base: http://localhost:8080/v1
      api_key: dummy-key-local
      max_tokens: 8192
      temperature: 0.3
      top_p: 0.95
      frequency_penalty: 0.05
      presence_penalty: 0.05
      timeout: 180
      stream: true

  - model_name: claude-3-5-haiku-20241022
    litellm_params:
      model: openai/mlx-community/Qwen2.5-Coder-3B-Instruct-4bit
      api_base: http://localhost:8080/v1
      api_key: dummy-key-local
      max_tokens: 8192
      temperature: 0.3
      top_p: 0.95
      frequency_penalty: 0.05
      presence_penalty: 0.05
      timeout: 180
      stream: true

# General settings
general_settings:
  master_key: none
  set_verbose: false
  json_logs: true
  num_workers: 1
  request_timeout: 180
  allowed_origins:
    - http://localhost:*
    - http://127.0.0.1:*

# Router settings
router_settings:
  routing_strategy: simple-shuffle
  model_group_alias:
    claude-coder: claude-coder-fast
    qwen-coder: claude-coder-fast

# Litellm settings
litellm_settings:
  telemetry: false
  drop_params: true
  num_retries: 2
  retry_after: 5
  success_callback: []
  failure_callback: []
```

**Step 3: Update .gitignore**

Add to .gitignore:

```
# Models
qwen-coder-7b-4bit/
qwen-coder-3b-4bit/
```

**Step 4: Test 3B model setup**

Run:
```bash
./setup.sh
```

Expected: Downloads 3B model (~3.2GB), completes successfully

**Step 5: Commit**

```bash
git add setup.sh config.3b.yaml .gitignore
git commit -m "feat: add Qwen2.5-Coder-3B-Instruct-4bit model support

- Download 3B model in setup.sh
- Create config.3b.yaml for fast inference
- Update .gitignore for both model directories"
```

### Task 2: Add --fast Flag to start.sh

**Files:**
- Modify: `start.sh:1-50` (add --fast flag parsing)
- Modify: `start.sh:200-250` (update start_litellm_proxy function)

**Step 1: Add --fast flag to argument parsing**

Add after line 30 in start.sh:

```bash
# Parse command line arguments
FAST_MODE=false
CONFIG_FILE="config.optimized.yaml"

while [[ $# -gt 0 ]]; do
    case $1 in
        --fast)
            FAST_MODE=true
            CONFIG_FILE="config.3b.yaml"
            shift
            ;;
        --status)
            show_status
            exit 0
            ;;
        --stop)
            stop_servers
            exit 0
            ;;
        --restart)
            stop_servers
            sleep 2
            # Fall through to start servers
            ;;
        --logs)
            tail_logs
            exit 0
            ;;
        --dashboard)
            run_dashboard
            exit 0
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done
```

**Step 2: Update show_help function**

Modify show_help function (around line 100):

```bash
show_help() {
    echo "Usage: ./start.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  (no args)     Start MLX-LM and LiteLLM servers (7B model)"
    echo "  --fast        Start with 3B model for faster inference"
    echo "  --status      Show server status"
    echo "  --stop        Stop all servers"
    echo "  --restart     Restart all servers"
    echo "  --logs        Tail server logs"
    echo "  --dashboard   Launch monitoring dashboard"
    echo "  --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./start.sh              # Start with 7B model (quality)"
    echo "  ./start.sh --fast       # Start with 3B model (speed)"
    echo "  ./start.sh --dashboard  # Launch monitoring UI"
}
```

**Step 3: Update start_litellm_proxy to use CONFIG_FILE**

Modify start_litellm_proxy function (around line 230):

```bash
start_litellm_proxy() {
    echo ""
    echo -e "${BLUE}Starting LiteLLM proxy server...${NC}"

    if [ "$FAST_MODE" = true ]; then
        echo -e "${YELLOW}→ Using 3B model (fast mode)${NC}"
    else
        echo -e "${YELLOW}→ Using 7B model (quality mode)${NC}"
    fi

    cd "$SCRIPT_DIR"
    source mlx-env/bin/activate

    nohup litellm --config "$CONFIG_FILE" --port 4000 > litellm_proxy.log 2>&1 &
    LITELLM_PID=$!
    echo "$LITELLM_PID" >> "$PID_FILE"

    echo -e "${GREEN}✓ LiteLLM proxy started (PID: $LITELLM_PID)${NC}"
    echo -e "  Port: 4000"
    echo -e "  Config: $CONFIG_FILE"
}
```

**Step 4: Test --fast flag**

Run:
```bash
./start.sh --stop
./start.sh --fast
curl http://localhost:4000/v1/models
```

Expected: Shows claude-coder-fast model, responds faster than 7B

**Step 5: Commit**

```bash
git add start.sh
git commit -m "feat: add --fast flag for 3B model startup

- Add --fast command line flag
- Use config.3b.yaml when --fast is specified
- Update help text with fast mode documentation
- Show model selection in startup output"
```

### Task 3: Benchmark Both Models

**Files:**
- Create: `benchmark.sh`
- Create: `docs/PERFORMANCE.md`

**Step 1: Create benchmark script**

```bash
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
```

**Step 2: Make benchmark script executable**

Run:
```bash
chmod +x benchmark.sh
```

**Step 3: Run benchmark**

Run:
```bash
./benchmark.sh
```

Expected: Completes both benchmarks, creates docs/PERFORMANCE.md with results

**Step 4: Commit**

```bash
git add benchmark.sh docs/PERFORMANCE.md
git commit -m "feat: add model performance benchmarking

- Create benchmark.sh for 3B vs 7B comparison
- Test latency, tokens/sec, and speedup
- Generate docs/PERFORMANCE.md with results
- Include system information and recommendations"
```

---

## Phase 2: MCP Server Infrastructure

### Task 4: Set Up MCP Python SDK

**Files:**
- Create: `mcp-servers/requirements.txt`
- Create: `mcp-servers/base_server.py`
- Modify: `setup.sh:85-95` (install MCP dependencies)

**Step 1: Create MCP requirements file**

```txt
# mcp-servers/requirements.txt
mcp>=0.9.0
httpx>=0.27.0
aiofiles>=23.2.1
```

**Step 2: Create base MCP server class**

```python
# mcp-servers/base_server.py
"""Base MCP server with common functionality."""

import asyncio
import logging
import signal
import sys
from pathlib import Path
from typing import Optional

from mcp.server import Server
from mcp.server.stdio import stdio_server


class BaseMCPServer:
    """Base class for MCP servers with common setup."""

    def __init__(self, name: str, log_file: Optional[Path] = None):
        self.name = name
        self.server = Server(name)
        self.running = False

        # Set up logging
        if log_file:
            log_file.parent.mkdir(parents=True, exist_ok=True)
            logging.basicConfig(
                filename=str(log_file),
                level=logging.INFO,
                format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
        else:
            logging.basicConfig(
                level=logging.INFO,
                format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )

        self.logger = logging.getLogger(name)

        # Handle graceful shutdown
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)

    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully."""
        self.logger.info(f"Received signal {signum}, shutting down...")
        self.running = False
        sys.exit(0)

    async def run(self):
        """Run the MCP server."""
        self.running = True
        self.logger.info(f"Starting {self.name} MCP server...")

        async with stdio_server() as (read_stream, write_stream):
            await self.server.run(
                read_stream,
                write_stream,
                self.server.create_initialization_options()
            )

    def register_tool(self, func, name: str, description: str, parameters: dict):
        """Register a tool with the MCP server."""
        @self.server.call_tool()
        async def tool_handler(name: str, arguments: dict):
            if name == func.__name__:
                try:
                    result = await func(**arguments)
                    return result
                except Exception as e:
                    self.logger.error(f"Error in {name}: {e}")
                    raise

        self.server.list_tools.append({
            "name": name,
            "description": description,
            "inputSchema": {
                "type": "object",
                "properties": parameters,
                "required": list(parameters.keys())
            }
        })
```

**Step 3: Update setup.sh to install MCP dependencies**

Add after virtual environment creation (around line 90):

```bash
echo ""
echo -e "${BLUE}Installing MCP server dependencies...${NC}"
pip install -r mcp-servers/requirements.txt
```

**Step 4: Test MCP base setup**

Run:
```bash
source mlx-env/bin/activate
python -c "from mcp_servers.base_server import BaseMCPServer; print('MCP SDK imported successfully')"
```

Expected: "MCP SDK imported successfully"

**Step 5: Commit**

```bash
git add mcp-servers/requirements.txt mcp-servers/base_server.py setup.sh
git commit -m "feat: add MCP server infrastructure

- Create mcp-servers/requirements.txt with SDK deps
- Implement BaseMCPServer base class
- Add logging, signal handling, tool registration
- Update setup.sh to install MCP dependencies"
```

### Task 5: Implement Web Search MCP Server

**Files:**
- Create: `mcp-servers/web-search/server.py`
- Create: `mcp-servers/web-search/requirements.txt`

**Step 1: Create web-search requirements**

```txt
# mcp-servers/web-search/requirements.txt
duckduckgo-search>=5.0.0
```

**Step 2: Implement web search server**

```python
# mcp-servers/web-search/server.py
"""Web Search MCP Server using DuckDuckGo."""

import asyncio
from pathlib import Path
import sys

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from base_server import BaseMCPServer
from duckduckgo_search import DDGS


class WebSearchServer(BaseMCPServer):
    """MCP server providing web search capabilities."""

    def __init__(self):
        log_file = Path.home() / ".ralph" / "mcp-web-search.log"
        super().__init__("web-search", log_file)

        # Rate limiting
        self.last_search_time = 0
        self.min_interval = 6  # seconds (10 requests/minute max)

        # Register search tool
        self.register_search_tool()

    def register_search_tool(self):
        """Register the search tool with MCP."""

        @self.server.call_tool()
        async def search(query: str, max_results: int = 5) -> list[dict]:
            """Search DuckDuckGo and return results.

            Args:
                query: Search query string
                max_results: Maximum number of results (default: 5, max: 10)

            Returns:
                List of dicts with title, url, snippet
            """
            # Rate limiting
            import time
            now = time.time()
            elapsed = now - self.last_search_time
            if elapsed < self.min_interval:
                wait_time = self.min_interval - elapsed
                self.logger.info(f"Rate limiting: waiting {wait_time:.1f}s")
                await asyncio.sleep(wait_time)

            self.last_search_time = time.time()

            # Limit max_results
            max_results = min(max_results, 10)

            self.logger.info(f"Searching: {query} (max_results={max_results})")

            try:
                with DDGS() as ddgs:
                    results = []
                    for result in ddgs.text(query, max_results=max_results):
                        results.append({
                            "title": result.get("title", ""),
                            "url": result.get("href", ""),
                            "snippet": result.get("body", "")
                        })

                    self.logger.info(f"Found {len(results)} results")
                    return results

            except Exception as e:
                self.logger.error(f"Search failed: {e}")
                raise Exception(f"Search error: {str(e)}")

        # Register with server
        self.server.list_tools.append({
            "name": "search",
            "description": "Search the web using DuckDuckGo. Returns titles, URLs, and snippets.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Search query"
                    },
                    "max_results": {
                        "type": "integer",
                        "description": "Maximum results to return (1-10)",
                        "default": 5
                    }
                },
                "required": ["query"]
            }
        })


async def main():
    """Run the web search MCP server."""
    server = WebSearchServer()
    await server.run()


if __name__ == "__main__":
    asyncio.run(main())
```

**Step 3: Test web search server**

Run:
```bash
source mlx-env/bin/activate
pip install duckduckgo-search
python mcp-servers/web-search/server.py &
sleep 2
# Test with manual MCP client or check logs
cat ~/.ralph/mcp-web-search.log
```

Expected: Server starts, logs "Starting web-search MCP server..."

**Step 4: Commit**

```bash
git add mcp-servers/web-search/
git commit -m "feat: implement web search MCP server

- Create DuckDuckGo-based search server
- Add rate limiting (10 requests/minute)
- Return title, URL, snippet for each result
- Log all searches to ~/.ralph/mcp-web-search.log"
```

### Task 6: Implement Git Intelligence MCP Server

**Files:**
- Create: `mcp-servers/git-intel/server.py`
- Create: `mcp-servers/git-intel/requirements.txt`

**Step 1: Create git-intel requirements**

```txt
# mcp-servers/git-intel/requirements.txt
GitPython>=3.1.40
networkx>=3.2
```

**Step 2: Implement git intelligence server**

```python
# mcp-servers/git-intel/server.py
"""Git Intelligence MCP Server for repository analysis."""

import asyncio
from pathlib import Path
import sys
from collections import defaultdict

sys.path.insert(0, str(Path(__file__).parent.parent))

from base_server import BaseMCPServer
import git
import networkx as nx


class GitIntelServer(BaseMCPServer):
    """MCP server providing git repository intelligence."""

    def __init__(self, repo_path: str = "."):
        log_file = Path.home() / ".ralph" / "mcp-git-intel.log"
        super().__init__("git-intel", log_file)

        self.repo_path = Path(repo_path)
        self.repo = None
        self.cochange_graph = None

        # Initialize repository
        try:
            self.repo = git.Repo(self.repo_path)
            self.logger.info(f"Initialized repo at {self.repo_path}")
        except git.InvalidGitRepositoryError:
            self.logger.error(f"Not a git repository: {self.repo_path}")

        # Register tools
        self.register_tools()

    def build_cochange_graph(self, limit: int = 100):
        """Build graph of files that change together."""
        if not self.repo:
            return None

        graph = nx.Graph()
        commits = list(self.repo.iter_commits(max_count=limit))

        for commit in commits:
            if not commit.parents:
                continue

            # Get files changed in this commit
            changed_files = []
            for diff in commit.parents[0].diff(commit):
                if diff.a_path:
                    changed_files.append(diff.a_path)
                if diff.b_path and diff.b_path != diff.a_path:
                    changed_files.append(diff.b_path)

            # Add edges between co-changed files
            for i, file1 in enumerate(changed_files):
                for file2 in changed_files[i+1:]:
                    if graph.has_edge(file1, file2):
                        graph[file1][file2]['weight'] += 1
                    else:
                        graph.add_edge(file1, file2, weight=1)

        return graph

    def register_tools(self):
        """Register git intelligence tools."""

        @self.server.call_tool()
        async def analyze_changes(since_commit: str = "HEAD~10") -> dict:
            """Analyze changes since a specific commit.

            Args:
                since_commit: Git ref to compare from (default: HEAD~10)

            Returns:
                Dict with files_changed, insertions, deletions, summary
            """
            if not self.repo:
                raise Exception("Not a git repository")

            try:
                commits = list(self.repo.iter_commits(f"{since_commit}..HEAD"))

                stats = {
                    "num_commits": len(commits),
                    "files_changed": set(),
                    "insertions": 0,
                    "deletions": 0,
                    "authors": set()
                }

                for commit in commits:
                    stats["authors"].add(commit.author.name)
                    for file in commit.stats.files:
                        stats["files_changed"].add(file)
                        stats["insertions"] += commit.stats.files[file]["insertions"]
                        stats["deletions"] += commit.stats.files[file]["deletions"]

                return {
                    "commits": stats["num_commits"],
                    "files": sorted(list(stats["files_changed"])),
                    "insertions": stats["insertions"],
                    "deletions": stats["deletions"],
                    "authors": sorted(list(stats["authors"])),
                    "summary": f"{stats['num_commits']} commits changed {len(stats['files_changed'])} files (+{stats['insertions']}/-{stats['deletions']})"
                }

            except Exception as e:
                self.logger.error(f"analyze_changes error: {e}")
                raise Exception(f"Git analysis error: {str(e)}")

        @self.server.call_tool()
        async def find_related_files(file_path: str, limit: int = 5) -> list[str]:
            """Find files that often change together with the given file.

            Args:
                file_path: Path to file relative to repo root
                limit: Maximum number of related files to return

            Returns:
                List of related file paths sorted by relationship strength
            """
            if not self.repo:
                raise Exception("Not a git repository")

            # Build co-change graph if needed
            if not self.cochange_graph:
                self.logger.info("Building co-change graph...")
                self.cochange_graph = self.build_cochange_graph()

            if not self.cochange_graph or file_path not in self.cochange_graph:
                return []

            # Get neighbors sorted by edge weight
            neighbors = []
            for neighbor in self.cochange_graph.neighbors(file_path):
                weight = self.cochange_graph[file_path][neighbor]['weight']
                neighbors.append((neighbor, weight))

            neighbors.sort(key=lambda x: x[1], reverse=True)
            return [f for f, w in neighbors[:limit]]

        @self.server.call_tool()
        async def explain_commit(sha: str) -> dict:
            """Get detailed information about a commit.

            Args:
                sha: Commit SHA (full or short)

            Returns:
                Dict with author, date, message, files_changed, stats
            """
            if not self.repo:
                raise Exception("Not a git repository")

            try:
                commit = self.repo.commit(sha)

                files_changed = []
                if commit.parents:
                    for diff in commit.parents[0].diff(commit):
                        files_changed.append({
                            "path": diff.a_path or diff.b_path,
                            "change_type": diff.change_type,
                            "insertions": diff.diff.count(b'\n+') if diff.diff else 0,
                            "deletions": diff.diff.count(b'\n-') if diff.diff else 0
                        })

                return {
                    "sha": commit.hexsha,
                    "author": commit.author.name,
                    "email": commit.author.email,
                    "date": commit.committed_datetime.isoformat(),
                    "message": commit.message.strip(),
                    "files_changed": files_changed,
                    "total_insertions": sum(f["insertions"] for f in files_changed),
                    "total_deletions": sum(f["deletions"] for f in files_changed)
                }

            except Exception as e:
                self.logger.error(f"explain_commit error: {e}")
                raise Exception(f"Commit analysis error: {str(e)}")

        # Register tools with server
        self.server.list_tools.extend([
            {
                "name": "analyze_changes",
                "description": "Analyze git changes since a specific commit",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "since_commit": {
                            "type": "string",
                            "description": "Git ref to compare from",
                            "default": "HEAD~10"
                        }
                    }
                }
            },
            {
                "name": "find_related_files",
                "description": "Find files that often change together with a given file",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "file_path": {
                            "type": "string",
                            "description": "Path to file"
                        },
                        "limit": {
                            "type": "integer",
                            "description": "Max results",
                            "default": 5
                        }
                    },
                    "required": ["file_path"]
                }
            },
            {
                "name": "explain_commit",
                "description": "Get detailed information about a specific commit",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "sha": {
                            "type": "string",
                            "description": "Commit SHA"
                        }
                    },
                    "required": ["sha"]
                }
            }
        ])


async def main():
    """Run the git intelligence MCP server."""
    server = GitIntelServer()
    await server.run()


if __name__ == "__main__":
    asyncio.run(main())
```

**Step 3: Test git-intel server**

Run:
```bash
source mlx-env/bin/activate
pip install GitPython networkx
python mcp-servers/git-intel/server.py &
sleep 2
cat ~/.ralph/mcp-git-intel.log
```

Expected: Server starts, logs show repository initialization

**Step 4: Commit**

```bash
git add mcp-servers/git-intel/
git commit -m "feat: implement git intelligence MCP server

- Analyze changes since specific commits
- Find files that co-change frequently
- Build co-change graph using networkx
- Explain commits with detailed stats
- Cache graph for performance"
```

---

**Note:** This plan continues with Phases 3-6 covering Ralph Loop, Monitoring Dashboard, Enhanced Setup, and Documentation. Due to length, I'm providing the first major phase sections. Each subsequent phase follows the same detailed step-by-step pattern.

Would you like me to continue with the remaining phases, or would you prefer to start implementing Phase 1 first?

---

## Next Steps

Plan saved to: `docs/plans/2026-01-23-local-agentic-coding-system.md`

**Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans skill, batch execution with checkpoints

Which approach would you like to use?
