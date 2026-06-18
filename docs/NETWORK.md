# Network Configuration

## Design Principle

Everything runs on the local network. No public exposure. Cloud endpoints are opt-in only.

## IP Map (Example)

| Service           | Bind Address      | Port | Reachable From |
|-------------------|-------------------|------|----------------|
| LiteLLM Proxy     | `0.0.0.0`         | 4000 | LAN clients    |
| vLLM Primary      | `127.0.0.1`       | 8001 | localhost only |
| vLLM Utility      | `127.0.0.1`       | 8002 | localhost only |

Replace `<your-server-lan-ip>` in `.env` with your server's actual LAN IP (e.g., `192.168.1.100`).

## Firewall Rules (UFW Example)

```bash
# Default deny incoming
sudo ufw default deny incoming

# Allow SSH from LAN
sudo ufw allow from 192.168.1.0/24 to any port 22

# Allow LiteLLM from LAN only
sudo ufw allow from 192.168.1.0/24 to any port 4000

# Deny vLLM ports from anywhere (already localhost-only, but belt+suspenders)
sudo ufw deny 8001
sudo ufw deny 8002

# Enable
sudo ufw enable
```

## Agent Configuration

All agents must point at the LiteLLM proxy, not directly at vLLM:

```bash
export OPENAI_BASE_URL=http://192.168.1.100:4000/v1
export OPENAI_API_KEY=sk-litellm-admin-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## No Internet / Air-Gapped

If the server has no internet:
- Download models beforehand on another machine
- Transfer the HuggingFace cache directory (`~/.cache/huggingface`) to the server
- All containers use pre-mounted cache volumes; no download needed

## Enabling Cloud Fallback

When you explicitly want to use Anthropic or OpenAI:

1. Add keys to `.env`:
   ```bash
   ANTHROPIC_API_KEY=sk-ant-...
   OPENAI_API_KEY=sk-...
   ```
2. Uncomment the cloud model blocks in `configs/litellm_config.yaml`
3. Restart LiteLLM
4. Agent requests will now route to cloud if local model is down or explicitly selected

To revert: re-comment the blocks and restart.

## Docker Network Isolation

- `vllm-primary` and `vllm-utility` live on the internal `llm-stack` bridge
- They are reachable by LiteLLM via Docker DNS (`vllm-primary`, `vllm-utility`)
- They are NOT exposed to the host LAN directly (only loopback ports are mapped)

This means even if someone on your LAN scans ports, they cannot hit vLLM directly — only LiteLLM (which you control via firewall).
