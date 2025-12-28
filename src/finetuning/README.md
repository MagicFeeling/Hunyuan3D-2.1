# Fine-tuning Hunyuan3D-2.1

This directory contains configuration and resources for fine-tuning the Hunyuan3D-2.1 model on custom preprocessed data.

## Two Fine-tuning Approaches

### Full Fine-tuning (`hunyuan3d-custom-finetuning.yaml`)
- **Hardware**: Requires 8 GPUs with ~98GB total VRAM
- **Method**: Trains all 3.7B parameters
- **Best for**: Maximum performance, multi-GPU setups
- **Memory**: ~12GB per GPU with batch_size=4

### LoRA Fine-tuning (`hunyuan3d-custom-lora.yaml`)
- **Hardware**: Single GPU with 44GB+ VRAM (e.g., NVIDIA L40S, A100)
- **Method**: Trains only ~1-2% of parameters using LoRA adapters
- **Best for**: Single GPU, limited VRAM, faster iteration
- **Memory**: ~40-44GB with batch_size=1

**Choose based on your hardware:**
- **8+ GPUs (80GB+ total)**: Use full fine-tuning
- **Single GPU (44GB+)**: Use LoRA fine-tuning
- **Single GPU (<44GB)**: Not recommended (insufficient memory)

## Prerequisites

1. **Docker Image**: `hunyuan3d21:latest` (already built)
   - Contains PyTorch 2.5.1 + CUDA 12.4
   - All Hunyuan3D-2.1 dependencies
   - ~33.4GB image size

2. **Preprocessed Data**: Must be in `src/preprocessing/data/preprocessed/`
   - Run `make preprocessing-example` to preprocess your .obj files
   - Each model needs: `{uid}/geo_data/` and `{uid}/render_cond/`

3. **GPU**: Requires NVIDIA GPU(s) with CUDA support
   - **Full fine-tuning**: 8 GPUs with ~12GB VRAM each (98GB total)
   - **LoRA fine-tuning**: 1 GPU with 44GB+ VRAM

## Quick Start

### 1. Check Preprocessed Data

```bash
ls -la src/preprocessing/data/preprocessed/
```

You should see folders with SHA256 hashes (e.g., `d4f58793...`) containing:
- `geo_data/{uid}_surface.npz`
- `geo_data/{uid}_sdf.npz`
- `render_cond/000.png` through `023.png`

### 2. Start Fine-tuning Container

```bash
make finetune
```

This will:
- Check that the Docker image exists
- Check that preprocessed data exists
- Create `output/` directory for checkpoints
- Start an interactive container shell

### 3. Run Training Inside Container

Choose the appropriate command based on your hardware:

#### Option A: Full Fine-tuning (8 GPUs, 98GB total VRAM)

```bash
python main.py \
  -c /workspace/finetuning/hunyuan3d-custom-finetuning.yaml \
  --output_dir /workspace/output/custom-finetune \
  --num_gpus 8 \
  --num_nodes 1
```

#### Option B: LoRA Fine-tuning (1 GPU, 44GB+ VRAM)

```bash
export CUDA_VISIBLE_DEVICES=0
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

python main.py \
  -c /workspace/finetuning/hunyuan3d-custom-lora.yaml \
  --output_dir /workspace/output/custom-lora \
  --num_gpus 1 \
  --num_nodes 1
```

**Note**: LoRA trains only ~1-2% of model parameters, significantly reducing memory requirements while maintaining good performance.

## Configuration Files

### Full Fine-tuning Config (`hunyuan3d-custom-finetuning.yaml`)

- **Data**: `/workspace/data/preprocessed`
- **Batch size**: 4 (default for 8 GPUs)
- **Learning rate**: 1e-5 (standard fine-tuning rate)
- **Steps**: 50,000
- **Parameters**: All 3.7B parameters trained
- **Memory**: ~12GB per GPU with batch_size=4
- **Pretrained weights**: Auto-downloaded from HuggingFace `tencent/Hunyuan3D-2.1`

### LoRA Fine-tuning Config (`hunyuan3d-custom-lora.yaml`)

- **Data**: `/workspace/data/preprocessed`
- **Batch size**: 1 (for single 44GB GPU)
- **Learning rate**: 1e-4 (higher LR is standard for LoRA)
- **Steps**: 50,000
- **LoRA rank**: 32 (adjust 8-64 for capacity vs memory tradeoff)
- **Target modules**: Query and Value projections in attention layers
- **Parameters**: Only ~60M trainable (1.6% of model)
- **Memory**: ~40-44GB with batch_size=1

### Key Settings to Adjust

Edit the config file you're using:

```yaml
# Batch size (adjust based on VRAM)
dataset.params.batch_size: 1  # or 4 for multi-GPU

# Training duration
training.steps: 50000

# Checkpoint frequency
training.every_n_train_steps: 500

# Validation frequency (must be < every_n_train_steps)
training.val_check_interval: 100

# LoRA rank (only in LoRA config)
model.params.lora_config.rank: 32  # 8, 16, 32, or 64
```

## Output Structure

Training outputs are saved to `output/` (mounted from host):

### Full Fine-tuning Output

```
output/custom-finetune/
├── ckpt/                          # Full model checkpoints (large files)
│   ├── ckpt-00000500.ckpt
│   ├── ckpt-00001000.ckpt
│   └── ...
└── log/                           # TensorBoard logs
    └── tensorboard/
        └── events.out.tfevents.*
```

### LoRA Fine-tuning Output

```
output/custom-lora/
├── ckpt/                          # Full model checkpoints (for compatibility)
│   ├── ckpt-00000500.ckpt        # Contains base model + LoRA adapters
│   └── ...
├── lora_adapters/                 # LoRA adapter weights only (small files)
│   ├── step_500/
│   │   ├── adapter_config.json
│   │   └── adapter_model.bin    # Only ~60MB instead of 15GB
│   └── ...
└── log/                           # TensorBoard logs
    └── tensorboard/
        └── events.out.tfevents.*
```

**Note**: LoRA adapters are much smaller (~60MB) than full checkpoints (~15GB), making them easier to share and deploy.

## Monitoring Training

### View TensorBoard Logs

```bash
# On host machine
tensorboard --logdir output/custom-finetune/log/tensorboard --port 6006
```

Then open http://localhost:6006 in your browser.

### Check Training Progress

Inside the container, monitor GPU usage:

```bash
watch -n 1 nvidia-smi
```

## Advanced Usage

### Resume from Checkpoint

**Full fine-tuning:**
```bash
python main.py \
  -c /workspace/finetuning/hunyuan3d-custom-finetuning.yaml \
  --output_dir /workspace/output/custom-finetune \
  --ckpt_path /workspace/output/custom-finetune/ckpt/ckpt-00001000.ckpt \
  --num_gpus 8
```

**LoRA fine-tuning:**
```bash
export CUDA_VISIBLE_DEVICES=0
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

python main.py \
  -c /workspace/finetuning/hunyuan3d-custom-lora.yaml \
  --output_dir /workspace/output/custom-lora \
  --ckpt_path /workspace/output/custom-lora/ckpt/ckpt-00001000.ckpt \
  --num_gpus 1
```

### Adjust GPU Visibility

```bash
# Use only GPUs 0, 1, 2, 3
export CUDA_VISIBLE_DEVICES=0,1,2,3
python main.py ... --num_gpus 4
```

### Shell Access

For debugging or manual commands:

```bash
make finetune-shell
```

## Important Notes

1. **Small Dataset Warning**: With only 2 models, the model will overfit quickly
   - Consider preprocessing more .obj files before fine-tuning
   - Reduce `training.steps` to avoid excessive overfitting

2. **Model Download**: On first run, pretrained weights (~6GB) download from HuggingFace
   - Cached in `~/.cache/huggingface/` (mounted in container)
   - Subsequent runs reuse cached weights

3. **Memory Requirements**:
   - **Full fine-tuning**: 8 GPUs with 98GB total memory (tested on 8x H20)
   - **LoRA fine-tuning**: 1 GPU with 44GB+ VRAM (tested on L40S)
   - **Point cloud size**: Fixed at 81920 points (required by pretrained VAE, cannot be changed)

4. **Data Format**: The dataloader expects exact structure from preprocessing
   - Don't manually rename folders (they're used as UIDs)
   - Don't modify the .npz files

## Cleanup

Stop and remove the fine-tuning container:

```bash
make finetune-clean
```

This doesn't delete the `output/` directory, so your checkpoints are preserved.

## Troubleshooting

### "No preprocessed data found"
```bash
make preprocessing-example  # Process all .obj files in src/preprocessing/data/raw/
```

### "Docker image not found"
The `hunyuan3d21:latest` image should already exist. If not:
```bash
docker build -f docker/Dockerfile -t hunyuan3d21:latest .
```

### "Out of memory"
- **For full fine-tuning**: Switch to LoRA fine-tuning instead
- **For LoRA**: Set `batch_size: 1` and use `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True`
- **Do NOT reduce `pc_size`**: The pretrained VAE requires exactly 81920 points and cannot be changed
- **Reduce LoRA rank**: Try `rank: 16` or `rank: 8` in LoRA config

### "Model not converging"
- With only 2 models, expect to overfit
- Check TensorBoard for loss curves
- Consider adding more training data

### LoRA-specific: "PEFT/LoRA errors"
- Make sure `peft` library is installed: `pip install peft`
- Check that target_modules match the model architecture
- Verify LoRA rank is reasonable (8-64 typical range)

### LoRA-specific: "Still out of memory"
- Reduce LoRA rank: Try `rank: 16` or `rank: 8`
- Ensure `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True` is set
- Check that batch_size is 1
- Consider reducing image_size from 518 (requires retraining from scratch)

## LoRA Fine-tuning Tips

1. **Learning Rate**: LoRA typically uses higher learning rates (1e-4) than full fine-tuning (1e-5)

2. **Rank Selection**:
   - `rank: 8` - Fastest, least memory, may underfit
   - `rank: 16` - Good balance
   - `rank: 32` - Default, good for most cases
   - `rank: 64` - Maximum capacity, more memory

3. **Target Modules**: The config targets Q and V projections by default. You can add more for better capacity:
   ```yaml
   target_modules:
     - "blocks.*.attn1.to_q"
     - "blocks.*.attn1.to_k"    # Add K projection
     - "blocks.*.attn1.to_v"
     - "blocks.*.attn1.out_proj" # Add output projection
     - "blocks.*.attn2.to_q"
     - "blocks.*.attn2.to_k"    # Add K projection
     - "blocks.*.attn2.to_v"
     - "blocks.*.attn2.out_proj" # Add output projection
   ```

4. **Using LoRA Adapters**: After training, you can load just the LoRA adapters (~60MB) instead of full checkpoints:
   ```python
   from peft import PeftModel

   # Load base model
   base_model = load_pretrained_model("tencent/Hunyuan3D-2.1")

   # Load LoRA adapters on top
   model = PeftModel.from_pretrained(base_model, "output/custom-lora/lora_adapters/step_5000")
   ```

5. **Memory Optimization**: If still OOM with rank=32:
   - Try `rank: 16` (saves ~30% memory)
   - Try `rank: 8` (saves ~60% memory)
   - Monitor actual memory use: `watch -n 1 nvidia-smi`
