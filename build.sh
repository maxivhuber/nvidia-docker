#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

PROJECT_NAME=$(grep -m 1 '^PROJECT_NAME=' .env | cut -d '=' -f2)

podman stop "$PROJECT_NAME"-0 > /dev/null 2>&1 || true && \
podman build --format docker --build-arg-file=./argfile.conf --tag ml-lab:latest -f ./Dockerfile > /dev/null 2>&1 && \
podman images -f dangling=true -q | xargs --no-run-if-empty podman rmi > /dev/null 2>&1  && \
podman run --init --rm --name "$PROJECT_NAME"-0 \
  --device=nvidia.com/gpu=all \
  --security-opt=label=disable \
  --ipc=host \
  --net=host \
  --env-file=.env \
  -v ./"${PROJECT_NAME}":/workspace/"${PROJECT_NAME}" \
  -v ./data:/workspace/data \
  -d ml-lab:latest > /dev/null 2>&1

echo "Success"