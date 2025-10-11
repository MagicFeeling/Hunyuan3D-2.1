# Hunyuan3D-2.1 Data Preprocessing Guide

This guide explains how to preprocess your 3D models for fine-tuning the Hunyuan3D-2.1 model.

## 📋 Overview

The preprocessing pipeline converts your raw 3D models (.obj, .glb, etc.) into the format required for training:

```
Input: your_model.obj
    ↓
[Blender Rendering] → 24 multi-view images + camera transforms
    ↓
[Watertight Processing] → Surface point clouds + SDF samples
    ↓
Output: Preprocessed dataset ready for training
```

## 🚀 Quick Start

### 1. Setup Directories

```bash
# Create data directories
mkdir -p docker/data/raw
mkdir -p docker/data/preprocessed

# Place your .obj or .glb files in the raw directory
cp /path/to/your/models/*.obj docker/data/raw/
```

### 2. Build Preprocessing Environment

```bash
make preprocessing-build
```

This builds a Docker image with:
- Blender 4.1
- Python 3.11 with OpenEXR, OpenCV
- Mesh processing libraries (trimesh, pymeshlab)

### 3. Run Preprocessing

#### Option A: Interactive Mode (Recommended for first time)

```bash
make preprocessing
```

This opens a shell inside the container. Then run:

```bash
# Process a single model
cd /workspace/tools
bash scripts/preprocess_single.sh /workspace/data/raw/Hurra_v1.obj Hurra_v1

# Or process all models in a directory
bash scripts/preprocess_batch.sh /workspace/data/raw /workspace/data/preprocessed
```

#### Option B: Batch Processing (Automated)

```bash
make preprocessing-example
```

This automatically processes all .obj/.glb files in `docker/data/raw/`.

## 📁 Output Structure

After preprocessing, your data will be organized as:

```
docker/data/preprocessed/
├── object_001/
│   ├── render_cond/              # Rendered condition images
│   │   ├── 000.png               # View from angle 0
│   │   ├── 001.png               # View from angle 1
│   │   ├── ...
│   │   ├── 023.png               # View from angle 23 (24 total views)
│   │   ├── mesh.ply              # Converted PLY mesh
│   │   └── transforms.json       # Camera parameters for each view
│   └── geo_data/                 # Geometric data
│       ├── object_001_surface.npz   # Surface point cloud samples
│       └── object_001_sdf.npz       # Signed Distance Field samples
├── object_002/
│   ├── render_cond/
│   └── geo_data/
└── ...
```

## 🔧 Manual Processing (Advanced)

If you want to process files manually:

### Step 1: Enter Container

```bash
make preprocessing-shell
```

### Step 2: Render Multi-View Images

```bash
cd /workspace/tools

export BLENDER_PATH=/opt/blender/blender
export INPUT_FILE=/workspace/data/raw/your_model.obj
export OUTPUT_NAME=your_model_name
export OUTPUT_FOLDER=/workspace/data/preprocessed

# Render 24 views with camera data
$BLENDER_PATH -b -P render/render.py -- \
    --object ${INPUT_FILE} \
    --output_folder ${OUTPUT_FOLDER}/${OUTPUT_NAME}/render_cond \
    --geo_mode \
    --resolution 512
```

### Step 3: Generate Geometric Data

```bash
# Process mesh to create watertight version + point clouds + SDF
python3 watertight/watertight_and_sample.py \
    --input_obj ${OUTPUT_FOLDER}/${OUTPUT_NAME}/render_cond/mesh.ply \
    --output_prefix ${OUTPUT_FOLDER}/${OUTPUT_NAME}/geo_data/${OUTPUT_NAME}
```

## 📊 Data Format Details

### 1. Rendered Images (render_cond/)
- **24 PNG images** (000.png - 023.png): Multi-view renders from different camera angles
- **mesh.ply**: Your 3D model converted to PLY format
- **transforms.json**: Camera parameters (position, rotation, FOV) for each view

### 2. Geometric Data (geo_data/)

#### Surface Samples (`*_surface.npz`)
Contains point cloud samples from the mesh surface:
- `random_surface`: (N, 6) array - uniform samples [x, y, z, nx, ny, nz]
- `sharp_surface`: (M, 6) array - samples near sharp edges [x, y, z, nx, ny, nz]

#### SDF Samples (`*_sdf.npz`)
Contains signed distance field samples:
- `vol_points`: (P, 3) - random 3D points in space
- `vol_label`: (P,) - signed distance to surface (negative=inside, positive=outside)
- `random_near_points`: (Q, 3) - points near the surface
- `random_near_label`: (Q,) - their signed distances
- `sharp_near_points`: (R, 3) - points near sharp edges
- `sharp_near_label`: (R,) - their signed distances

## ⚙️ Configuration

### Render Settings

Edit `render/render.py` or pass command-line arguments:

- `--resolution`: Image resolution (default: 512)
- `--num_views`: Number of views to render (default: 24)
- `--geo_mode`: Enable geometry mode for shape training

### Sampling Settings

Edit `watertight/watertight_and_sample.py`:

- Number of surface samples
- Number of volume samples
- SDF sampling distance thresholds

## 🐛 Troubleshooting

### Issue: "Blender not found"
```bash
# Verify Blender is installed in container
docker compose -f docker/docker-compose.preprocessing.yaml run --rm preprocessing which blender
```

### Issue: "No such file or directory"
- Ensure your input files are in `docker/data/raw/`
- Check file permissions
- Verify volume mounts in `docker-compose.preprocessing.yaml`

### Issue: "OpenEXR import error"
```bash
# Verify OpenEXR is installed in Blender's Python
docker compose -f docker/docker-compose.preprocessing.yaml run --rm preprocessing \
    /opt/blender/4.1/python/bin/python3.11 -c "import OpenEXR; print('OK')"
```

### Issue: "Mesh processing failed"
- Ensure input mesh is manifold (watertight)
- Try cleaning mesh in Blender/MeshLab first
- Check mesh has valid normals and faces

### Issue: "Calling operator bpy.ops.import_scene.obj error, could not be found"
**Fixed**: Blender 4.x uses new import operators (`bpy.ops.wm.obj_import` instead of `bpy.ops.import_scene.obj`). The render script now automatically detects and uses the correct API.

### Issue: "Module 'igl' has no attribute 'write_obj'"
**Fixed**: Newer libigl uses `writeOBJ` instead of `write_obj`. The code now handles both versions.

### Issue: "ValueError: too many values to unpack"
**Fixed**: Newer libigl API returns 4 values from `signed_distance()` instead of 3. The code now handles different API versions.

### Issue: "signed_distance(): incompatible function arguments"
**Fixed**:
- Removed unsupported `return_normals` parameter
- Ensured proper dtype conversion (float64, int64)
- Trimesh arrays are now explicitly converted to numpy arrays

## 📝 Tips for Best Results

1. **Mesh Quality**: Clean meshes process better
   - Remove duplicate vertices
   - Fix non-manifold edges
   - Ensure consistent face normals

2. **File Formats**: Supported formats
   - .obj (recommended)
   - .glb/.gltf
   - .ply
   - .stl

3. **Batch Processing**: For large datasets
   - Process in batches of 50-100 models
   - Monitor disk space (each model ~10-50MB preprocessed)
   - Use SSD for faster I/O

4. **Dataset Organization**: Keep raw data separate
   ```
   docker/data/
   ├── raw/              # Original models (keep as backup)
   ├── preprocessed/     # Processed training data
   └── validation/       # Validation set (process separately)
   ```

5. **Resuming Failed Jobs**: The preprocessing scripts automatically skip completed steps
   - If rendering completes but geometric processing fails, rerun the script
   - Step 1 is skipped if `mesh.ply` exists
   - Step 2 is skipped if `_sdf.npz` exists
   - No need to wait for 10-minute rendering again!

## 🔗 Next Steps

After preprocessing:

1. **Verify Output**
   ```bash
   # Check a sample output
   ls -lh docker/data/preprocessed/your_model/render_cond/
   ls -lh docker/data/preprocessed/your_model/geo_data/
   ```

2. **Update Training Config**
   Edit `hy3dshape/configs/hunyuandit-finetuning-flowmatching-dinol518-bf16-lr1e5-4096.yaml`:
   ```yaml
   dataset:
     params:
       train_data_list: /path/to/docker/data/preprocessed
       val_data_list: /path/to/docker/data/preprocessed_val
   ```

3. **Start Training**
   ```bash
   cd hy3dshape
   bash train_demo.sh
   ```

## 🔧 Technical Notes & Fixes Applied

### API Compatibility Fixes

This preprocessing environment includes several fixes for compatibility with Blender 4.x and modern Python libraries:

#### 1. **Blender 4.x Import Operators**
**Location**: `hy3dshape/tools/render/render.py`

**Issue**: Blender 4.x changed import operators from `bpy.ops.import_scene.obj` to `bpy.ops.wm.obj_import`

**Fix**: Added version detection to use correct operators:
```python
def get_import_function(ext):
    if ext == "obj":
        if hasattr(bpy.ops.wm, 'obj_import'):
            return bpy.ops.wm.obj_import  # Blender 4.x
        else:
            return bpy.ops.import_scene.obj  # Blender 3.x
```

#### 2. **libigl API Changes**
**Location**: `hy3dshape/tools/watertight/watertight_and_sample.py`

**Issues & Fixes**:

a) **signed_distance() return values**:
   - Old API: returns 3 values `(sdf, face_indices, closest_points)`
   - New API: returns 4 values `(sdf, face_indices, closest_points, normals)`
   - **Fix**: Extract only first element: `vol_sdf = result[0]`

b) **Removed unsupported parameters**:
   - Removed: `return_normals=False` (not supported in new API)
   - Added explicit dtype conversion: `astype(np.float64)` for points, `np.int64` for faces

c) **Trimesh array compatibility**:
   - Converted trimesh.caching.TrackedArray to numpy arrays:
   ```python
   vertices = np.asarray(mesh.vertices, dtype=np.float64)
   faces = np.asarray(mesh.faces, dtype=np.int64)
   ```

d) **marching_cubes() return handling**:
   - Handles variable return values from different API versions
   ```python
   result = igl.marching_cubes(...)
   if isinstance(result, tuple) and len(result) == 2:
       mc_verts, mc_faces = result
   else:
       mc_verts = result[0]
   ```

e) **write_obj() vs writeOBJ()**:
   - New API uses camelCase: `writeOBJ` instead of `write_obj`
   ```python
   try:
       igl.write_obj(filename, verts, faces)
   except AttributeError:
       igl.writeOBJ(filename, verts, faces)
   ```

#### 3. **Smart Resume Capability**
**Location**: `hy3dshape/tools/scripts/preprocess_single.sh`

**Feature**: Automatically skip completed preprocessing steps
- Checks for `mesh.ply` before running Step 1 (rendering)
- Checks for `*_sdf.npz` before running Step 2 (geometric processing)
- Saves ~10 minutes when resuming failed jobs

#### 4. **Docker Compose V2 Support**
**Location**: `Makefile`

**Feature**: Auto-detects Docker Compose version
```makefile
DOCKER_COMPOSE := $(shell command -v docker-compose 2> /dev/null)
ifndef DOCKER_COMPOSE
    DOCKER_COMPOSE := docker compose
endif
```
- Works with both `docker-compose` (V1) and `docker compose` (V2)

### Library Versions

The preprocessing container uses:
- **Blender**: 4.1.0
- **Python**: 3.10 (system) + 3.11 (Blender)
- **libigl**: Latest version (via pip)
- **trimesh**: Latest version
- **pymeshlab**: 2022.2.post3

### Known Limitations

1. **Blender Addons**: Some Blender addons must be enabled at runtime rather than during Docker build
2. **Memory Usage**: Watertight processing with high grid resolution (256³) can use significant RAM
3. **Processing Time**:
   - Rendering: 2-5 minutes per model (24 views)
   - Geometric processing: 1-3 minutes per model
   - Total: ~3-8 minutes per model

## 📚 Additional Resources

- [Main README](../README.md)
- [Tools README](../hy3dshape/tools/README.md)
- [Training Guide](TRAINING_GUIDE.md) (coming soon)

## 🤝 Support

For issues:
- GitHub Issues: https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1/issues
- Discord: https://discord.gg/dNBrdrGGMa

## 📋 Changelog

### Version 1.0 (2025-01-11)
- Initial preprocessing environment setup
- Added Blender 4.1 support with API compatibility layer
- Fixed libigl API compatibility issues
- Implemented smart resume capability for failed jobs
- Added Docker Compose V2 support
- Created automated preprocessing scripts
- Comprehensive documentation and troubleshooting guide
