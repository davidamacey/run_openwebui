# Open WebUI with Local AI Models

Run AI models **100% locally** on your home server — no API keys, no cloud costs, no data leaving your network. This Docker Compose setup gives you a production-ready AI stack with a beautiful web interface.

## What You Get

- **Gemma4 E4B** — Google's Gemma 4 4B multimodal model: text + vision (images) + audio, 128K context, served via vLLM
- **Docling** — GPU-accelerated document/PDF extraction (replaces Apache Tika as the primary extractor)
- **Apache Tika** — Document extraction fallback (stays running alongside Docling)
- **Open WebUI** — Chat interface with dark mode, conversation history, and model switching
- **100% Private** — Everything runs locally; your data never leaves your server

Additional services are available as commented-out blocks (see below).

## Hardware Requirements

### Reference Setup (this repo's active configuration)

| GPU | Model | VRAM | Role |
|-----|-------|------|------|
| GPU 0 | RTX A6000 | 48 GB | Reserved / testing |
| GPU 1 | RTX 3080 Ti | 12 GB | Docling (GPU-accelerated OCR) |
| GPU 2 | RTX A6000 | 48 GB | vLLM — Gemma4 E4B (128K context) |

### Minimum Requirements

- NVIDIA GPU with at least 8 GB VRAM (for Gemma4 E4B in BF16)
- 32 GB system RAM
- Docker with NVIDIA Container Toolkit installed

### Model VRAM Requirements

| Model | VRAM | Notes |
|-------|------|-------|
| Gemma4 E4B BF16 | ~15 GB | 128K context; full vision + audio |
| Gemma4 31B AWQ INT4 | ~20 GB | 64K context; vision broken under fp16 — see Known Issues |
| GPT-OSS 20B | ~16 GB | Text only |
| GPT-OSS 120B | ~96 GB | Requires 2× A6000 |
| Llama 3.2 11B Vision | ~24 GB | |
| Docling (GPU) | ~4 GB | CUDA 12.8 image, works with 13.0 driver |

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository>
   cd run_openwebui
   ```

2. **Create your `.env` file**
   ```bash
   cp .env.example .env
   # Edit .env and fill in your HuggingFace token and a secret key
   ```
   - `HUGGING_TOKEN2`: Token from [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens)
   - Accept model terms at [huggingface.co/google/gemma-4-E4B-it](https://huggingface.co/google/gemma-4-E4B-it)

3. **Create required host directories**
   ```bash
   sudo mkdir -p /mnt/nas/hf_vllm_models
   sudo mkdir -p /mnt/nas/vllm_compile_cache
   sudo mkdir -p /mnt/nas/gpt-oss-cache/torchinductor
   sudo mkdir -p /mnt/nas/gpt-oss-cache/torch_extensions
   sudo mkdir -p /mnt/nas/gpt-oss-cache/triton_cache
   sudo mkdir -p /mnt/nas/gpt-oss-cache/nvrtc_cache
   sudo mkdir -p /mnt/nas/ollama_webui/webui
   ```

4. **Adjust GPU assignments** in `docker-compose.yaml` to match your hardware:
   ```yaml
   CUDA_VISIBLE_DEVICES: "2"   # single GPU
   CUDA_VISIBLE_DEVICES: "0,2" # multi-GPU (tensor parallel)
   ```

5. **Start services**
   ```bash
   docker compose up -d
   ```

6. **Access the interfaces**
   - Open WebUI: `http://localhost:8010`

## Services

### Always Active

| Service | Port | Description |
|---------|------|-------------|
| Open WebUI | 8010 | Chat interface |
| Apache Tika | 8009 | Document/PDF extraction (fallback) |
| Docling | 5001 | GPU-accelerated document extraction (primary) |
| vllm-gemma4-e4b | 8012 | Gemma4 4B — text + vision + audio, 128K context |

### Optional (Commented Out — Uncomment to Enable)

| Service | Port | VRAM | Description |
|---------|------|------|-------------|
| vllm-gemma4-31b | 8012 | ~20 GB | Gemma4 31B AWQ — text + vision (64K context; see Known Issues) |
| vllm-gptoss-20b | 8012 | ~16 GB | GPT-OSS 20B text model |
| vllm-gptoss-120b | 8011 | ~96 GB | GPT-OSS 120B (2× A6000) |
| vllm-llama32-11b-vision | 8015 | ~24 GB | Llama 3.2 11B vision/text |
| comfyui | 8188 | ~32 GB | Flux image generation |
| ollama | 11434 | varies | Fallback for non-vLLM models |

## Switching Models

Only one vLLM service should be active on a given GPU at a time. To switch:

1. Comment out the current active service block (e.g., `vllm-gemma4-e4b`)
2. Uncomment the target service block (e.g., `vllm-gemma4-31b`)
3. Update `OPENAI_API_BASE_URL` in the `open-webui` environment to point to the new container name
4. Run `docker compose up -d`

## Document Extraction

Docling is the primary extraction engine. It runs on GPU 1 (3080 Ti) and handles PDFs, images, and complex layouts with high accuracy. Apache Tika runs alongside it as a lightweight fallback.

In Open WebUI: **Admin → Settings → Documents** should show Docling as the active engine.

The Docling image (`docling-serve-cu128`) bundles all OCR models — no separate download required.

## Known Issues

### Gemma4 vision returns `<pad>` tokens under FP16 (vLLM issue #40290)

**Symptom**: All image inputs return only `<pad>` tokens regardless of the image.

**Root cause**: Gemma4's SigLIP vision encoder is stored in BF16 in the checkpoint. When vLLM loads the model in FP16 (default), the standardize step in the vision tower overflows, producing degenerate embeddings.

**Fix**: Always use `--dtype bfloat16` for any Gemma4 model served via vLLM. This applies to all sizes — E4B, 31B AWQ, etc. The `vllm-gemma4-e4b` service already includes this flag.

The commented-out `vllm-gemma4-31b` block preserves the AWQ configuration. Note that the 31B AWQ model has this same vision bug AND is limited to ~11K context on a single A6000 due to KV memory pressure — the E4B model is the recommended replacement.

## Troubleshooting

- **Out of Memory**: Reduce `--gpu-memory-utilization` or `--max-model-len`
- **Model not loading**: Check that volume mounts under `/mnt/nas/` exist and are writable
- **Connection refused**: Verify all services are on the `oi_net` Docker network
- **Docling not processing PDFs**: Check `docker compose logs docling` — first run may take a minute to initialize
- **Open WebUI not using Docling**: Go to Admin → Settings → Documents and confirm the engine is set to Docling
