# 🚀 Open WebUI with Local AI Models

Run ChatGPT-quality AI models **100% locally** on your home server - no API keys, no cloud costs, no data leaving your network. This Docker Compose setup gives you a production-ready AI stack with a beautiful web interface.

## ✨ What You Get

- 🤖 **GPT-OSS Models** - OpenAI's powerful open-source language models (20B & 120B parameters)
- 🎨 **Flux Image Generation** - State-of-the-art text-to-image with ComfyUI
- 📄 **Document Intelligence** - Extract and chat with PDFs, images, and documents via Apache Tika
- 💬 **Beautiful Chat Interface** - Open WebUI with dark mode, conversation history, and model switching
- 🔒 **100% Private** - Everything runs locally, your data never leaves your server
- ⚡ **Hardware Flexible** - Modular configuration adapts to your GPU setup

## Overview

This repository provides a plug-and-play Docker Compose configuration designed for home servers with NVIDIA GPUs. All services are pre-configured but commented out by default - simply uncomment what your hardware supports and deploy!

## Hardware Requirements

### Minimum Requirements
- NVIDIA GPU with at least 16GB VRAM
- 32GB system RAM
- Docker with NVIDIA Container Toolkit

### Model VRAM Requirements
- **GPT-OSS-20B**: ~16GB VRAM (1x A6000 or similar)
- **GPT-OSS-120B**: ~96GB VRAM (2x A6000)
- **Llama-3.2-11B-Vision**: ~24GB VRAM
- **ComfyUI Flux**: ~32GB VRAM

## 📋 Example Deployments

### Single A6000 (48GB)  
- **Enable**: Open WebUI, Tika, GPT-OSS-20B
- **Result**: Text generation with 20B model

### Dual A6000 (96GB) - Option 1
- **Enable**: Open WebUI, Tika, GPT-OSS-120B
- **Result**: Advanced text generation with 120B model

### Dual A6000 (96GB) - Option 2
- **Enable**: Open WebUI, Tika, GPT-OSS-20B, ComfyUI
- **GPU Assignment**: GPU 0 for ComfyUI, GPU 2 for GPT-OSS-20B
- **Result**: Full text + image generation stack

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository>
   cd run_openwebui
   ```

2. **Create .env file for Hugging Face token**
   ```bash
   echo "HUGGING_TOKEN2=your_hf_token_here" > .env
   ```
   > 📝 Get your token from [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens) - required for ComfyUI model downloads

3. **Configure your models**
   
   Edit `docker-compose.yaml` and uncomment the services your hardware supports based on the example deployments above

4. **Set GPU visibility**
   
   Adjust `CUDA_VISIBLE_DEVICES` in each service to match your GPU IDs:
   ```yaml
   environment:
     CUDA_VISIBLE_DEVICES: "0"  # Single GPU
     # CUDA_VISIBLE_DEVICES: "0,1"  # Multi-GPU
   ```

5. **Create required directories**
   ```bash
   sudo mkdir -p /mnt/nas/hf_vllm_models
   sudo mkdir -p /mnt/nas/ollama_webui/webui
   sudo mkdir -p /mnt/nas/hf_comfyui_models
   ```

6. **Start services**
   ```bash
   docker compose up -d
   ```

7. **Access the interfaces**
   - **Open WebUI**: `http://localhost:8010`
   - **ComfyUI**: `http://localhost:8188` (if enabled)

## Services

### Core Services (Always Enabled)
- **Open WebUI** (port 8010): Chat interface for all models
- **Apache Tika** (port 8009): Document/PDF extraction and OCR

### Optional Model Services (Uncomment as Needed)

#### Text Generation
- **vLLM GPT-OSS-20B** (port 8012): 20B parameter model for general text
- **vLLM GPT-OSS-120B** (port 8011): 120B parameter model for advanced tasks
- **vLLM Llama-3.2-11B-Vision** (port 8015): Multimodal vision/text model

#### Image Generation  
- **ComfyUI** (port 8188): Flux1-dev image generation

#### Fallback Models
- **Ollama** (port 11434): For models not compatible with vLLM

## Configuration Tips

### Selecting Models
Models are commented out to prevent deployment failures on systems with insufficient VRAM. Uncomment only the services your GPU(s) can handle:

```yaml
# Uncomment the services you want to enable:
services:
  # vllm-gptoss-120b:  # Requires 2x A6000
  vllm-gptoss-20b:     # Requires 1x A6000  
  # comfyui:           # Requires 32GB+ VRAM
```

### GPU Assignment
When running multiple services, assign different GPUs to avoid conflicts:

```yaml
# Service 1 on GPU 0
CUDA_VISIBLE_DEVICES: "0"

# Service 2 on GPU 1  
CUDA_VISIBLE_DEVICES: "1"

# Service using multiple GPUs
CUDA_VISIBLE_DEVICES: "0,2"
```

### Memory Optimization
For limited VRAM, adjust these parameters:
- `--gpu-memory-utilization`: Reduce from 0.95 to 0.90
- `--max-num-seqs`: Reduce concurrent requests
- `LOW_VRAM=true`: Enable for ComfyUI on <16GB cards

## Troubleshooting

- **Out of Memory**: Reduce `--max-model-len` or disable concurrent services
- **Models not loading**: Check volume mounts and ensure model files are downloaded
- **Connection refused**: Verify services are on the same Docker network (`oi_net`)
- **ComfyUI model download fails**: Ensure your Hugging Face token is set correctly in `.env`