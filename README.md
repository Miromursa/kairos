# Local LLM Stack

3-tier agentic coding stack for local network deployment on 3x RTX 3090.

## Quick Start

### 1. Prepare the server

```bash
# Install NVIDIA Container Toolkit if not already present
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Create project directory
sudo mkdir -p /opt/llm-stack
sudo chown $USER:$USER /opt/llm-stack
```

### 2. Copy files

```bash
# From this repo / archive
cp -r docker-compose.yml .env .gitignore configs scripts docs systemd /opt/llm-stack/
cd /opt/llm-stack
```

### 3. Configure environment

Edit `.env`:
- Set `HF_TOKEN` to your HuggingFace token
- Set `LITELLM_MASTER_KEY` to a generated secret
- Adjust `PROJECT_DIR` and `HF_CACHE_DIR` paths if needed
- Replace `<your-server-lan-ip>` with the actual LAN IP

### 4. Launch

```bash
docker compose up -d
```

First start downloads models. Monitor with:

```bash
docker logs -f vllm-primary
docker logs -f vllm-utility
```

### 5. Verify

```bash
chmod +x scripts/verify.sh
./scripts/verify.sh
```

### 6. Enable auto-start (optional)

```bash
sudo cp systemd/llm-stack.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now llm-stack
```

### 7. Install agents

```bash
chmod +x scripts/install-agents.sh
./scripts/install-agents.sh
```

Then configure each agent to point at `http://<lan-ip>:4000/v1`.

## Directory Layout

```
.
├── docker-compose.yml          # vLLM + LiteLLM services (pinned tags)
├── .env                        # Secrets & model selections (chmod 600)
├── .gitignore                  # Prevents committing secrets
├── configs/
│   └── litellm_config.yaml     # Model routing & fallbacks
├── scripts/
│   ├── install-agents.sh      # Clone & setup gjc, claw, lazycodex
│   └── verify.sh              # Post-deploy health checks
├── systemd/
│   └── llm-stack.service      # Auto-start on boot
└── docs/
    ├── ARCHITECTURE.md         # Stack diagram & data flow
    ├── OPERATIONS.md           # Start/stop, logs, updates
    ├── TROUBLESHOOTING.md      # Common issues & fixes
    └── NETWORK.md              # Firewall & LAN setup
```

## Docs

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — How the pieces fit together
- [`docs/OPERATIONS.md`](docs/OPERATIONS.md) — Day-to-day commands
- [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) — When things break
- [`docs/NETWORK.md`](docs/NETWORK.md) — Security & LAN setup
