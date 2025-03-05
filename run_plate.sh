#!/bin/bash

TOTAL_START_TIME=$SECONDS

### PARAMETERS ###
BUCKET="s3://cellpainting-gallery/cpg0037-oasis/broad/images/2025_01_12_U2OS_Batch2/images/"
REPO_DIR="/home/jewald/repos/microscopy_computational_tools/"
DATA_DIR="/home/jewald/embeddings/"

# Ensure TARGET is provided
if [ -z "$1" ]; then
    echo "Error: No target plate specified."
    echo "Usage: $0 TARGET [download_imgs] [detect_cells] [get_embeddings]"
    exit 1
fi

TARGET="$1"
shift  # Shift arguments so that remaining args are processed normally

### STEP SELECTION ###
RUN_DOWNLOAD=false
RUN_DETECT_CELLS=false
RUN_GET_EMBEDDINGS=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        download_imgs) RUN_DOWNLOAD=true ;;
        detect_cells) RUN_DETECT_CELLS=true ;;
        get_embeddings) RUN_GET_EMBEDDINGS=true ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: $0 [download_imgs] [detect_cells] [get_embeddings]"
            exit 1
            ;;
    esac
done

# Function to format time in minutes and seconds
format_time() {
    local elapsed_time=$1
    printf "%02d min %02d sec\n" $((elapsed_time / 60)) $((elapsed_time % 60))
}

### STEP ONE: download_imgs
if [ "$RUN_DOWNLOAD" = true ]; then
    STEP_START_TIME=$SECONDS
    echo "Starting image download..."

    MATCHING_DIR=$(aws s3 ls "$BUCKET" | awk '{print $2}' | grep "$TARGET")
    if [ -z "$MATCHING_DIR" ]; then
        echo "Error: No directory found containing '$TARGET'"
        exit 1
    fi

    mkdir -p "$TARGET"
    FINAL_S3_PATH="${BUCKET}${MATCHING_DIR}Images/"
    DOWNLOAD_PATH="${DATA_DIR}images/${TARGET}/"

    # Download .tiff files matching -ch2 to -ch6 patterns into the new directory
    aws s3 cp --recursive "$FINAL_S3_PATH" "$DOWNLOAD_PATH" \
        --exclude "*" \
        --include "*-ch2*.tiff" \
        --include "*-ch3*.tiff" \
        --include "*-ch4*.tiff" \
        --include "*-ch5*.tiff" \
        --include "*-ch6*.tiff" > /dev/null 2>&1

    echo "Download complete: Files saved in $DOWNLOAD_PATH"

    STEP_END_TIME=$SECONDS
    STEP_DURATION=$((STEP_END_TIME - STEP_START_TIME))
    echo "Step 1 (download_imgs) runtime: $(format_time $STEP_DURATION)"
fi

### STEP TWO: detect_cells
if [ "$RUN_DETECT_CELLS" = true ]; then
    STEP_START_TIME=$SECONDS
    echo "Starting cell detection..."

    parallel -j 4 python3 ${REPO_DIR}cellpose/run_cellpose.py ${DATA_DIR}images/${TARGET}/ ${DATA_DIR}centers/ -ch5 4 ::: 0 1 2 3

    # Concatenate all embeddings
    echo -e "file\\ti\\tj" > ${DATA_DIR}centers/${TARGET}.tsv
    cat ${DATA_DIR}centers/cellpose_* >> ${DATA_DIR}centers/${TARGET}.tsv
    rm ${DATA_DIR}centers/cellpose_*.csv
    echo "Cellpose complete: Files saved in ${DATA_DIR}centers/${TARGET}.tsv"

    STEP_END_TIME=$SECONDS
    STEP_DURATION=$((STEP_END_TIME - STEP_START_TIME))
    echo "Step 2 (detect_cells) runtime: $(format_time $STEP_DURATION)"
fi

### STEP THREE: get_embeddings
if [ "$RUN_GET_EMBEDDINGS" = true ]; then
    STEP_START_TIME=$SECONDS
    echo "Starting embedding generation..."

    python3 ${REPO_DIR}embeddings/run_model.py dino4cells \
        ${DATA_DIR}weights/dino4cells/DINO_cell_painting_base_checkpoint.pth \
        ${DATA_DIR}images/${TARGET}/ \
        DNA,Mito,RNA,ER,AGP -ch5,-ch4,-ch6,-ch2,-ch3 \
        ${DATA_DIR}centers/${TARGET}.tsv \
        0 \
        ${DATA_DIR}embeddings/dino4cells/${TARGET}.h5

    echo "dino4cells complete: Files saved in ${DATA_DIR}embeddings/dino4cells/${TARGET}.h5"

    STEP_END_TIME=$SECONDS
    STEP_DURATION=$((STEP_END_TIME - STEP_START_TIME))
    echo "Step 3 (get_embeddings) runtime: $(format_time $STEP_DURATION)"
fi

### END TIMER FOR ENTIRE SCRIPT ###
TOTAL_END_TIME=$SECONDS
TOTAL_DURATION=$((TOTAL_END_TIME - TOTAL_START_TIME))
echo "Total script runtime: $(format_time $TOTAL_DURATION)"
