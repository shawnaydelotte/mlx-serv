# Local Agentic Coding System Design

**Date:** 2026-01-23
**Status:** Approved for Implementation
**Goal:** Transform mlx-serv into a complete local agentic coding environment with Ralph Loop, MCP servers, dual model support, and clone-and-go setup

## Overview

This design expands the current mlx-serv setup (MLX-LM + LiteLLM serving Qwen2.5-Coder-7B) into a comprehensive local agentic coding system. The enhanced system will provide autonomous iteration capabilities, web search, git intelligence, document RAG, real-time monitoring, and optimized performance through dual model support.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    LAYER 1: USER INTERFACE                   │
│  ┌──────────────────────┐        ┌──────────────────────┐   │
│  │   OpenCode (VS Code) │        │    CLI Tools         │   │
│  │  - Code editing       │        │  - ./start.sh        │   │
│  │  - AI chat            │        │  - ./ralph-loop.sh   │   │
│  │  - MCP integration    │        │  - ./dashboard.sh    │   │
│  └──────────────────────┘        └──────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│          LAYER 2: ORCHESTRATION & EXTENSIONS                │
│  ┌───────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │  Ralph Loop   │  │ MCP Servers  │  │  Monitoring     │  │
│  │  Engine       │  │ - Web Search │  │  Dashboard      │  │
│  │               │  │ - Git Intel  │  │  (Terminal UI)  │  │
│  │  Plan → Exec  │  │ - Doc RAG    │  │                 │  │
│  │  Review →     │  │              │  │  Metrics, Logs  │  │
│  │  Refine       │  │  (Unix sock) │  │  Progress bars  │  │
│  └───────────────┘  └──────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              LAYER 3: MODEL INFERENCE                        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  LiteLLM Proxy (Port 4000)                           │   │
│  │  - Anthropic-compatible API                          │   │
│  │  - Model routing (3B vs 7B)                          │   │
│  │  - Streaming, metrics                                │   │
│  └──────────────────────────────────────────────────────┘   │
│                              ↓                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  MLX-LM Server (Port 8080)                           │   │
│  │  - Qwen2.5-Coder-3B-4bit (fast: ~300-400 tok/s)     │   │
│  │  - Qwen2.5-Coder-7B-4bit (quality: ~170 tok/s)      │   │
│  │  - Metal GPU acceleration                            │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Component Designs

### 1. Ralph Loop Engine

**Purpose:** Enable autonomous iteration on coding tasks through structured Plan → Execute → Review → Refine cycles.

**Implementation:**

- **Core Loop Structure:**
  - Maintains conversation context with local model
  - Tracks iteration state in `.ralph/state.json`
  - Writes plans to `.ralph/current-plan.md`
  - Logs all actions to `.ralph/iteration-N.log`

- **Cycle Phases:**
  1. **Plan:** Model analyzes task, breaks into steps, identifies success criteria
  2. **Execute:** Model uses OpenCode tooling to read files, edit code, run tests
  3. **Review:** Automatic validation - tests passed? New errors? Requirements met?
  4. **Refine:** Decide if done or update plan and iterate again

- **User Control Points:**
  - Initial plan approval before execution
  - Checkpoint after every 2 iterations
  - `--auto` flag for uninterrupted execution
  - Ctrl+C for clean emergency stop
  - Max iterations: 5 (configurable)

- **State Management:**
  - All state in `.ralph/` directory
  - Survives restarts
  - Full audit trail with timestamps
  - Review reports track learnings across iterations

**Entry Point:** `./ralph-loop.sh <task-description>`

### 2. MCP Server Architecture

**Purpose:** Provide standardized extensions for web search, git intelligence, and documentation retrieval.

**Common Infrastructure:**
- MCP Python SDK for all servers
- Unix socket communication (`.ralph/mcp-*.sock`)
- Centralized config in `.ralph/mcp-config.json`
- Registration with OpenCode via `.config/opencode/mcp.json`

**2a. Web Search MCP Server**

- **Tool Exposed:** `search(query, max_results=5)`
- **Backend:** DuckDuckGo API (no auth required)
- **Rate Limiting:** 10 requests/minute (configurable)
- **Output Format:** Markdown with titles, URLs, snippets
- **Use Cases:** Finding documentation, checking latest library versions, researching error messages
- **Location:** `mcp-servers/web-search/server.py`

**2b. Git Intelligence MCP Server**

- **Tools Exposed:**
  - `analyze_changes(since_commit)` - Summarize what changed
  - `find_related_files(file_path)` - Suggest files that might need updates
  - `explain_commit(sha)` - Deep commit analysis

- **Capabilities:**
  - Builds in-memory graph of file relationships
  - Analyzes co-change patterns from git history
  - Parses imports/dependencies for static analysis
  - Incrementally updates graph as new commits happen

- **Use Cases:** Understanding impact of changes, finding test files, identifying dependencies
- **Location:** `mcp-servers/git-intel/server.py`

**2c. Document RAG MCP Server**

- **Tool Exposed:** `search_docs(query, context="")`
- **Backend:**
  - Sentence-transformers via MLX for embeddings
  - FAISS for vector storage
  - Indexes: README files, markdown docs, code comments

- **Build Process:**
  - Automatic index on first run
  - Incremental updates when docs change
  - Stores embeddings in `.ralph/doc-index.faiss`

- **Use Cases:** Finding configuration examples, API documentation, setup instructions
- **Location:** `mcp-servers/doc-rag/server.py`

### 3. Dual Model Support

**Purpose:** Balance speed and quality by offering both 3B and 7B models.

**Model Configurations:**

**Qwen2.5-Coder-3B-Instruct-4bit (Fast):**
- Performance: ~300-400 tokens/sec on M2 Max
- Memory: ~2GB
- Best for: Code completion, formatting, simple refactoring, test generation
- Config: `config.3b.yaml`
- Launch: `./start.sh --fast`

**Qwen2.5-Coder-7B-Instruct-4bit (Quality):**
- Performance: ~170 tokens/sec on M2 Max
- Memory: ~4GB
- Best for: Complex debugging, architecture decisions, subtle refactoring
- Config: `config.optimized.yaml` (current default)
- Launch: `./start.sh` (default)

**Automatic Model Selection (Ralph Loop):**

The Ralph Loop Engine analyzes task descriptions and auto-selects models:

- **Use 3B for:** "format code", "add comments", "generate tests", "fix typo"
- **Use 7B for:** "refactor architecture", "debug complex issue", "optimize algorithm", "design API"

Keywords triggering 7B: "refactor", "architecture", "debug", "complex", "optimize", "design"

**Manual Override:**
```bash
# Force 3B for speed
./ralph-loop.sh --model 3b "refactor authentication system"

# Force 7B for quality
./ralph-loop.sh --model 7b "add unit tests"
```

### 4. Monitoring Dashboard

**Purpose:** Real-time visibility into model inference and system health via terminal UI.

**Technology:** Python with rich/textual for terminal UI

**Layout (4 Panels):**

```
┌─────────────────────────────┬─────────────────────────────┐
│  CURRENT REQUEST            │  SYSTEM METRICS             │
│                             │                             │
│  Tokens: 2048/10521 (19%)  │  MLX Memory: 4.2GB / 8GB    │
│  Speed: 285 tok/s           │  GPU Util: 87%              │
│  ETA: 28 seconds            │  Temp: 42°C                 │
│  ████████░░░░░░░░░░░        │                             │
│                             │  Model: Qwen-3B-4bit        │
├─────────────────────────────┼─────────────────────────────┤
│  RECENT REQUESTS            │  MCP SERVER STATUS          │
│                             │                             │
│  14:32:15  complete  2.1s   │  ● web-search   active      │
│  14:31:58  complete  5.4s   │  ● git-intel    active      │
│  14:31:22  complete  1.8s   │  ○ doc-rag      idle        │
│  14:30:45  failed    0.2s   │                             │
│  14:30:12  complete  3.7s   │  Uptime: 2h 34m             │
└─────────────────────────────┴─────────────────────────────┘
```

**Features:**
- Live token-by-token progress with ETA
- System resource monitoring (memory, GPU, temp)
- Request history with latency tracking
- MCP server health indicators
- Auto-suggests 3B model if 7B shows memory pressure
- Polling: 500ms updates
- WebSocket streaming for real-time token progress

**Entry Point:** `./start.sh --dashboard`

**Integration:**
- Connects to LiteLLM metrics endpoint (`localhost:4000/metrics`)
- Reads MLX-LM stats via process monitoring
- Checks MCP socket availability for status

### 5. Clone-and-Go Setup Experience

**Purpose:** Enable new users to clone and run with a single command.

**Enhanced setup.sh Features:**

**System Detection:**
- Detects RAM (8GB vs 16GB+)
- Identifies Apple Silicon model (M1/M2/M3/M4)
- Checks available disk space
- Recommends configuration based on hardware

**Recommendations:**
- M1/M2 base (8GB): Install 3B model only, suggest 7B as optional
- M2 Pro/Max/Ultra (16GB+): Install both models, 7B as default
- M3+ (any): Install both models, auto model selection enabled

**Progress Display:**

```
MLX-SERV Setup
═══════════════════════════════════════

✓ System Requirements      (5s)
  └─ M2 Max detected, 32GB RAM, 45GB free disk

⟳ Virtual Environment      (2m 15s) [████████████░░░░░░░░] 65%
  └─ Installing Python dependencies...

○ Model Downloads          (pending)
  └─ Will download: 3B (3.2GB), 7B (4.8GB)

○ OpenCode Configuration   (pending)
○ MCP Server Setup         (pending)
○ Verification Tests       (pending)
```

**One-Command Installation:**

```bash
git clone https://github.com/user/mlx-serv.git
cd mlx-serv
./setup.sh --auto
```

**The `--auto` Flag:**
- Uses sensible defaults (no questions)
- Installs both models if disk space permits (>20GB free)
- Uses optimized config
- Enables all MCP servers
- Configures OpenCode automatically
- Runs verification tests

**Post-Setup Summary:**

```
✓ Setup Complete!
═══════════════════════════════════════

Models Installed:
  • Qwen2.5-Coder-3B-4bit   3.2GB  (fast)
  • Qwen2.5-Coder-7B-4bit   4.8GB  (quality)

OpenCode Configured:
  • Default model: claude-coder-fake → 7B
  • API: http://localhost:4000

MCP Servers Enabled:
  • web-search (DuckDuckGo)
  • git-intel (repository analysis)
  • doc-rag (documentation search)

Ralph Loop Ready:
  • ./ralph-loop.sh "your task description"
  • Auto model selection: enabled

Next Steps:
  1. ./start.sh              # Launch servers
  2. ./start.sh --dashboard  # Monitor performance
  3. Open OpenCode and start coding!

Documentation:
  • README.md         Complete guide
  • QUICKSTART.md     Quick reference
  • RALPH-LOOP.md     Tutorial and examples
```

**Error Handling:**
- Clear failure messages with suggested fixes
- Doesn't exit immediately - explains what went wrong
- Offers to retry failed stages
- Provides commands to manually fix issues

## File Structure (Additions)

```
mlx-serv/
│
├── Scripts (New/Enhanced)
│   ├── ralph-loop.sh       # Ralph Loop orchestrator
│   ├── dashboard.sh        # Monitoring dashboard
│   ├── setup.sh            # Enhanced with auto-detection
│   └── start.sh            # Enhanced with --fast, --dashboard flags
│
├── MCP Servers
│   ├── mcp-servers/
│   │   ├── web-search/
│   │   │   ├── server.py
│   │   │   └── requirements.txt
│   │   ├── git-intel/
│   │   │   ├── server.py
│   │   │   └── requirements.txt
│   │   └── doc-rag/
│   │       ├── server.py
│   │       ├── requirements.txt
│   │       └── indexer.py
│
├── Configuration (New)
│   ├── config.3b.yaml      # Fast 3B model config
│   └── ralph-config.yaml   # Ralph Loop settings
│
├── Documentation (New)
│   ├── RALPH-LOOP.md       # Tutorial and examples
│   ├── MCP-SERVERS.md      # MCP server documentation
│   └── PERFORMANCE.md      # 3B vs 7B benchmarks
│
├── Runtime (Generated)
│   └── .ralph/
│       ├── state.json
│       ├── current-plan.md
│       ├── iteration-*.log
│       ├── mcp-config.json
│       ├── mcp-*.sock
│       └── doc-index.faiss
│
└── Models (New)
    ├── qwen-coder-7b-4bit/    # Existing
    └── qwen-coder-3b-4bit/    # New - faster model
```

## Implementation Phases

### Phase 1: Dual Model Support
1. Download and quantize Qwen2.5-Coder-3B-Instruct
2. Create `config.3b.yaml` with optimized settings
3. Update `start.sh` with `--fast` flag for 3B model
4. Benchmark both models and document performance
5. Update documentation with model selection guide

### Phase 2: MCP Servers
1. Set up MCP Python SDK infrastructure
2. Implement Web Search server (DuckDuckGo)
3. Implement Git Intelligence server
4. Implement Document RAG server
5. Create MCP configuration and registration
6. Test each server independently
7. Integrate with OpenCode

### Phase 3: Ralph Loop Engine
1. Design state management system
2. Implement Plan phase (task decomposition)
3. Implement Execute phase (OpenCode integration)
4. Implement Review phase (validation logic)
5. Implement Refine phase (iteration logic)
6. Add user approval checkpoints
7. Create `ralph-loop.sh` entry point
8. Write RALPH-LOOP.md tutorial

### Phase 4: Monitoring Dashboard
1. Set up rich/textual UI framework
2. Implement 4-panel layout
3. Connect to LiteLLM metrics endpoint
4. Add real-time token progress tracking
5. Add system resource monitoring
6. Add MCP server status checks
7. Create `dashboard.sh` entry point

### Phase 5: Enhanced Setup Experience
1. Add system detection to setup.sh
2. Implement intelligent recommendations
3. Create interactive progress display
4. Add `--auto` flag for one-command setup
5. Improve error handling and recovery
6. Create post-setup summary display
7. Update all documentation

### Phase 6: Documentation & Polish
1. Write RALPH-LOOP.md with tutorials
2. Write MCP-SERVERS.md with examples
3. Write PERFORMANCE.md with benchmarks
4. Update README.md with new capabilities
5. Update QUICKSTART.md
6. Create example Ralph Loop sessions
7. Final testing and refinement

## Success Criteria

1. **Clone-and-Go:** New user can run `./setup.sh --auto` and have fully functional system in 15-30 minutes
2. **Ralph Loop:** Can autonomously iterate on coding tasks with user approval checkpoints
3. **MCP Integration:** All three MCP servers working and accessible from OpenCode
4. **Performance:** 3B model achieves 2-3x speed improvement over 7B
5. **Monitoring:** Dashboard provides real-time visibility with <1 second latency
6. **Documentation:** Complete guides for all new features with examples
7. **Reliability:** All components survive restarts and handle errors gracefully

## Key Design Decisions

1. **Local-First:** Zero external API calls except optional web search (DuckDuckGo)
2. **Unix Sockets for MCP:** Better performance and security than HTTP for local communication
3. **State in `.ralph/`:** Centralized state management, easy cleanup, survives restarts
4. **Auto Model Selection:** Balances speed and quality without user intervention
5. **Terminal UI:** Rich dashboard without browser dependency
6. **FAISS for RAG:** Simple, fast, no database setup required
7. **Incremental Setup:** Each component can be disabled if not needed

## Performance Expectations

**Model Inference:**
- 3B model: 300-400 tok/s (M2 Max), 200-300 tok/s (M1/M2 base)
- 7B model: 150-200 tok/s (M2 Max), 100-150 tok/s (M1/M2 base)

**MCP Server Latency:**
- Web Search: 200-500ms (depends on DuckDuckGo)
- Git Intel: 10-50ms (cached graph)
- Doc RAG: 50-200ms (depends on index size)

**Memory Usage:**
- Base (7B only): ~8GB total
- Dual (3B + 7B): ~10GB total (only one loaded at a time)
- With all MCP servers: +500MB

**Disk Usage:**
- Models: 3B (3.2GB) + 7B (4.8GB) = 8GB
- Virtual env: ~8GB
- MCP servers + deps: ~500MB
- Total: ~17GB

## Risk Mitigation

**Risk:** Users with 8GB RAM can't run 7B model comfortably
**Mitigation:** Setup detects RAM and recommends 3B-only installation

**Risk:** MCP servers fail silently
**Mitigation:** Dashboard shows real-time status, logs to `.ralph/mcp-*.log`

**Risk:** Ralph Loop gets stuck in infinite iteration
**Mitigation:** Max iteration limit (5), user checkpoints every 2 iterations

**Risk:** Model downloads fail (flaky networks)
**Mitigation:** Resume support in setup.sh, verify checksums

**Risk:** OpenCode configuration conflicts
**Mitigation:** Backup existing config, validation before overwrite

## Future Enhancements (Out of Scope)

- Additional MCP servers (Jira, Slack, Linear)
- Multi-model inference (run 3B and 7B simultaneously)
- Cloud sync for Ralph Loop state
- VSCode extension for Ralph Loop control
- Fine-tuning pipeline for custom models
- Kubernetes deployment option

---

**Design Approved:** 2026-01-23
**Ready for Implementation Planning**
