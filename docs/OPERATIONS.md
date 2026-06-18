# Operations Guide

## Start the Stack

```bash
cd /opt/llm-stack  # or wherever you placed the project
docker compose up -d
```

First start downloads the models (several minutes to hours depending on connection). Monitor with:

```bash
docker logs -f vllm-primary
docker logs -f vllm-utility
```

## Stop the Stack

```bash
docker compose down
```

To also remove volumes (not usually needed):

```bash
docker compose down -v
```

## View Logs

```bash
docker logs -f vllm-primary   # Primary model server
docker logs -f vllm-utility   # Utility / coder model
docker logs -f litellm-proxy  # Router & gateway
```

## Check Service Health

```bash
# vLLM primary
curl http://127.0.0.1:8001/health

# vLLM utility
curl http://127.0.0.1:8002/health

# LiteLLM models list
curl http://127.0.0.1:4000/v1/models \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"
```

## Update a Model

1. Edit `.env`, change `PRIMARY_MODEL` or `UTILITY_MODEL` to the new HuggingFace model ID
2. Stop the service:
   ```bash
   docker compose stop vllm-primary
   ```
3. Start again (new model downloads automatically):
   ```bash
   docker compose up -d vllm-primary
   ```

## Add a New Local Model

1. Add a new vLLM service block in `docker-compose.yml` (copy `vllm-utility`, adjust GPUs)
2. Add the model to `configs/litellm_config.yaml` under `model_list`
3. Restart LiteLLM:
   ```bash
   docker compose restart litellm-proxy
   ```

## Enable Cloud Fallback (Manual)

1. Edit `configs/litellm_config.yaml`
2. Uncomment the Anthropic / OpenAI model blocks
3. Add your API keys to `.env`:
   ```bash
   ANTHROPIC_API_KEY=sk-ant-...
   OPENAI_API_KEY=sk-...
   ```
4. Restart:
   ```bash
   docker compose restart litellm-proxy
   ```

To disable again, re-comment the blocks and restart.

## GPU Monitoring

```bash
watch -n 1 nvidia-smi
```

Expected layout:
- GPU 0 + 1: vLLM primary (both at ~90% utilization under load)
- GPU 2: vLLM utility (~60% under load, idle when not in use)

## Auto-Start on Boot

```bash
sudo cp /opt/llm-stack/systemd/llm-stack.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now llm-stack
```

After enabling, the stack starts automatically on reboot. Manage it with:

```bash
sudo systemctl status llm-stack   # Check status
sudo systemctl start llm-stack    # Start now
sudo systemctl stop llm-stack     # Stop now
sudo systemctl restart llm-stack  # Restart
```

## Backup & Restore

- `.env` — keep a secure copy (contains keys)
- `configs/` — version in git (no secrets stored here)
- HF cache — models are large; no need to back up, just re-download if needed
