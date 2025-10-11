#!/bin/bash
# Preprocess a single 3D model file

set -e  # Exit on error

if [ "$#" -lt 2 ]; then
    echo "Usage: bash preprocess_single.sh <input_file> <output_name> [output_folder]"
    echo ""
    echo "Arguments:"
    echo "  input_file    : Path to input 3D model (.obj, .glb, etc.)"
    echo "  output_name   : Unique name for this object (e.g., chair_001)"
    echo "  output_folder : Output directory (default: /workspace/data/preprocessed)"
    echo ""
    echo "Example:"
    echo "  bash preprocess_single.sh /workspace/data/raw/chair.obj chair_001"
    exit 1
fi

INPUT_FILE=$1
OUTPUT_NAME=$2
OUTPUT_FOLDER=${3:-/workspace/data/preprocessed}

# Set environment variables
export OPENCV_IO_ENABLE_OPENEXR=1
export BLENDER_PATH=${BLENDER_PATH:-/opt/blender/blender}

# Verify Blender exists
if [ ! -f "$BLENDER_PATH" ]; then
    echo "Error: Blender not found at $BLENDER_PATH"
    echo "Please set BLENDER_PATH environment variable"
    exit 1
fi

# Verify input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_FOLDER"

echo "============================================"
echo "Hunyuan3D-2.1 Data Preprocessing"
echo "============================================"
echo "Input file:    $INPUT_FILE"
echo "Output name:   $OUTPUT_NAME"
echo "Output folder: $OUTPUT_FOLDER"
echo "Blender path:  $BLENDER_PATH"
echo "============================================"
echo ""

# Step 1: Render multi-view images
RENDER_COMPLETE="$OUTPUT_FOLDER/$OUTPUT_NAME/render_cond/mesh.ply"
if [ -f "$RENDER_COMPLETE" ]; then
    echo "[1/2] Rendering already complete (found mesh.ply), skipping..."
    echo "✓ Using existing renders: $OUTPUT_FOLDER/$OUTPUT_NAME/render_cond/"
else
    echo "[1/2] Rendering multi-view images with Blender..."
    echo "This will take 2-5 minutes per model..."

    $BLENDER_PATH -b -P render/render.py -- \
        --object "$INPUT_FILE" \
        --output_folder "$OUTPUT_FOLDER/$OUTPUT_NAME/render_cond" \
        --geo_mode \
        --resolution 512

    if [ $? -ne 0 ]; then
        echo "Error: Blender rendering failed!"
        exit 1
    fi

    echo "✓ Rendering complete: $OUTPUT_FOLDER/$OUTPUT_NAME/render_cond/"
fi
echo ""

# Step 2: Generate watertight mesh and geometric data
SDF_COMPLETE="$OUTPUT_FOLDER/$OUTPUT_NAME/geo_data/${OUTPUT_NAME}_sdf.npz"
if [ -f "$SDF_COMPLETE" ]; then
    echo "[2/2] Geometric data already complete, skipping..."
    echo "✓ Using existing data: $OUTPUT_FOLDER/$OUTPUT_NAME/geo_data/"
else
    echo "[2/2] Generating geometric data (watertight mesh, point clouds, SDF)..."
    echo "This will take 1-3 minutes per model..."

    python3 watertight/watertight_and_sample.py \
        --input_obj "$OUTPUT_FOLDER/$OUTPUT_NAME/render_cond/mesh.ply" \
        --output_prefix "$OUTPUT_FOLDER/$OUTPUT_NAME/geo_data/$OUTPUT_NAME"

    if [ $? -ne 0 ]; then
        echo "Error: Geometric data generation failed!"
        exit 1
    fi

    echo "✓ Geometric data complete: $OUTPUT_FOLDER/$OUTPUT_NAME/geo_data/"
fi
echo ""

# Verify output
echo "============================================"
echo "Preprocessing complete for: $OUTPUT_NAME"
echo "============================================"
echo "Output structure:"
echo "$OUTPUT_FOLDER/$OUTPUT_NAME/"
echo "├── render_cond/"
echo "│   ├── 000.png - 023.png (24 views)"
echo "│   ├── mesh.ply"
echo "│   └── transforms.json"
echo "└── geo_data/"
echo "    ├── ${OUTPUT_NAME}_surface.npz"
echo "    └── ${OUTPUT_NAME}_sdf.npz"
echo "============================================"
echo ""

# Check file sizes
RENDER_COUNT=$(find "$OUTPUT_FOLDER/$OUTPUT_NAME/render_cond" -name "*.png" | wc -l)
SURFACE_FILE="$OUTPUT_FOLDER/$OUTPUT_NAME/geo_data/${OUTPUT_NAME}_surface.npz"
SDF_FILE="$OUTPUT_FOLDER/$OUTPUT_NAME/geo_data/${OUTPUT_NAME}_sdf.npz"

echo "Verification:"
if [ "$RENDER_COUNT" -eq 24 ]; then
    echo "✓ 24 rendered views generated"
else
    echo "⚠ Warning: Expected 24 views, found $RENDER_COUNT"
fi

if [ -f "$SURFACE_FILE" ]; then
    SIZE=$(du -h "$SURFACE_FILE" | cut -f1)
    echo "✓ Surface data: $SIZE"
else
    echo "✗ Surface data missing"
fi

if [ -f "$SDF_FILE" ]; then
    SIZE=$(du -h "$SDF_FILE" | cut -f1)
    echo "✓ SDF data: $SIZE"
else
    echo "✗ SDF data missing"
fi

echo ""
echo "Done! ✨"
