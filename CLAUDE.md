# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository provides Docker Compose configurations for running Open WebUI with various AI services on a home server with 2 A6000s and 1 3080Ti GPUs. The stack includes:
- Open WebUI (chat interface)
- vLLM servers running GPT-OSS models
- ComfyUI for Flux image generation
- Apache Tika for document/OCR extraction
- Optional: Ollama for non-vLLM compatible models

## Commands

### Start Services
```bash
# Start all services
docker compose up -d

# Start specific service
docker compose up -d open-webui

# View logs
docker compose logs -f [service-name]

# Stop services
docker compose down
```

### Service Health Check
```bash
# Check running containers
docker ps

# Check service endpoints
curl http://localhost:8010  # Open WebUI
curl http://localhost:8012/health  # vLLM GPT-OSS-20B
curl http://localhost:8188  # ComfyUI
curl http://localhost:8009  # Tika
```

## Architecture

### Service Configuration
- **Network**: All services communicate via `oi_net` bridge network
- **Volume Mounts**: Models and cache stored in `/mnt/nas/` directories
- **GPU Assignment**: 
  - GPU 0: ComfyUI (Flux image generation)
  - GPU 2: vLLM GPT-OSS-20B (text generation)
  - GPUs 0,2: vLLM GPT-OSS-120B (when enabled)

### Port Mappings
- 8010: Open WebUI interface
- 8012: vLLM GPT-OSS-20B API
- 8188: ComfyUI interface
- 8009: Apache Tika document extraction

### Key Environment Variables
- `HUGGING_TOKEN2`: Required for ComfyUI model downloads
- `WEBUI_DOCKER_TAG`: Open WebUI version (default: main)
- `LOW_VRAM`: ComfyUI memory optimization flag

### Model Configuration
- GPT-OSS models served via vLLM with OpenAI-compatible API
- ComfyUI workflow configured for Flux1-dev with 1024x1024 image generation
- Models cached in shared NAS volumes for efficient loading