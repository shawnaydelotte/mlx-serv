# Quick Start Guide

## First Time Setup

```bash
# 1. Clone/download this repository
cd mlx-serv

# 2. Run setup (takes 15-30 min)
./setup.sh

# 3. Start servers
./start.sh
```

## Daily Use

```bash
# Start servers (7B model - quality)
./start.sh

# Start with 3B model (faster)
./start.sh --fast

# Check status
./start.sh --status

# View logs
./start.sh --logs

# Stop servers
./start.sh --stop

# Autonomous iteration
./ralph-loop.sh "task description"
```

## OpenCode Configuration

Automatically configure OpenCode:

```bash
# Recommended (optimized for code generation)
./configure-opencode.sh --optimized

# Or default settings
./configure-opencode.sh
```

This updates `~/.config/opencode/config.json` with correct settings.

**See [../setup/OPENCODE-SETUP.md](../setup/OPENCODE-SETUP.md) for detailed guide.**

## Test It Works

```bash
# Run health checks
./test.sh

# Run full verification
./verify.sh

# Run test suite
source mlx-env/bin/activate
PYTHONPATH=. pytest tests/ -v

# Or manual test
curl http://localhost:4000/health
curl http://localhost:4000/v1/models
```

## Common Issues

### Servers won't start
```bash
./start.sh --stop  # Kill any old processes
./start.sh         # Restart
```

### Out of memory
```bash
# Close other apps and restart
./start.sh --restart
```

### Slow first response
- Normal! Model loading takes 10-30 seconds on first request
- Subsequent requests are faster

## Configuration notes

`./start.sh` already uses `config.optimized.yaml` (7B: max_tokens 8192, temperature 0.3, stream true).
`./start.sh --fast` uses `config.3b.yaml` (primary alias `claude-coder-fast`).

Conservative settings live in `config.yaml` if you run LiteLLM manually.

## File Structure

```
mlx-serv/
├── start.sh          ← Main script (use this!)
├── test.sh           ← Verify everything works
├── setup.sh          ← One-time setup
├── config.yaml       ← LiteLLM configuration
└── README.md         ← Full documentation
```

## Endpoints

| URL | Purpose |
|-----|---------|
| `http://localhost:8080/v1` | MLX-LM backend (OpenAI format) |
| `http://localhost:4000` | LiteLLM proxy (Anthropic format) |
| `http://localhost:4000/health` | Health check |

**For OpenCode**: Use port `4000` with model `claude-coder-fake` (7B default). Fast mode primary alias is `claude-coder-fast`.

## Performance Tips

1. **Keep servers running** between coding sessions (avoid cold starts)
2. **Use streaming** for better perceived speed
3. **Lower temperature** (0.2-0.3) for code generation
4. **Close other apps** if memory is tight
5. **First request is slow** (~30s) - normal!

## Help

```bash
./start.sh --help     # Show all options
cat README.md         # Full documentation
./test.sh             # Verify setup
```

## Comparison

| Feature | Cloud API | Local (this setup) |
|---------|-----------|-------------------|
| Cost | Pay per use | Free |
| Speed | Fast | Slower (but acceptable) |
| Privacy | Data sent to cloud | 100% private |
| Quality | Excellent | Good for most tasks |
| Offline | No | Yes |
| Setup | Easy | One-time effort |

---

**Need more help?** See [../../README.md](../../README.md) for detailed documentation.
