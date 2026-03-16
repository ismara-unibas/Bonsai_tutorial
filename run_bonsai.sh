#!/usr/bin/env bash

set -euo pipefail

CONTAINER_NAME="bonsai"
IMAGE_NAME="pachkov/bonsai"
INPUT_DIR="$PWD"
BONSAI_ARGS=$*
NUM_THREADS=8

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n)
            if [[ $# -lt 2 ]]; then
                echo "Error: -n requires a positive integer value." >&2
                exit 1
            fi
            NUM_THREADS="$2"
            if ! [[ "$NUM_THREADS" =~ ^[0-9]+$ ]] || [[ "$NUM_THREADS" -lt 1 ]]; then
                echo "Error: -n requires a positive integer value." >&2
                exit 1
            fi
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# check if dir sanity_results exists in the current directory
if [[ ! -d "sanity_results" ]]; then
    echo "Error: sanity_results directory not found in the current directory: $PWD" >&2
    exit 1
fi

cleanup() {
	echo
	echo "Stopping and removing container '$CONTAINER_NAME'..."
	docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}

trap cleanup INT TERM

if docker ps --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
	echo "Container '$CONTAINER_NAME' is already running. Restarting it..."
	docker rm -f "$CONTAINER_NAME" >/dev/null
elif docker ps -a --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
	echo "Container '$CONTAINER_NAME' exists but is not running. Removing it..."
	docker rm "$CONTAINER_NAME" >/dev/null
fi

echo "Starting container '$CONTAINER_NAME' from image '$IMAGE_NAME'..."
docker run -d \
	--name "$CONTAINER_NAME" \
	-v "$INPUT_DIR":/mnt \
	"$IMAGE_NAME" >/dev/null

echo "Container is running."
echo "Mounted: $INPUT_DIR -> /mnt"
# start sanity in the container
echo "Starting bonsai in the container..."
# config

# CS
if [ -f "cellstates_results/optimized_clusters.txt" ]; then
	docker exec \
	    -w /mnt \
	    -t bonsai \
	    bash -c "mkdir -p bonsai_results/premerge_cs && python /bonsai/bonsai/create_config_file.py --new_yaml_path /mnt/bonsai_results/bonsai_config.yaml --dataset 'bonsai_docker' --data_folder /mnt/sanity_results --results_folder /mnt/bonsai_results --nnn_n_randomtrees 4 --nnn_n_randommoves 100 --tmp_folder /mnt/bonsai_results/premerge_cs --input_is_sanity_output True --pickup_intermediate True"

    docker exec \
        -w /mnt \
        -t bonsai \
        bash -c "python /bonsai/optional_preprocessing/create_cellstates_premerged_tree.py --config_filepath /mnt/bonsai_results/bonsai_config.yaml --verbose True --premerged_folder /mnt/bonsai_results/premerge_cs --cellstates_file /mnt/cellstates_results/optimized_clusters.txt"
else
    echo "Skipping Cellstates premerged tree step: cellstates_results/optimized_clusters.txt not found."

	docker exec \
	    -w /mnt \
	    -t bonsai \
	    bash -c "mkdir -p bonsai_results/premerge_cs && python /bonsai/bonsai/create_config_file.py --new_yaml_path /mnt/bonsai_results/bonsai_config.yaml --dataset 'bonsai_docker' --data_folder /mnt/sanity_results --results_folder /mnt/bonsai_results --nnn_n_randomtrees 4 --nnn_n_randommoves 100 --input_is_sanity_output True --pickup_intermediate True"
fi

# run bonsai_main with mpi
docker exec \
    -w /mnt \
    -t bonsai \
    bash -c "mpiexec --allow-run-as-root -n $NUM_THREADS python -m mpi4py /bonsai/bonsai/bonsai_main.py \
        --config_filepath /mnt/bonsai_results/bonsai_config.yaml"

# run bonsai_scout_preprocessing
docker exec \
    -w /mnt \
    -t bonsai \
    bash -c "mkdir -p /mnt/annotation && rm -rf /mnt/bonsai_results/bonsai_vis* && python /bonsai/bonsai_scout/bonsai_scout_preprocess.py --results_folder /mnt/bonsai_results --annotation_path /mnt/annotation --take_all_genes False"

echo "Bonsai run finished."

echo
echo "Stopping and removing container '$CONTAINER_NAME'..."
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
