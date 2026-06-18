#!/bin/bash
set -euo pipefail

# Verification Checklist for Local LLM Stack
# Run after 'docker compose up -d'

PASS=0
FAIL=0

log_pass() { echo "  [PASS] $1"; ((PASS++)) || true; }
log_fail() { echo "  [FAIL] $1"; ((FAIL++)) || true; }

# Dependency check
if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not installed. Install it first:"
    echo "  sudo apt-get install jq"
    exit 1
fi

if ! command -v docker &>/dev/null; then
    echo "ERROR: docker is required but not installed."
    exit 1
fi

echo "=== Local LLM Stack Verification ==="
echo ""

# 1. Docker & GPU
echo "[1/6] Docker GPU access..."
if docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi &>/dev/null; then
    log_pass "NVIDIA Container Toolkit working"
else
    log_fail "NVIDIA Container Toolkit not working"
fi

# 2. Containers running
echo "[2/6] Containers status..."
for c in vllm-primary vllm-utility litellm-proxy; do
    if docker ps --format '{{.Names}}' | grep -q "^${c}$"; then
        log_pass "$c is running"
    else
        log_fail "$c is NOT running"
    fi
done

# 3. vLLM health
echo "[3/6] vLLM health endpoints..."
if curl -sf http://127.0.0.1:8001/health &>/dev/null; then
    log_pass "vllm-primary health OK"
else
    log_fail "vllm-primary health FAILED"
fi

if curl -sf http://127.0.0.1:8002/health &>/dev/null; then
    log_pass "vllm-utility health OK"
else
    log_fail "vllm-utility health FAILED"
fi

# 4. LiteLLM models list
echo "[4/6] LiteLLM model list..."
MASTER_KEY="${LITELLM_MASTER_KEY:-$(grep LITELLM_MASTER_KEY .env 2>/dev/null | cut -d= -f2 || true)}"
if [ -n "$MASTER_KEY" ]; then
    MODELS=$(curl -sf http://127.0.0.1:4000/v1/models \
        -H "Authorization: Bearer $MASTER_KEY" 2>/dev/null | jq -r '.data[].id' 2>/dev/null || true)
    if echo "$MODELS" | grep -q "qwen-primary"; then
        log_pass "qwen-primary registered in LiteLLM"
    else
        log_fail "qwen-primary NOT found in LiteLLM"
    fi
    if echo "$MODELS" | grep -q "qwen-coder"; then
        log_pass "qwen-coder registered in LiteLLM"
    else
        log_fail "qwen-coder NOT found in LiteLLM"
    fi
else
    log_fail "LITELLM_MASTER_KEY not found in environment or .env"
fi

# 5. Simple chat completion
echo "[5/6] Chat completion smoke test..."
if [ -n "$MASTER_KEY" ]; then
    RESP=$(curl -sf http://127.0.0.1:4000/v1/chat/completions \
        -H "Authorization: Bearer $MASTER_KEY" \
        -H "Content-Type: application/json" \
        -d '{"model":"qwen-coder","messages":[{"role":"user","content":"Say hello"}],"max_tokens":10}' 2>/dev/null || true)
    if echo "$RESP" | grep -q '"content"'; then
        log_pass "Chat completion responded"
    else
        log_fail "Chat completion did not respond correctly"
    fi
else
    log_fail "Skipping chat test (no master key)"
fi

# 6. GPU utilization
echo "[6/6] GPU visibility..."
GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | wc -l)
if [ "$GPU_COUNT" -ge 3 ]; then
    log_pass "Found $GPU_COUNT GPUs (expected 3x RTX 3090)"
else
    log_fail "Found $GPU_COUNT GPU(s) (expected 3)"
fi

echo ""
echo "=========================="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "=========================="

if [ "$FAIL" -eq 0 ]; then
    echo "All checks passed. Stack is ready."
    exit 0
else
    echo "Some checks failed. Review logs above."
    exit 1
fi
