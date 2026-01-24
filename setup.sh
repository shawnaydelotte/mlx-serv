#!/bin/bash
# =====================================================================
#   Complete MLX + mlx-lm + LiteLLM Setup Script for Mac (Anthropic-Compatible API)
#   Assumes: Homebrew installed, default Python 3.9.6.
#   This script:
#     - Installs Python 3.12 via Homebrew
#     - Creates/activates venv in current directory
#     - Installs mlx-lm and litellm
#     - Downloads/quantizes Qwen2.5-Coder-7B model (4-bit) to current directory
#     - Starts mlx-lm server
#     - Creates LiteLLM config for Anthropic compatibility
#     - Starts LiteLLM proxy
#   All operations confined to current directory where script is run.
# =====================================================================

set -e  # Exit on any error

# Step 1: Update Homebrew and install Python 3.12
echo "→ Updating Homebrew and installing Python 3.12..."
brew update
brew install python@3.12

# Step 2: Create and activate virtual environment in current directory
echo "→ Creating virtual environment in current directory..."
python3.12 -m venv ./mlx-env
source ./mlx-env/bin/activate

# Step 3: Upgrade pip and install dependencies
echo "→ Upgrading pip and installing mlx-lm + litellm..."
pip install --upgrade pip setuptools wheel
pip install mlx-lm litellm

# Step 3.5: Install MCP server dependencies
echo "→ Installing MCP server dependencies..."
pip install -r mcp-servers/requirements.txt

# Step 4: Download and quantize model (Qwen2.5-Coder-7B to 4-bit) in current directory
echo "→ Downloading and quantizing Qwen2.5-Coder-7B model..."
mlx_lm.convert --hf-path Qwen/Qwen2.5-Coder-7B-Instruct --mlx-path ./qwen-coder-7b-4bit --q-bits 4

# Step 5: Start mlx-lm server in background
echo "→ Starting mlx-lm server on port 8080..."
nohup python -m mlx_lm.server --model ./qwen-coder-7b-4bit --port 8080 > mlx_server.log 2>&1 &
echo "mlx-lm server PID: $!"
sleep 5  # Wait for server to start

# Step 6: Create LiteLLM config.yaml for Anthropic compatibility
echo "→ Creating LiteLLM config.yaml..."
cat << EOF > config.yaml
model_list:
  - model_name: claude-coder-fake
    litellm_params:
      model: openai/mlx-community/Qwen2.5-Coder-7B-Instruct-4bit
      api_base: http://localhost:8080/v1
      api_key: dummy-key-local
      max_tokens: 4096
      temperature: 0.7
EOF

# Step 7: Start LiteLLM proxy in background
echo "→ Starting LiteLLM proxy on port 4000..."
nohup litellm --config config.yaml --port 4000 > litellm_proxy.log 2>&1 &
echo "LiteLLM proxy PID: $!"
sleep 5  # Wait for proxy to start

echo ""
echo "===================================================="
echo "           Setup complete! 🎉"
echo ""
echo " - mlx-lm server running at http://localhost:8080/v1"
echo " - LiteLLM proxy (Anthropic-compatible) at http://localhost:4000/v1"
echo " - Model ready: Use 'claude-coder-fake' in Anthropic clients"
echo " - Logs: mlx_server.log and litellm_proxy.log"
echo ""
echo "To activate venv in future: source ./mlx-env/bin/activate"
echo "To stop servers: kill the PIDs above or use 'pkill -f mlx_lm.server' and 'pkill -f litellm'"
echo "Test with Anthropic SDK example in docs."
echo "===================================================="

echo ""
echo "→ Downloading Qwen2.5-Coder-3B-Instruct-4bit model..."
echo "  This will take 5-8 minutes depending on connection speed."

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
    echo "✓ 3B model already exists"
fi
