#!/bin/bash
# Batch preprocess multiple 3D model files

set -e  # Exit on error

if [ "$#" -lt 2 ]; then
    echo "Usage: bash preprocess_batch.sh <input_dir> <output_dir> [file_extension]"
    echo ""
    echo "Arguments:"
    echo "  input_dir      : Directory containing 3D models"
    echo "  output_dir     : Output directory for preprocessed data"
    echo "  file_extension : File extension to process (default: obj)"
    echo ""
    echo "Example:"
    echo "  bash preprocess_batch.sh /workspace/data/raw /workspace/data/preprocessed obj"
    exit 1
fi

INPUT_DIR=$1
OUTPUT_DIR=$2
FILE_EXT=${3:-obj}

# Verify input directory exists
if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Input directory not found: $INPUT_DIR"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Count files
FILE_COUNT=$(find "$INPUT_DIR" -maxdepth 1 -name "*.${FILE_EXT}" -o -name "*.glb" | wc -l)

if [ "$FILE_COUNT" -eq 0 ]; then
    echo "Error: No .${FILE_EXT} or .glb files found in $INPUT_DIR"
    exit 1
fi

echo "============================================"
echo "Hunyuan3D-2.1 Batch Preprocessing"
echo "============================================"
echo "Input directory:  $INPUT_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "File extension:   $FILE_EXT"
echo "Files found:      $FILE_COUNT"
echo "============================================"
echo ""

# Set environment variables
export OPENCV_IO_ENABLE_OPENEXR=1
export BLENDER_PATH=${BLENDER_PATH:-/opt/blender/blender}

# Process each file
CURRENT=0
SUCCEEDED=0
FAILED=0
FAILED_FILES=()

for INPUT_FILE in "$INPUT_DIR"/*.${FILE_EXT} "$INPUT_DIR"/*.glb; do
    # Skip if glob didn't match any files
    [ -f "$INPUT_FILE" ] || continue

    CURRENT=$((CURRENT + 1))

    # Extract filename without extension
    BASENAME=$(basename "$INPUT_FILE")
    FILENAME="${BASENAME%.*}"

    # Generate unique output name (use hash to avoid filename issues)
    OUTPUT_NAME=$(echo -n "$FILENAME" | sha256sum | cut -c1-64)

    echo ""
    echo "============================================"
    echo "Processing [$CURRENT/$FILE_COUNT]: $BASENAME"
    echo "Output name: $OUTPUT_NAME"
    echo "============================================"

    # Check if already processed
    if [ -f "$OUTPUT_DIR/$OUTPUT_NAME/geo_data/${OUTPUT_NAME}_sdf.npz" ]; then
        echo "⊘ Skipping (already processed)"
        SUCCEEDED=$((SUCCEEDED + 1))
        continue
    fi

    # Run preprocessing
    if bash scripts/preprocess_single.sh "$INPUT_FILE" "$OUTPUT_NAME" "$OUTPUT_DIR"; then
        SUCCEEDED=$((SUCCEEDED + 1))
        echo "✓ Success: $BASENAME"
    else
        FAILED=$((FAILED + 1))
        FAILED_FILES+=("$BASENAME")
        echo "✗ Failed: $BASENAME"
        echo "Continuing with next file..."
    fi
done

# Summary
echo ""
echo "============================================"
echo "Batch Preprocessing Complete"
echo "============================================"
echo "Total files:  $FILE_COUNT"
echo "Succeeded:    $SUCCEEDED"
echo "Failed:       $FAILED"
echo "============================================"

if [ "$FAILED" -gt 0 ]; then
    echo ""
    echo "Failed files:"
    for FAILED_FILE in "${FAILED_FILES[@]}"; do
        echo "  - $FAILED_FILE"
    done
    echo ""
    echo "Check logs above for error details."
fi

echo ""
echo "Preprocessed data saved to: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "1. Verify output: ls -lh $OUTPUT_DIR"
echo "2. Update training config with: train_data_list: $OUTPUT_DIR"
echo "3. Start training!"
echo ""

exit 0
