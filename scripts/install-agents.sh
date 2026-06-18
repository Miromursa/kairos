#!/bin/bash
set -euo pipefail

# Agent Layer Installation Script
# Run on the target server after the vLLM + LiteLLM stack is up.

INSTALL_DIR="${INSTALL_DIR:-$HOME/llm-agents}"
LITELLM_URL="${LITELLM_URL:-http://localhost:4000}"

echo "=== Installing agent layers to $INSTALL_DIR ==="
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# ------------------------------------------------------------------
# 1. Gajae Code (gjc)
# ------------------------------------------------------------------
echo "[1/3] Installing Gajae Code..."
if [ ! -d "gajae-code" ]; then
    git clone https://github.com/Yeachan-Heo/gajae-code.git
fi
cd gajae-code
# Follow upstream install instructions (Node.js assumed installed)
if [ -f "package.json" ]; then
    npm install
    npm link
elif [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
    pip install -e .
fi
cd "$INSTALL_DIR"

# ------------------------------------------------------------------
# 2. Claw Code Agent (Python, zero-deps)
# ------------------------------------------------------------------
echo "[2/3] Installing Claw Code Agent (Python)..."
if [ ! -d "claw-code-agent" ]; then
    git clone https://github.com/HarnessLab/claw-code-agent.git
fi
cd claw-code-agent
# Zero external deps; just needs Python 3.10+
python3 --version
# Find the CLI entry point (may vary by upstream version)
CLI_ENTRY=""
for f in claw.py main.py codex.py; do
    [ -f "$f" ] && CLI_ENTRY="$f" && break
done
if [ -z "$CLI_ENTRY" ]; then
    echo "WARNING: No known CLI entry point found in claw-code-agent"
else
    chmod +x "$CLI_ENTRY"
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(pwd)/$CLI_ENTRY" "$HOME/.local/bin/claw"
fi
cd "$INSTALL_DIR"

# ------------------------------------------------------------------
# 3. LazyCodex (Codex plugin)
# ------------------------------------------------------------------
echo "[3/3] Installing LazyCodex..."
# Requires Node.js and OpenAI Codex CLI
if ! command -v codex &>/dev/null; then
    echo "Installing OpenAI Codex CLI..."
    npm install -g @openai/codex
fi
npx lazycodex-ai install --no-tui --codex-autonomous

# ------------------------------------------------------------------
# Configuration helpers
# ------------------------------------------------------------------
echo ""
echo "=== Agent Configuration ==="
echo "Point all agents at your LiteLLM proxy: $LITELLM_URL"
echo ""
echo "Claw Code Agent:"
echo "  export OPENAI_BASE_URL=$LITELLM_URL/v1"
echo "  export OPENAI_API_KEY=any-non-empty-string"
echo "  claw <args>"
echo ""
echo "LazyCodex / Codex CLI:"
echo "  export OPENAI_BASE_URL=$LITELLM_URL/v1"
echo "  export OPENAI_API_KEY=any-non-empty-string"
echo "  codex <args>"
echo ""
echo "Gajae Code:"
echo "  See gajae-code docs for configuration. Typically set base URL in config."
