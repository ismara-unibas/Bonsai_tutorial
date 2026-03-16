#!/usr/bin/env bash

set -euo pipefail

CONTAINER_NAME="bonsai"
IMAGE_NAME="pachkov/bonsai"

INPUT_DIR="${1:-$PWD}"
PORT="${2:-9000}"

if [[ ! -d "$INPUT_DIR" ]]; then
	echo "Error: input-dir does not exist: $INPUT_DIR" >&2
	exit 1
fi

if [[ ! "$PORT" =~ ^[0-9]+$ ]]; then
	echo "Error: port must be an integer, got: $PORT" >&2
	exit 1
fi

cleanup() {
	echo
	echo "Stopping and removing container '$CONTAINER_NAME'..."
	docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}

trap cleanup INT TERM

# check if dir bonsai_results exists in the current directory
if [[ ! -d "bonsai_results" ]]; then
    echo "Error: bonsai_results directory not found in the current directory: $PWD" >&2
    exit 1
fi

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
	-p "$PORT":"$PORT" \
	"$IMAGE_NAME"
# start bonsai_scout in the container
echo "Starting bonsai_scout in the container..."
docker exec \
    -w /mnt \
    -d "$CONTAINER_NAME" \
    python3 /bonsai/bonsai_scout/run_bonsai_scout_app.py \
    --results_folder /mnt/bonsai_results \
    --settings_filename /mnt/bonsai_results/bonsai_vis_settings.json \
    --port 9000

echo "Container is running."
echo "Mounted: $INPUT_DIR -> /mnt"
echo "Port mapping: $PORT:$PORT"
echo "Access the app at: http://localhost:$PORT"
echo "Press CTRL-C to stop and remove the container."

while true; do
	if ! docker ps --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
		echo "Container '$CONTAINER_NAME' is no longer running. Exiting."
		cleanup
		exit 1
	fi
	sleep 1
done
