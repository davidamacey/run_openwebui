# Open WebUI with Local AI Models

Run AI models **100% locally** on your home server — no API keys, no cloud costs, no data leaving your network. This Docker Compose setup gives you a production-ready AI stack with a beautiful web interface.

## What You Get

- **Gemma4 E4B** — Google's Gemma 4 4B multimodal model: text + vision (images) + audio, 128K context, served via vLLM
- **Docling** — GPU-accelerated document/PDF extraction, primary extraction engine
- **Apache Tika** — Lightweight CPU document extraction, fallback alongside Docling
- **Open WebUI** — Chat interface with dark mode, conversation history, and model switching
- **100% Private** — Everything runs locally; your data never leaves your server

Additional model services are available as commented-out blocks (see [Optional Services](#optional-services-commented-out--uncomment-to-enable)).

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

| Model | VRAM | Context | Modalities | Notes |
|-------|------|---------|------------|-------|
| Gemma4 E4B BF16 | ~15 GB | 128K | Text + vision + audio | Recommended — full multimodal |
| Gemma4 31B AWQ INT4 | ~20 GB | ~11K | Text + vision | Limited context on single A6000; see [Known Issues](#known-issues) |
| GPT-OSS 20B | ~16 GB | 131K | Text only | |
| GPT-OSS 120B | ~96 GB | 131K | Text only | Requires 2× A6000 |
| Llama 3.2 11B Vision | ~24 GB | 32K | Text + vision | |
| Docling (GPU) | ~4 GB | — | — | CUDA 12.8 image, compatible with CUDA 13.0 driver |

---

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository>
   cd run_openwebui
   ```

2. **Create your `.env` file**
   ```bash
   cp .env.example .env
   # Edit .env and fill in your values
   ```
   - `HUGGING_TOKEN2`: Read token from [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens)
   - `WEBUI_SECRET_KEY`: Any random string — used to sign Open WebUI sessions
   - Accept model terms at [huggingface.co/google/gemma-4-E4B-it](https://huggingface.co/google/gemma-4-E4B-it) before first start

3. **Create required host directories** (model weights and compile caches live here)
   ```bash
   sudo mkdir -p /mnt/nas/hf_vllm_models
   sudo mkdir -p /mnt/nas/vllm_compile_cache
   sudo mkdir -p /mnt/nas/gpt-oss-cache/torchinductor
   sudo mkdir -p /mnt/nas/gpt-oss-cache/torch_extensions
   sudo mkdir -p /mnt/nas/gpt-oss-cache/triton_cache
   sudo mkdir -p /mnt/nas/gpt-oss-cache/nvrtc_cache
   sudo mkdir -p /mnt/nas/ollama_webui/webui
   ```
   > These paths are defined in the `x-common-volumes` anchor in `docker-compose.yaml`. Adjust them to match your storage layout.

4. **Adjust GPU assignments** to match your hardware — change `CUDA_VISIBLE_DEVICES` in each service:
   ```yaml
   CUDA_VISIBLE_DEVICES: "0"   # single GPU
   CUDA_VISIBLE_DEVICES: "0,1" # multi-GPU tensor parallel
   ```

5. **Start services**
   ```bash
   docker compose up -d
   ```
   First start downloads model weights (~8 GB for E4B). Monitor with:
   ```bash
   docker compose logs -f vllm-gemma4-e4b
   ```

6. **Access Open WebUI** at `http://localhost:8010`

---

## Services

### Always Active

| Service | Port | Description |
|---------|------|-------------|
| Open WebUI | 8010 | Chat interface |
| vllm-gemma4-e4b | 8012 | Gemma4 4B — text + vision + audio, 128K context |
| Docling | 5001 | GPU-accelerated document extraction (primary) |
| Apache Tika | 8009 | CPU document extraction (fallback) |

### Optional Services (Commented Out — Uncomment to Enable)

| Service | Port | VRAM | Context | Description |
|---------|------|------|---------|-------------|
| vllm-gemma4-31b | 8012 | ~20 GB | ~11K | Gemma4 31B AWQ INT4 — limited context on single GPU; see Known Issues |
| vllm-gptoss-20b | 8012 | ~16 GB | 131K | GPT-OSS 20B — text only |
| vllm-gptoss-120b | 8011 | ~96 GB | 131K | GPT-OSS 120B — text only, requires 2× A6000 |
| vllm-llama32-11b-vision | 8015 | ~24 GB | 32K | Llama 3.2 11B — text + vision |
| comfyui | 8188 | ~32 GB | — | Flux1-dev image generation |
| ollama | 11434 | varies | varies | Fallback for models not supported by vLLM |

---

## Switching Models

Only one vLLM service should be active on a given GPU at a time. To switch:

1. Comment out the current active service block (e.g., `vllm-gemma4-e4b`)
2. Uncomment the target service block (e.g., `vllm-gptoss-20b`)
3. Update `OPENAI_API_BASE_URL` in the `open-webui` environment to the new container name:
   ```yaml
   - OPENAI_API_BASE_URL=http://vllm-gptoss-20b:8000/v1
   ```
4. `docker compose up -d`

> **Important**: Gemma4 models require the `vllm/vllm-openai:gemma4-cu130` image, not `latest`. The `gemma4-cu130` tag is a Gemma4-specific vLLM build that includes the correct attention backend and chat template support. Using `latest` will fail or produce incorrect output.

---

## vLLM Configuration Reference

Each vLLM service passes flags to the `vllm serve` command. Here's what the key flags do and when to tune them:

### Memory and context

| Flag | Default in this repo | What it does |
|------|---------------------|--------------|
| `--max-model-len` | 131072 (E4B) | Maximum sequence length (prompt + output). Reduce if you get OOM on first load. |
| `--gpu-memory-utilization` | 0.90 | Fraction of GPU VRAM allocated to vLLM. Reduce to leave room for other processes. |
| `--max-num-seqs` | 8 (E4B) | Maximum concurrent requests. Reduce to lower memory usage at the cost of throughput. |
| `--swap-space` | not set (E4B) | CPU RAM (GB) used to offload KV cache blocks when GPU is full. Set to 32 if you want longer queues. |

### Reasoning and tool use

| Flag | What it does |
|------|--------------|
| `--reasoning-parser gemma4` | Enables structured reasoning output (thinking tokens). Gemma4 uses `<start_of_turn>thinking` blocks. |
| `--enable-auto-tool-choice` | Allows the model to call tools defined in the system prompt automatically. |
| `--tool-call-parser gemma4` | Parses Gemma4's tool call format from the output stream. |

These three flags together enable Open WebUI's tool/function calling features (web search, code execution, etc.). Remove them if you only need plain chat and want to reduce overhead.

### Multimodal

| Flag | What it does |
|------|--------------|
| `--limit-mm-per-prompt '{"image":4,"audio":1}'` | Maximum images and audio clips per request. E4B supports both; 31B supports images only. |
| `--chat-template /vllm-workspace/examples/tool_chat_template_gemma4.jinja` | Gemma4-specific chat template that correctly inserts `<\|image\|>` and `<\|audio\|>` tokens. Required for multimodal input. |
| `--dtype bfloat16` | Loads model weights in BF16. **Required for Gemma4** — see Known Issues. |

### Performance

| Flag | What it does |
|------|--------------|
| `--async-scheduling` | Enables async request scheduling for better throughput under concurrent load. |
| `VLLM_ATTENTION_BACKEND: TRITON_ATTN_VLLM_V1` | Forces the Triton attention kernel. Required for Gemma4 due to its heterogeneous head dimensions (head_dim=256 / global_head_dim=512). |

---

## Document Extraction: Docling vs Tika

Both services run simultaneously. Open WebUI uses Docling as the primary engine; Tika is available as a fallback.

| | Docling | Apache Tika |
|-|---------|-------------|
| **Best for** | Complex PDFs, scanned documents, tables, multi-column layouts, diagrams | Plain text extraction, Office files, simple PDFs |
| **Processing** | GPU-accelerated (ONNX vision models) | CPU only |
| **Accuracy** | High — layout-aware, preserves structure | Lower on complex layouts |
| **Speed** | Slower on first request (model warm-up) | Fast for simple documents |
| **Models** | Bundled in the Docker image (no separate download) | None — rule-based extraction |
| **Port** | 5001 | 8009 |

### Configuring in Open WebUI

After first start, go to **Admin Panel → Settings → Documents** and confirm:
- Content Extraction Engine: **Docling**
- Docling Server URL: `http://docling:5001`

To fall back to Tika only, change the engine to **Tika** and set URL to `http://tika:9998`.

### Using audio in Open WebUI (Gemma4 E4B)

Gemma4 E4B supports audio input natively. To send audio:
1. In Open WebUI, click the microphone/attachment icon in the chat input
2. Upload or record an audio file (WAV, MP3, or M4A)
3. The model receives it as a multimodal token — no transcription step needed

> Open WebUI may also have its own STT (speech-to-text) pipeline configured separately. The audio token path above sends the raw audio directly to the model; the STT pipeline transcribes first and sends text. Both work with this setup.

---

## Known Issues

### Gemma4 vision returns `<pad>` tokens under FP16 (vLLM issue #40290)

**Symptom**: All image inputs return only `<pad>` tokens regardless of the image content.

**Root cause**: Gemma4's SigLIP vision encoder is stored in BF16 in the model checkpoint. When vLLM loads the model in FP16 (its default), the standardize step in the vision tower overflows, producing degenerate embeddings that cause the LLM to output the pad token for every position.

**Fix**: Always use `--dtype bfloat16` for any Gemma4 model served via vLLM. This applies to all sizes — E4B, 31B AWQ, etc. The active `vllm-gemma4-e4b` service already includes this flag.

**Gemma4 31B AWQ**: The commented-out `vllm-gemma4-31b` block is preserved for reference. Beyond the fp16 vision bug, the 31B AWQ model is also limited to ~11K context on a single 48 GB A6000 due to KV cache memory pressure after weights are loaded. The E4B model at 128K context is the recommended replacement.

---

## Troubleshooting

- **OOM on startup**: Reduce `--max-model-len` or `--gpu-memory-utilization`. The E4B model at 128K context uses ~33 GB of KV cache headroom on a 48 GB GPU — reduce `--max-model-len` to 65536 to free ~16 GB.
- **Model stuck downloading**: First start downloads ~8 GB (E4B) from HuggingFace. Check `docker compose logs -f vllm-gemma4-e4b`. Ensure `HUGGING_TOKEN2` is set and model terms are accepted.
- **Connection refused on 8012**: vLLM takes 3–10 minutes on first start (compile cache is cold). Wait for `Application startup complete` in the logs.
- **Docling slow on first PDF**: The ONNX vision models warm up on first use — subsequent requests are faster.
- **Open WebUI not using Docling**: Go to Admin → Settings → Documents and verify the engine is set to Docling.
- **Services can't reach each other**: All services must be on the `oi_net` network. Check with `docker network inspect run_openwebui_oi_net`.
- **Wrong GPU used**: Verify `CUDA_VISIBLE_DEVICES` in each service. Use `CUDA_DEVICE_ORDER: PCI_BUS_ID` (already set in `x-common-env`) so GPU indices match `nvidia-smi` output.
