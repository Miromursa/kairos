# Troubleshooting

## vLLM fails to start / OOM

**Symptom**: Container exits immediately, logs show `CUDA out of memory`

**Causes & Fixes**:
- Model too large for allocated GPUs
  - Default models: 32B-AWQ primary (TP=2), 7B-FP16 utility (single GPU). If you changed to larger models:
    - Switch to AWQ/INT4 quantization in `.env`
    - Reduce `--max-model-len` in `docker-compose.yml`
    - Lower `--gpu-memory-utilization` (e.g., 0.85)
- Tensor parallel misconfiguration
  - Ensure `--tensor-parallel-size` matches the number of GPUs assigned
  - Verify `NVIDIA_VISIBLE_DEVICES` lists contiguous GPUs

## LiteLLM cannot reach vLLM

**Symptom**: `404` or `Connection refused` when calling LiteLLM

**Fixes**:
```bash
# Verify vLLM is actually up
docker compose ps

# Check internal DNS resolution
docker run --rm --network llm-stack alpine nslookup vllm-primary

# If unhealthy, inspect logs
docker logs vllm-primary
```

## Model download is extremely slow

**Fixes**:
- Ensure `HF_TOKEN` is valid (gated models require it)
- Use a HuggingFace mirror if in a region with slow connectivity:
  ```yaml
  environment:
    - HF_ENDPOINT=https://hf-mirror.com
  ```
- Pre-download models with `huggingface-cli` on host before starting containers

## Agent says "model not found"

**Fixes**:
- Check model alias matches exactly what's in `litellm_config.yaml`
- Verify LiteLLM is returning the model:
  ```bash
  curl http://localhost:4000/v1/models
  ```
- Ensure agent's `OPENAI_BASE_URL` ends with `/v1`

## Tool calling not working

**Symptom**: Model returns plain text instead of structured tool calls

**Fixes**:
- Verify vLLM started with `--enable-auto-tool-choice` and the correct parser:
  - Qwen2.5 models: `--tool-call-parser qwen`
  - Qwen3 models: `--tool-call-parser qwen3_xml`
- Ensure the model actually supports tool calling (Qwen2.5+ does)
- vLLM auto-loads chat templates from the tokenizer. If you overrode with `--chat-template`, verify the template file exists and is correct

## Port already in use

**Fixes**:
```bash
# Find what's using port 4000
sudo ss -tlnp | grep 4000

# Kill or reassign, then restart
docker compose restart litellm-proxy
```

## Docker cannot see GPUs

**Fixes**:
```bash
# Verify NVIDIA Container Toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Test
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```

## High latency / slow generation

**Tuning**:
- Increase `--max-num-seqs` (default 256) if you expect many concurrent requests
- Enable chunked prefill: add `--enable-chunked-prefill` to vLLM command
- For single-user agent workflows, latency is usually fine; throughput matters more for shared use

## "Unauthorized" from LiteLLM

**Fix**: Pass the master key in your request header:
```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{"model":"qwen-primary","messages":[{"role":"user","content":"hi"}]}'
```
