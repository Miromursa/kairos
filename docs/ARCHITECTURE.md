# Architecture

## Overview

Local-only LLM serving stack for agentic coding, running on 3x NVIDIA RTX 3090 (72 GB VRAM total), 160 GB RAM, dual Xeon E5-2698.

## Stack Diagram

```
User / LAN Clients
        |
        v
+-------------------+
|   Agent Layer     |  gajae-code (gjc) — governance & worktrees
|                   |  claw-code-agent — execution & tool calling
|                   |  lazycodex — Codex plugin harness
+-------------------+
        |
        | OpenAI-compatible API (HTTP)
        v
+-------------------+
|  LiteLLM Proxy    |  Single endpoint, model routing, key management
|    (port 4000)    |  Cloud fallbacks: disabled by default (manual)
+-------------------+
        |
        | Internal Docker bridge
        v
+-------------------+     +-------------------+
|  vLLM Primary     |     |  vLLM Utility     |
|  GPUs 0 + 1       |     |  GPU 2            |
|  TP = 2           |     |  TP = 1           |
|  32B dense / AWQ  |     |  7B coder / FP16  |
|  (port 8001)      |     |  (port 8002)      |
+-------------------+     +-------------------+
```

## Component Responsibilities

### vLLM Primary (GPU 0+1)
- Role: General-purpose reasoning, planning, complex code generation
- Model: `Qwen2.5-32B-Instruct-AWQ` (recommended) or FP8 variant
- Tensor Parallel = 2 across dual 3090s
- Max context: 32K tokens
- Tool calling enabled (`--enable-auto-tool-choice`)

### vLLM Utility (GPU 2)
- Role: Fast coding assistance, inline completions, simpler tasks
- Model: `Qwen2.5-Coder-7B-Instruct`
- Single GPU, plenty of headroom
- Same tool-calling flags for consistency

### LiteLLM Proxy
- Role: API gateway
- Provides one OpenAI-compatible URL for all agents
- Maps model aliases (`qwen-primary`, `qwen-coder`) to backend vLLM instances
- Cloud providers present in config but commented out; enable by uncommenting + restart
- Master key protects admin endpoints

### Agent Layer
- **Gajae Code**: Initiates worktrees, shapes intent, plans execution
- **Claw Code Agent**: Python zero-dep agent; talks to LiteLLM via standard OpenAI client
- **LazyCodex**: Wraps OpenAI Codex CLI; configured to target local LiteLLM instead of OpenAI

## Data Flow

1. User invokes agent CLI (e.g., `gjc`, `claw`, `codex`)
2. Agent assembles prompt + tool definitions
3. HTTP POST to LiteLLM `:4000/v1/chat/completions`
4. LiteLLM routes to `vllm-primary` or `vllm-utility` based on model alias
5. vLLM generates response; tool calls parsed and returned
6. Agent executes tools; loop continues

## Network Boundaries

- All services bind to host LAN IP (e.g., `192.168.1.x`) or loopback
- No reverse proxy exposed to WAN
- Router/firewall blocks inbound on ports 4000, 8001, 8002
- Docker internal bridge (`llm-stack`) isolates vLLM containers from direct LAN access
