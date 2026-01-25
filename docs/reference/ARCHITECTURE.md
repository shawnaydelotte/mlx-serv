# Architecture Overview

## System Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Your Development Tools                  │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ OpenCode │  │  Claude  │  │   curl   │  │  Custom  │   │
│  │          │  │   Code   │  │          │  │   Apps   │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │             │             │             │          │
└───────┼─────────────┼─────────────┼─────────────┼──────────┘
        │             │             │             │
        │  Anthropic  │  Anthropic  │   HTTP     │   HTTP
        │     API     │     API     │    API     │    API
        └─────────────┴─────────────┴─────────────┘
                             │
                             ▼
        ┌─────────────────────────────────────────────────────┐
        │         LiteLLM Proxy (Port 4000)                   │
        │  ┌──────────────────────────────────────────────┐  │
        │  │  • Translates Anthropic → OpenAI format      │  │
        │  │  • Routes to backend MLX server              │  │
        │  │  • Handles streaming                         │  │
        │  │  • Provides /health, /v1/models endpoints    │  │
        │  └──────────────────────────────────────────────┘  │
        └───────────────────────┬─────────────────────────────┘
                                │ OpenAI API format
                                ▼
        ┌─────────────────────────────────────────────────────┐
        │          MLX-LM Server (Port 8080)                  │
        │  ┌──────────────────────────────────────────────┐  │
        │  │  • Loads Qwen2.5-Coder-7B-4bit model         │  │
        │  │  • Inference using MLX framework             │  │
        │  │  • OpenAI-compatible /v1/chat/completions    │  │
        │  │  • Optimized for Apple Silicon               │  │
        │  └──────────────────────────────────────────────┘  │
        └───────────────────────┬─────────────────────────────┘
                                │
                                ▼
        ┌─────────────────────────────────────────────────────┐
        │              MLX Framework (Apple)                  │
        │  ┌──────────────────────────────────────────────┐  │
        │  │  • Hardware acceleration via Metal           │  │
        │  │  • Optimized for M-series chips              │  │
        │  │  • Unified memory architecture               │  │
        │  └──────────────────────────────────────────────┘  │
        └───────────────────────┬─────────────────────────────┘
                                │
                                ▼
        ┌─────────────────────────────────────────────────────┐
        │           Apple Silicon (M1/M2/M3/M4)               │
        │                                                      │
        │   [CPU Cores]  [GPU Cores]  [Neural Engine]  [RAM] │
        │        ▲            ▲              ▲            ▲   │
        │        └────────────┴──────────────┴────────────┘   │
        │               Unified Memory (8-64GB)               │
        └─────────────────────────────────────────────────────┘
```

## Data Flow

### Request Flow (Client → Model)

```
1. OpenCode sends request
   POST http://localhost:4000/v1/messages
   {
     "model": "claude-coder-fake",
     "messages": [{"role": "user", "content": "write code"}]
   }
              │
              ▼
2. LiteLLM receives, translates to OpenAI format
   POST http://localhost:8080/v1/chat/completions
   {
     "model": "Qwen2.5-Coder-7B-Instruct-4bit",
     "messages": [{"role": "user", "content": "write code"}]
   }
              │
              ▼
3. MLX-LM server processes request
   • Loads model into unified memory (first request only)
   • Tokenizes input
   • Runs inference on GPU/Neural Engine
   • Generates tokens
              │
              ▼
4. MLX-LM returns response
   {
     "choices": [{
       "message": {"content": "def function()..."}
     }]
   }
              │
              ▼
5. LiteLLM translates back to Anthropic format
   {
     "content": [{"text": "def function()..."}]
   }
              │
              ▼
6. OpenCode receives and displays
```

### Streaming Flow

```
Client                LiteLLM              MLX-LM
  │                      │                    │
  ├─ Connect SSE ───────►│                    │
  │  stream: true        ├─ Forward ─────────►│
  │                      │                    │
  │                      │                    ├─ Generate token 1
  │                      │◄─── "def" ─────────┤
  │◄─── "def" ──────────┤                    │
  │                      │                    ├─ Generate token 2
  │                      │◄── "function" ─────┤
  │◄── "function" ──────┤                    │
  │                      │                    │
  │        ... streaming continues ...        │
  │                      │                    │
  │                      │◄─── [DONE] ────────┤
  │◄──── [DONE] ────────┤                    │
  │                      │                    │
```

## Component Details

### 1. LiteLLM Proxy

**Purpose**: API translation and routing
**Language**: Python
**Port**: 4000
**Config**: `config.yaml`

**Key Features**:
- Translates Anthropic API → OpenAI API
- Supports multiple backends
- Streaming support
- Model aliasing
- CORS handling
- Request/response logging

**Endpoints**:
- `GET /health` - Health check
- `GET /v1/models` - List available models
- `POST /v1/chat/completions` - Chat completion (OpenAI format)
- `POST /v1/messages` - Messages (Anthropic format)

### 2. MLX-LM Server

**Purpose**: Model inference
**Language**: Python + MLX (C++)
**Port**: 8080
**Model**: Qwen2.5-Coder-7B-Instruct-4bit

**Key Features**:
- OpenAI-compatible API
- Optimized for Apple Silicon
- 4-bit quantization (faster, less memory)
- Dynamic model loading
- Streaming generation
- Metal GPU acceleration

**Endpoints**:
- `GET /v1/models` - Model information
- `POST /v1/chat/completions` - Generate completion
- `GET /health` - Health check (if available)

### 3. MLX Framework

**Purpose**: ML acceleration on Apple Silicon
**Language**: C++ with Python bindings
**Vendor**: Apple

**Key Features**:
- Unified memory architecture
- GPU/Neural Engine utilization
- Lazy evaluation
- NumPy-like API
- Metal backend
- Automatic differentiation

### 4. Model: Qwen2.5-Coder-7B-Instruct

**Type**: Large Language Model for code
**Size**: 7 billion parameters
**Quantization**: 4-bit (from 16-bit FP)
**Memory**: ~4GB (vs ~14GB full precision)
**Context**: 32K tokens
**License**: Apache 2.0

**Optimizations**:
- Instruction-tuned for coding tasks
- Multi-language support (80+ languages)
- Fill-in-middle capability
- Repository-level understanding

## File Layout

```
mlx-serv/
│
├── Scripts
│   ├── setup.sh          # One-time installation
│   ├── start.sh          # Start/stop/status (main script)
│   └── test.sh           # Verification
│
├── Configuration
│   ├── config.yaml       # LiteLLM config (default)
│   └── config.optimized.yaml  # Tuned for code
│
├── Model (4-5GB)
│   └── qwen-coder-7b-4bit/
│       ├── config.json
│       ├── tokenizer.json
│       ├── *.safetensors  # Model weights
│       └── ...
│
├── Runtime
│   ├── mlx-env/          # Python virtual env
│   ├── mlx_server.log    # MLX-LM logs
│   ├── litellm_proxy.log # LiteLLM logs
│   └── .server_pids      # Process tracking
│
└── Documentation
    ├── README.md
    ├── QUICKSTART.md
    ├── IMPROVEMENTS.md
    └── ARCHITECTURE.md   # This file
```

## Process Lifecycle

### Startup Sequence

```
1. User runs: ./start.sh
         │
         ▼
2. Check system requirements
   ├─ macOS? ✓
   ├─ Apple Silicon? ✓
   ├─ Virtual env exists? ✓
   ├─ Model exists? ✓
   ├─ Config exists? ✓
   └─ Memory available? ✓
         │
         ▼
3. Start MLX-LM server
   ├─ Activate venv
   ├─ python -m mlx_lm.server
   ├─ Wait for process stabilization (2s)
   ├─ Check port 8080 bound
   ├─ Wait for HTTP response (30s)
   └─ ✓ MLX-LM ready
         │
         ▼
4. Start LiteLLM proxy
   ├─ litellm --config config.yaml
   ├─ Wait for process stabilization (2s)
   ├─ Check port 4000 bound
   ├─ Wait for HTTP response (30s)
   └─ ✓ LiteLLM ready
         │
         ▼
5. Display success status
   ├─ Show URLs
   ├─ Show usage commands
   └─ Ready for requests! 🚀
```

### Shutdown Sequence

```
1. User runs: ./start.sh --stop
         │
         ▼
2. Read .server_pids file
   ├─ litellm:12345
   └─ mlx:12346
         │
         ▼
3. Kill processes gracefully
   ├─ kill 12345 (LiteLLM)
   └─ kill 12346 (MLX-LM)
         │
         ▼
4. Fallback: kill by name
   ├─ pkill -f "litellm"
   └─ pkill -f "mlx_lm.server"
         │
         ▼
5. Cleanup
   └─ rm .server_pids
```

## Memory Layout (Example: 16GB Mac)

```
┌─────────────────────────────────────────┐
│       Total RAM: 16GB                   │
├─────────────────────────────────────────┤
│  macOS System:           4GB            │ ← OS, system processes
├─────────────────────────────────────────┤
│  Model Weights:          4GB            │ ← Qwen-7B-4bit
├─────────────────────────────────────────┤
│  Inference Buffer:       2GB            │ ← Active computation
├─────────────────────────────────────────┤
│  Python/MLX/LiteLLM:     1GB            │ ← Runtime overhead
├─────────────────────────────────────────┤
│  Available:              5GB            │ ← Other apps, cache
└─────────────────────────────────────────┘
```

**Notes**:
- Unified memory shared between CPU/GPU/Neural Engine
- Model loaded once, reused for all requests
- Memory usage stable after first request
- If memory pressure, macOS will swap (slower)

## Performance Characteristics

### Latency Breakdown

```
First Request (Cold Start):
├─ Model loading:     20-40s     (one-time)
├─ Tokenization:      50-200ms
├─ First token:       500-1000ms
└─ Subsequent tokens: 30-60ms/token

Warm Requests:
├─ Model loaded:      0s         (cached)
├─ Tokenization:      50-200ms
├─ First token:       200-500ms
└─ Subsequent tokens: 30-60ms/token
```

### Throughput

- **Tokens/second**: 15-30 (7B model on M2)
- **Requests/minute**: 5-20 (depends on length)
- **Concurrent requests**: 1 (serial processing)

### Optimization Factors

**Faster**:
- Lower `max_tokens`
- Lower `temperature` (less sampling)
- Shorter prompts
- 4-bit vs 8-bit quantization

**Slower**:
- First request (cold start)
- Very long prompts (>4K tokens)
- High `temperature` (more sampling)
- System memory pressure

## Network Flow

```
localhost only - no external network traffic

┌──────────────────────────────────────────┐
│          localhost (127.0.0.1)           │
│                                          │
│  Port 4000              Port 8080        │
│  ┌──────────┐          ┌──────────┐     │
│  │ LiteLLM  │◄────────►│  MLX-LM  │     │
│  └────▲─────┘          └──────────┘     │
│       │                                  │
│       │ External clients                 │
│       │ (OpenCode, curl, etc)            │
└───────┼──────────────────────────────────┘
        │
    ┌───┴────┐
    │ Client │
    └────────┘
```

**Security**:
- Both servers bind to `localhost` only
- No external network access
- No authentication required (local trust)
- CORS enabled for local development

## Comparison: Cloud vs Local

### Request Path Comparison

**Cloud API**:
```
OpenCode → Internet → Anthropic Servers → Response
          (50-200ms)    (varies)
Total: 100-500ms typical
```

**Local Setup**:
```
OpenCode → LiteLLM → MLX-LM → Response
          (< 1ms)   (1-5s first token)
Total: 1-5s typical (after warm-up)
```

### Trade-offs

| Aspect | Cloud | Local |
|--------|-------|-------|
| Latency | 100-500ms | 1-5s |
| Quality | Excellent | Good |
| Privacy | Data sent out | 100% local |
| Cost | $$ per token | Free |
| Setup | None | One-time effort |
| Offline | No | Yes |
| Scale | Unlimited | Single user |

## Monitoring Points

### Health Checks

```
1. Process-level
   ├─ ps -p <pid>
   └─ lsof -i :<port>

2. Network-level
   ├─ curl localhost:8080/v1/models
   └─ curl localhost:4000/health

3. Application-level
   └─ POST /v1/chat/completions (test request)
```

### Logs

```
mlx_server.log:
├─ Model loading progress
├─ Request/response pairs
├─ Token generation stats
└─ Errors/warnings

litellm_proxy.log:
├─ Proxy startup
├─ Backend connections
├─ Request routing
└─ Translation errors
```

## Scaling Considerations

### Current: Single Model, Single User

```
Client → LiteLLM → MLX-LM → Model
          (1:1)     (1:1)
```

### Future: Multiple Models

```
Client 1 ─┐
Client 2 ─┼─→ LiteLLM ─┬─→ MLX-LM:8080 → Model A
Client 3 ─┘            └─→ MLX-LM:8081 → Model B
```

### Future: Load Balancing

```
Clients ──→ LiteLLM ──┬──→ MLX-LM (replica 1)
                      ├──→ MLX-LM (replica 2)
                      └──→ MLX-LM (replica 3)
```

**Note**: Current setup is single-threaded, one request at a time.

## Technology Stack Summary

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Client | OpenCode, curl | User interface |
| API Translation | LiteLLM | Format conversion |
| Inference Server | mlx-lm | Model serving |
| ML Framework | MLX | Acceleration |
| Model | Qwen2.5-Coder | LLM weights |
| Hardware | Apple Silicon | Computation |
| OS | macOS | Platform |

---

This architecture provides a complete, self-contained LLM inference stack optimized for Apple Silicon, with production-quality tooling and monitoring.
