# Model Aliases Configuration

## Problem Solved

OpenCode (and other tools) may try to use standard Claude model names like `claude-haiku-4-5` instead of `claude-coder-fake`. To handle this, the server now provides multiple model aliases that all route to your local Qwen model.

## Available Model Names

All of these model names work and route to the same local model:

| Model Name | Purpose |
|------------|---------|
| `claude-coder-fake` | Original/primary name |
| `claude-haiku-4-5` | Latest Haiku alias |
| `claude-3-5-sonnet-20241022` | Sonnet 3.5 alias |
| `claude-3-5-haiku-20241022` | Haiku 3.5 alias |

## How It Works

The `config.yaml` and `config.optimized.yaml` files now include multiple model entries that all point to the same backend:

```yaml
model_list:
  - model_name: claude-coder-fake
    litellm_params:
      model: openai/mlx-community/Qwen2.5-Coder-7B-Instruct-4bit
      # ...

  - model_name: claude-haiku-4-5
    litellm_params:
      model: openai/mlx-community/Qwen2.5-Coder-7B-Instruct-4bit
      # ...same backend
```

## Testing

Verify all aliases work:

```bash
# List available models
curl http://localhost:4000/v1/models

# Test with different model names
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test" \
  -d '{"model":"claude-haiku-4-5","messages":[{"role":"user","content":"Hi"}]}'

curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test" \
  -d '{"model":"claude-3-5-sonnet-20241022","messages":[{"role":"user","content":"Hi"}]}'
```

## OpenCode Usage

OpenCode can now use any of these model names in its configuration:

```json
{
  "model": "anthropic/claude-haiku-4-5"
}
```

Or:

```json
{
  "model": "anthropic/claude-3-5-sonnet-20241022"
}
```

All will route to your local Qwen model.

## Adding More Aliases

To add more model aliases, edit `config.yaml` or `config.optimized.yaml`:

```yaml
model_list:
  # ... existing entries ...

  - model_name: your-custom-name
    litellm_params:
      model: openai/mlx-community/Qwen2.5-Coder-7B-Instruct-4bit
      api_base: http://localhost:8080/v1
      api_key: dummy-key-local
      max_tokens: 4096
      temperature: 0.7
```

Then restart the server:
```bash
./start.sh --restart
```

## Why This Matters

Different tools may be configured with different Claude model names:
- OpenCode might use `claude-haiku-4-5`
- Claude Code might use `claude-3-5-sonnet-20241022`
- Custom scripts might use `claude-coder-fake`

With aliases, they all work without reconfiguration!

## Performance Note

All aliases use the same backend model, so performance is identical regardless of which name you use. The name is just for compatibility with different tools.
