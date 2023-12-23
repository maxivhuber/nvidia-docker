#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

PROJECT_NAME=$(grep -m 1 '^PROJECT_NAME=' .env | cut -d '=' -f2)

podman stop "$PROJECT_NAME"-0 > /dev/null 2>&1 || true && \
podman build --build-arg-file=./argfile.conf --tag ml-lab:latest -f ./Dockerfile > /dev/null 2>&1 && \
podman images -f dangling=true -q | xargs --no-run-if-empty podman rmi > /dev/null 2>&1 && \
podman run -d --rm --name "$PROJECT_NAME"-0 --ipc=host \
  --device=nvidia.com/gpu=all \
  --security-opt=label=disable \
  --net=host \
  --env-file=.env \
  -v ./"${PROJECT_NAME}":/workspace/"${PROJECT_NAME}" \
  -v ./data:/workspace/data \
  ml-lab:latest > /dev/null 2>&1

echo "Success"