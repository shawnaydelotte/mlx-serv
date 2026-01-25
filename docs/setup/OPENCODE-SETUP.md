# OpenCode Integration Guide

Complete guide to integrate OpenCode with your local MLX-LM server.

## Quick Setup (Automated)

### Option 1: Default Configuration

```bash
# From the mlx-serv directory
./configure-opencode.sh
```

This configures OpenCode with default settings:
- Max tokens: 4096
- Temperature: 0.7
- Context window: 32K tokens

### Option 2: Optimized Configuration (Recommended)

```bash
# From the mlx-serv directory
./configure-opencode.sh --optimized
```

This configures OpenCode with optimized settings for code generation:
- Max tokens: 8192 (longer outputs)
- Temperature: 0.3 (more focused/deterministic)
- Top-p: 0.9
- Frequency penalty: 0.1 (reduces repetition)
- Presence penalty: 0.1 (encourages variety)

## Complete Workflow

### Step 1: Start MLX-LM Server

```bash
cd /Users/s/Projects/mlx-serv
./start.sh
```

Wait for both services to start and verify:
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

### Step 2: Configure OpenCode

```bash
# Choose one:
./configure-opencode.sh              # Default settings
./configure-opencode.sh --optimized  # Better for code (recommended)
```

### Step 3: Verify Configuration

```bash
# Check OpenCode config
cat ~/.config/opencode/config.json

# Test the connection
./test.sh
```

Expected output:
```
[1/5] Checking if servers are running...
  ✓ MLX-LM server listening on port 8080
  ✓ LiteLLM proxy listening on port 4000

[5/5] Testing completion endpoint...
  ✓ Completion successful

════════════════════════════════════
  All tests passed! ✓
════════════════════════════════════
```

### Step 4: Start Coding with OpenCode

Launch OpenCode and start using it! The model `claude-coder-fake` is now available.

## Configuration File Location

OpenCode config: `~/.config/opencode/config.json`

## Configuration Details

### Default Configuration

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "anthropic": {
      "options": {
        "baseURL": "http://localhost:4000/v1"
      },
      "models": {
        "claude-coder-fake": {
          "options": {
            "maxTokens": 4096,
            "temperature": 0.7,
            "contextWindow": 32768
          }
        }
      }
    }
  },
  "model": "anthropic/claude-coder-fake",
  "features": {
    "streaming": true,
    "codeCompletion": true
  }
}
```

### Optimized Configuration

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "anthropic": {
      "options": {
        "baseURL": "http://localhost:4000/v1"
      },
      "models": {
        "claude-coder-fake": {
          "options": {
            "maxTokens": 8192,
            "temperature": 0.3,
            "contextWindow": 32768,
            "topP": 0.9,
            "frequencyPenalty": 0.1,
            "presencePenalty": 0.1
          }
        }
      }
    }
  },
  "model": "anthropic/claude-coder-fake",
  "features": {
    "streaming": true,
    "codeCompletion": true,
    "diagnostics": true
  }
}
```

## Manual Configuration

If you prefer to configure OpenCode manually:

1. **Edit the config file:**
   ```bash
   nano ~/.config/opencode/config.json
   ```

2. **Update the settings:**
   ```json
   {
     "provider": {
       "anthropic": {
         "options": {
           "baseURL": "http://localhost:4000/v1"
         }
       }
     },
     "model": "anthropic/claude-coder-fake"
   }
   ```

3. **Save and restart OpenCode**

## Matching Server Configuration

The OpenCode configuration should match your MLX-LM server config:

### If using `config.yaml` (default)

Use: `./configure-opencode.sh` (default)

Both configurations will have:
- Max tokens: 4096
- Temperature: 0.7

### If using `config.optimized.yaml`

Use: `./configure-opencode.sh --optimized`

Both configurations will have:
- Max tokens: 8192
- Temperature: 0.3
- Penalties enabled

## Switching Configurations

### Switch to Optimized (Recommended)

```bash
# 1. Update server config
cd /Users/s/Projects/mlx-serv
cp config.optimized.yaml config.yaml

# 2. Restart server
./start.sh --restart

# 3. Update OpenCode config
./configure-opencode.sh --optimized
```

### Switch to Default

```bash
# 1. Restore server config
cd /Users/s/Projects/mlx-serv
git checkout config.yaml
# OR manually edit config.yaml to restore defaults

# 2. Restart server
./start.sh --restart

# 3. Update OpenCode config
./configure-opencode.sh
```

## Verifying the Integration

### Test 1: Server Health

```bash
cd /Users/s/Projects/mlx-serv
./test.sh
```

### Test 2: Manual API Test

```bash
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test" \
  -d '{
    "model": "claude-coder-fake",
    "messages": [
      {"role": "user", "content": "Write a Python hello world"}
    ],
    "max_tokens": 100
  }'
```

### Test 3: OpenCode Test

1. Launch OpenCode
2. Open or create a file
3. Ask OpenCode to generate code
4. Verify responses are coming from your local server

## Troubleshooting

### OpenCode Can't Connect

**Check 1: Is the server running?**
```bash
cd /Users/s/Projects/mlx-serv
./start.sh --status
```

**Check 2: Can you reach the endpoint?**
```bash
curl http://localhost:4000/health
curl http://localhost:4000/v1/models
```

**Check 3: Is OpenCode config correct?**
```bash
cat ~/.config/opencode/config.json
# Verify baseURL is: http://localhost:4000/v1
# Verify model is: claude-coder-fake
```

### Slow Responses

1. **First request is always slow** (30-45s) - this is normal (model loading)
2. **Subsequent requests** should be faster (2-10s depending on complexity)
3. **Check if using optimized config**:
   ```bash
   grep temperature ~/.config/opencode/config.json
   # 0.3 = optimized, 0.7 = default
   ```

### Wrong Model Responses

If OpenCode is using cloud API instead of local:

```bash
# Verify baseURL in config
grep baseURL ~/.config/opencode/config.json
# Should show: http://localhost:4000/v1

# Re-run configuration
./configure-opencode.sh --optimized
```

### Configuration Not Working

```bash
# Backup current config
cp ~/.config/opencode/config.json ~/.config/opencode/config.json.backup

# Re-run automated configuration
./configure-opencode.sh --optimized

# Restart OpenCode
```

## Advanced Configuration

### Custom Temperature

Edit `~/.config/opencode/config.json`:

```json
{
  "provider": {
    "anthropic": {
      "models": {
        "claude-coder-fake": {
          "options": {
            "temperature": 0.2  // Lower = more deterministic
          }
        }
      }
    }
  }
}
```

Temperature guide:
- `0.0-0.2`: Very focused, deterministic (good for code completion)
- `0.3-0.5`: Balanced (recommended for general coding)
- `0.6-0.8`: More creative (good for brainstorming)
- `0.9-1.0`: Very creative (not recommended for code)

### Custom Max Tokens

```json
{
  "provider": {
    "anthropic": {
      "models": {
        "claude-coder-fake": {
          "options": {
            "maxTokens": 16384  // Very long outputs
          }
        }
      }
    }
  }
}
```

Note: Longer max_tokens = slower responses

### Multiple Models

If you want to serve multiple models:

1. **Start additional MLX-LM servers on different ports**
2. **Update LiteLLM config** (`config.yaml`) with multiple models
3. **Update OpenCode config** with both models:

```json
{
  "provider": {
    "anthropic": {
      "models": {
        "claude-coder-fake": {
          "options": { "maxTokens": 8192 }
        },
        "qwen-coder-3b": {
          "options": { "maxTokens": 4096 }
        }
      }
    }
  }
}
```

## Performance Tuning

### For Faster Responses

1. **Use optimized config**: `./configure-opencode.sh --optimized`
2. **Lower temperature**: 0.2-0.3
3. **Reduce max tokens**: 4096 or less
4. **Keep server running**: Avoid stopping/starting (cold start penalty)

### For Better Quality

1. **Use default config**: `./configure-opencode.sh`
2. **Higher temperature**: 0.5-0.7
3. **More max tokens**: 8192+
4. **Enable streaming**: Already on by default

## Daily Workflow

### Morning (Start of Day)

```bash
# 1. Start the server
cd /Users/s/Projects/mlx-serv
./start.sh

# 2. Verify it's working
./test.sh

# 3. Start coding with OpenCode!
```

### Evening (End of Day)

```bash
# Optional: Stop the server to free memory
cd /Users/s/Projects/mlx-serv
./start.sh --stop
```

Or just leave it running for instant access next time!

## Configuration Backups

The `configure-opencode.sh` script automatically creates backups:

```bash
# List backups
ls -la ~/.config/opencode/config.json.backup-*

# Restore a backup
cp ~/.config/opencode/config.json.backup-20260123-140000 \
   ~/.config/opencode/config.json
```

## Environment Variables (Alternative)

Instead of config file, you can use environment variables:

```bash
# In your ~/.zshrc or ~/.bashrc
export ANTHROPIC_API_KEY="local"
export ANTHROPIC_BASE_URL="http://localhost:4000"
```

Then restart your shell:
```bash
source ~/.zshrc  # or ~/.bashrc
```

## Monitoring Usage

### Watch logs in real-time

```bash
cd /Users/s/Projects/mlx-serv
./start.sh --logs
```

You'll see each request/response as OpenCode uses the model.

### Check server status anytime

```bash
cd /Users/s/Projects/mlx-serv
./start.sh --status
```

## FAQ

**Q: Do I need internet for this to work?**
A: No! Once the model is downloaded and OpenCode is configured, everything works offline.

**Q: Can I use this with other tools besides OpenCode?**
A: Yes! Any tool that supports Anthropic API can be configured to use `http://localhost:4000`

**Q: Will OpenCode still use cloud API for other models?**
A: Only if you configure other models. The `claude-coder-fake` model will always use your local server.

**Q: Can I use the optimized config with default server config?**
A: Yes, but it's better to match them for consistency. Use either both default or both optimized.

**Q: How do I know if OpenCode is using local vs cloud?**
A: Check the server logs: `./start.sh --logs` - you'll see requests when OpenCode uses local server.

## Getting Help

1. **Check server status**: `./start.sh --status`
2. **Run tests**: `./test.sh`
3. **View logs**: `./start.sh --logs`
4. **Reconfigure**: `./configure-opencode.sh --optimized`
5. **See full docs**: `cat README.md`

---

**Summary**: Run `./configure-opencode.sh --optimized` once, then use OpenCode normally. The local model will be available as `claude-coder-fake`!
