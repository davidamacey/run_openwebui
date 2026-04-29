# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

Docker Compose stack for running Open WebUI with local AI models on a home server. Active services:

- **Open WebUI** — chat interface (port 8010)
- **vllm-gemma4-e4b** — Gemma4 4B, BF16, 128K context, text + vision + audio (port 8012, GPU 2)
- **Docling** — GPU-accelerated document/PDF extraction (port 5001, GPU 1)
- **Apache Tika** — document extraction fallback (port 8009)

Additional services are preserved as commented-out YAML blocks.

## Commands

```bash
# Start all services
docker compose up -d

# Start specific service
docker compose up -d vllm-gemma4-e4b

# View logs
docker compose logs -f vllm-gemma4-e4b

# Stop services
docker compose down

# Health checks
curl http://localhost:8010        # Open WebUI
curl http://localhost:8012/health # vLLM
curl http://localhost:5001/health # Docling
curl http://localhost:8009        # Tika
```

## Architecture

### GPU Assignment

| GPU | Hardware | VRAM | Role |
|-----|----------|------|------|
| 0 | RTX A6000 | 48 GB | Reserved / testing |
| 1 | RTX 3080 Ti | 12 GB | Docling |
| 2 | RTX A6000 | 48 GB | vllm-gemma4-e4b |

### Network and Volumes

- All services use the `oi_net` bridge network and communicate by container name
- Model cache and weights stored under `/mnt/nas/` — must exist before first `docker compose up`

### Port Mappings

| Port | Service |
|------|---------|
| 8010 | Open WebUI |
| 8012 | vLLM (active model) |
| 5001 | Docling |
| 8009 | Apache Tika |

### Key Environment Variables (in `.env`)

- `HUGGING_TOKEN2` — HuggingFace read token; required for gated models (Gemma4)
- `WEBUI_SECRET_KEY` — Open WebUI session key

## Known Issues

### Gemma4 vision FP16 bug (vLLM issue #40290)

All Gemma4 sizes output only `<pad>` tokens for image inputs when `dtype=float16`. Root cause: BF16 overflow in SigLIP vision tower standardize step. Fix: `--dtype bfloat16`. The active `vllm-gemma4-e4b` service already includes this flag.

The commented-out `vllm-gemma4-31b` block is preserved for reference — do not use it without `--dtype bfloat16` if vision is needed.
