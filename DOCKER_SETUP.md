# Docker Setup for Hunyuan3D-2.1

This repository uses a unified Docker setup for preprocessing, fine-tuning, and Gradio demo.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Host Machine                              │
│                                                             │
│  ~/.cache/huggingface/     (42GB - Shared model cache)     │
│  ├── models--tencent--Hunyuan3D-2.1                        │
│  ├── models--facebook--dinov2-large                        │
│  └── models--black-forest-labs--FLUX.1-dev                 │
│                                                             │
│  ./output/                  (Training outputs & demos)      │
│  ./src/preprocessing/data/  (Your 3D models & processed)   │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Mounts shared cache
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Docker Image: hunyuan3d21:latest               │
│                         (33.4GB)                            │
│                                                             │
│  - PyTorch 2.5.1 + CUDA 12.4                               │
│  - All Hunyuan3D dependencies                              │
│  - Code only (no model weights)                            │
└─────────────────────────────────────────────────────────────┘
          │                   │                   │
          │                   │                   │
          ▼                   ▼                   ▼
    ┌─────────┐         ┌─────────┐        ┌─────────┐
    │Preproc  │         │Finetune │        │ Gradio  │
    │Container│         │Container│        │Container│
    └─────────┘         └─────────┘        └─────────┘
```

## All Services Share:
- ✅ **Same Docker image** (`hunyuan3d21:latest`)
- ✅ **Same model cache** (`~/.cache/huggingface/`)
- ✅ **Same output directory** (`./output/`)
- ✅ Models downloaded once, used everywhere

## Docker Compose Files

1. **docker-compose.preprocessing.yaml** - Data preprocessing with Blender
2. **docker-compose.finetuning.yaml** - Model fine-tuning
3. **docker-compose.gradio.yaml** - Web demo interface

## Available Commands

### Preprocessing
```bash
make preprocessing-example   # Process all .obj files in src/preprocessing/data/raw/
make preprocessing-shell     # Interactive shell for manual preprocessing
make preprocessing-clean     # Remove preprocessing container
```

### Fine-tuning
```bash
make finetune               # Start fine-tuning (interactive shell)
make finetune-shell         # Debug shell
make finetune-clean         # Stop and remove container

# Two fine-tuning approaches available:
# 1. Full fine-tuning: Requires 8 GPUs (98GB total VRAM)
#    Use: hunyuan3d-custom-finetuning.yaml
# 2. LoRA fine-tuning: Single GPU (44GB+ VRAM)
#    Use: hunyuan3d-custom-lora.yaml
```

### Gradio Demo
```bash
make gradio                 # Start web interface at http://localhost:7860
make gradio-shell           # Debug shell
make gradio-clean           # Stop and remove container
```

## Cleanup Instructions

### Safe to Delete

You can safely remove the old standalone container:

```bash
# Remove the old container (keeps the image)
docker rm hy3d21

# Check what's using space
docker system df
```

This container was from your previous Gradio runs and is no longer needed since we use docker-compose now.

### What NOT to Delete

**Keep these:**
- ❌ **Don't delete** `hunyuan3d21:latest` image (33.4GB) - shared by all services
- ❌ **Don't delete** `~/.cache/huggingface/` (42GB) - your downloaded models
- ❌ **Don't delete** `./output/` - your training checkpoints

**Can delete if needed:**
- ✅ Old containers: `kohya-ss-gui`, `tensorboard`, `hunyuanimage-2.1` (if unused)
- ✅ Dangling images: `<none>` tags (use `docker image prune`)
- ✅ Old preprocessing images if you rebuild

### Reclaim Space

```bash
# Remove all stopped containers
docker container prune

# Remove dangling images (careful!)
docker image prune

# Remove unused build cache
docker builder prune
```

## Model Cache Details

Your `~/.cache/huggingface/` (42GB) contains:

- **tencent/Hunyuan3D-2.1**: Shape generation models (~6-7GB)
  - VAE encoder/decoder
  - DiT denoiser
  - Config files

- **facebook/dinov2-large**: Image encoder (~1GB)

- **black-forest-labs/FLUX**: Text-to-image models (if used)

All services mount this cache at `/root/.cache/huggingface` inside containers, so:
- Downloads happen once
- Shared across preprocessing, fine-tuning, and gradio
- Persists on host even when containers are removed

## Disk Space Requirements

- **Image**: 33.4GB (already have)
- **Models**: 42GB (already cached on host)
- **Working space**: 10-20GB for preprocessing/training outputs
- **Total needed**: ~85-95GB

## First Run

When you run `make gradio` or `make finetune` for the first time:

1. **Image check**: Verifies `hunyuan3d21:latest` exists
2. **Cache mount**: Mounts `~/.cache/huggingface/` (42GB models already there!)
3. **Fast start**: No downloads needed since models are cached
4. **Ready**: Web UI at http://localhost:7860 or training shell

## Troubleshooting

### "Image not found"
The image exists but docker might not find it:
```bash
docker images | grep hunyuan3d21
# Should show: hunyuan3d21   latest   c4cb8ebade0a   3 months ago   33.4GB
```

### "Out of space"
Check disk usage:
```bash
df -h
docker system df
```

Remove unused containers/images:
```bash
make preprocessing-clean
make finetune-clean
make gradio-clean
docker system prune
```

### "Models downloading again"
If models re-download, the cache mount might not be working:
```bash
ls -lh ~/.cache/huggingface/hub/
# Should show: models--tencent--Hunyuan3D-2.1
```

## Port Conflicts

- **Gradio**: Uses port 7860 (http://localhost:7860)
- If port is in use: Change in `docker-compose.gradio.yaml`
  ```yaml
  ports:
    - "8080:7860"  # Access at http://localhost:8080
  ```

## Development Workflow

1. **Add new .obj models**:
   ```bash
   cp my_model.obj src/preprocessing/data/raw/
   make preprocessing-example
   ```

2. **Fine-tune on processed data**:
   ```bash
   make finetune
   # Inside container (choose one):

   # Full fine-tuning (8 GPUs):
   python main.py -c /workspace/finetuning/hunyuan3d-custom-finetuning.yaml ...

   # LoRA fine-tuning (1 GPU, 44GB+ VRAM):
   export CUDA_VISIBLE_DEVICES=0
   export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
   python main.py -c /workspace/finetuning/hunyuan3d-custom-lora.yaml ...
   ```

3. **Test with Gradio**:
   ```bash
   make gradio
   # Open http://localhost:7860
   ```

All use the same image and cache!
