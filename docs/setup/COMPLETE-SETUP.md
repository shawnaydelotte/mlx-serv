# Complete Setup Guide - MLX-LM + OpenCode

End-to-end setup guide for running local coding models with OpenCode.

## Prerequisites

- Apple Silicon Mac (M1/M2/M3/M4)
- macOS 12.0+ (Monterey or later)
- 8GB+ RAM (16GB recommended)
- 15GB free disk space
- Homebrew installed

## One-Time Setup (First Time Only)

### Step 1: Install Everything

```bash
cd /Users/s/Projects/mlx-serv
./setup.sh
```

This will:
- Install Python 3.12 via Homebrew
- Create virtual environment
- Install mlx-lm and litellm
- Download Qwen2.5-Coder-7B model (4-bit, ~3GB download)
- Quantize model for Apple Silicon

**Time**: 15-30 minutes (mostly model download)

### Step 2: Start the Server

```bash
./start.sh
```

You'll see a beautiful startup sequence with health checks.

**Expected output:**
```
╔════════════════════════════════════════╗
║  🚀 Servers Running Successfully!      ║
╠════════════════════════════════════════╣
║  MLX-LM Backend:                       ║
║    http://localhost:8080/v1            ║
║  LiteLLM Proxy:                        ║
║    http://localhost:4000               ║
╚════════════════════════════════════════╝
```

### Step 3: Configure OpenCode

```bash
./configure-opencode.sh --optimized
```

**Expected output:**
```
╔════════════════════════════════════════╗
║  OpenCode Configuration for MLX-LM     ║
╚════════════════════════════════════════╝

✓ OpenCode config directory exists
✓ Backing up existing configuration
✓ Optimized configuration written
✓ Configuration is valid JSON

╔════════════════════════════════════════╗
║  Configuration Complete! ✓             ║
╚════════════════════════════════════════╝
```

### Step 4: Verify Everything Works

```bash
./test.sh
```

**Expected output:**
```
Testing MLX-LM + LiteLLM Setup

[1/5] Checking if servers are running...
  ✓ MLX-LM server listening on port 8080
  ✓ LiteLLM proxy listening on port 4000

[2/5] Testing MLX-LM endpoint...
  ✓ MLX-LM /v1/models endpoint responding

[3/5] Testing LiteLLM health endpoint...
  ✓ LiteLLM /health endpoint responding

[4/5] Testing LiteLLM models endpoint...
  ✓ Model 'claude-coder-fake' is available

[5/5] Testing completion endpoint...
  ✓ Completion successful

════════════════════════════════════
  All tests passed! ✓
════════════════════════════════════
```

### Step 5: Start Coding!

Launch OpenCode and start using the local model!

## Daily Workflow

### Morning (Start of Day)

```bash
cd /Users/s/Projects/mlx-serv
./start.sh
```

That's it! Server is ready.

### Using OpenCode

Just use OpenCode normally. It will use your local model automatically.

### Evening (Optional)

```bash
./start.sh --stop  # Free up memory
```

Or leave it running for instant access tomorrow.

## Quick Reference

### Essential Commands

```bash
# Start servers
./start.sh

# Check status
./start.sh --status

# View logs (live)
./start.sh --logs

# Stop servers
./start.sh --stop

# Restart servers
./start.sh --restart

# Test everything
./test.sh
```

### Configuration Commands

```bash
# Configure OpenCode (optimized - recommended)
./configure-opencode.sh --optimized

# Configure OpenCode (default)
./configure-opencode.sh

# Switch to optimized server config
cp config.optimized.yaml config.yaml
./start.sh --restart
```

### Troubleshooting Commands

```bash
# Check server status
./start.sh --status

# View live logs
./start.sh --logs

# Run full test suite
./test.sh

# Check OpenCode config
cat ~/.config/opencode/config.json

# Test API manually
curl http://localhost:4000/health
curl http://localhost:4000/v1/models
```

## File Locations

### Server Files

```
/Users/s/Projects/mlx-serv/
├── start.sh              # Main script
├── configure-opencode.sh # OpenCode setup
├── test.sh               # Verification
├── config.yaml           # Server config
├── config.optimized.yaml # Better config
└── qwen-coder-7b-4bit/   # Model (~4GB)
```

### OpenCode Config

```
~/.config/opencode/config.json
```

View it:
```bash
cat ~/.config/opencode/config.json
```

Edit it:
```bash
nano ~/.config/opencode/config.json
```

### Logs

```
/Users/s/Projects/mlx-serv/mlx_server.log
/Users/s/Projects/mlx-serv/litellm_proxy.log
```

View logs:
```bash
cd /Users/s/Projects/mlx-serv
./start.sh --logs
```

## Configuration Matching

For best results, match your server and OpenCode configs:

### Option 1: Optimized (Recommended)

**Server:**
```bash
cp config.optimized.yaml config.yaml
./start.sh --restart
```

**OpenCode:**
```bash
./configure-opencode.sh --optimized
```

**Settings:** max_tokens=8192, temperature=0.3

### Option 2: Default

**Server:** Use existing `config.yaml`

**OpenCode:**
```bash
./configure-opencode.sh
```

**Settings:** max_tokens=4096, temperature=0.7

## Performance Tips

1. **Keep server running** between sessions (avoid cold start)
2. **Use optimized config** for better code generation
3. **First request is slow** (30-45s) - normal!
4. **Subsequent requests** are faster (2-10s)
5. **Close other apps** if memory is tight

## Common Issues & Fixes

### Server won't start

```bash
# Stop any old processes
./start.sh --stop

# Restart fresh
./start.sh
```

### OpenCode can't connect

```bash
# 1. Check server is running
./start.sh --status

# 2. Test endpoint
curl http://localhost:4000/health

# 3. Reconfigure OpenCode
./configure-opencode.sh --optimized
```

### Slow responses

- First request is always slow (model loading) - normal
- Use optimized config: `./configure-opencode.sh --optimized`
- Lower temperature in config (0.2-0.3)

### Wrong model/cloud API being used

```bash
# Verify OpenCode config points to local
grep baseURL ~/.config/opencode/config.json
# Should show: http://localhost:4000/v1

# Reconfigure if needed
./configure-opencode.sh --optimized
```

## Testing

### Quick Test

```bash
./test.sh
```

### Manual API Test

```bash
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test" \
  -d '{
    "model": "claude-coder-fake",
    "messages": [
      {"role": "user", "content": "Write hello world in Python"}
    ]
  }'
```

### OpenCode Test

1. Open OpenCode
2. Create a new file
3. Ask OpenCode to write code
4. Watch logs: `./start.sh --logs`
5. You should see requests in the logs

## Documentation

- **README.md** - Complete guide
- **QUICKSTART.md** - One-page reference
- **OPENCODE-SETUP.md** - Detailed OpenCode integration
- **ARCHITECTURE.md** - System architecture
- **IMPROVEMENTS.md** - What's been improved
- **FILES.txt** - Repository contents

## Getting Help

1. Check status: `./start.sh --status`
2. Run tests: `./test.sh`
3. View logs: `./start.sh --logs`
4. Read docs: `cat README.md`
5. Check OpenCode config: `cat ~/.config/opencode/config.json`

## Summary Checklist

- [ ] Run `./setup.sh` (one-time, 15-30 min)
- [ ] Run `./start.sh` (daily)
- [ ] Run `./configure-opencode.sh --optimized` (one-time)
- [ ] Run `./test.sh` (verify everything works)
- [ ] Launch OpenCode and start coding!

**That's it! You now have a fully functional local coding AI.**

## What You Get

✅ **Privacy**: All code stays on your Mac
✅ **Cost**: $0/month (no API fees)
✅ **Speed**: Good (after warm-up)
✅ **Offline**: Works without internet
✅ **Quality**: Good for most coding tasks
✅ **Control**: Full control over model and parameters

Enjoy coding with complete privacy and zero API costs! 🚀
