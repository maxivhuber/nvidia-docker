## Deep Learning Container Setup and Usage Guide

This guide provides instructions for setting up and using Podman containers for running deep learning applications with PyTorch and NVIDIA GPUs.

### Useful Resources

- **Containers For Deep Learning**: [NVIDIA User Guide](https://docs.nvidia.com/deeplearning/frameworks/user-guide/index.html)
- **Podman and the NVIDIA Container Toolkit**: [Installing Podman](https://docs.nvidia.com/ai-enterprise/deployment-guide-rhel-with-kvm/0.1.0/podman.html)
- **Running PyTorch in Docker Containers with NVIDIA GPUs**: [NVIDIA PyTorch Notes](https://docs.nvidia.com/deeplearning/frameworks/pytorch-release-notes/running.html)
- **Run on an On-Prem Cluster**: [Pytorch Cluster Setup](https://lightning.ai/docs/pytorch/stable/clouds/cluster_intermediate_1.html)

### Setup Instructions

1. **Project Folder**:
    - Rename your project folder to `my_project`.
2. **Environment Variables**:
    - Open the `.env` file in the root directory.
    - Set your project name as an environment variable (e.g., `PROJECT_NAME=my_project`).
    - Set the Jupyter Lab port (e.g., `JUPYTER_PORT=8000`).
    - Configure cluster settings (`MASTER_PORT`, `MASTER_ADDR`, `WORLD_SIZE`, `NODE_RANK`).
    - Set NCCL environment variables.
3. **Requirements File**:
    - Add any necessary pip dependencies to the `requirements.txt` file.

### Usage

- **Starting the Container**:
    - Run `bash build.sh` to build and start the container using Podman.
- **Accessing Jupyter Lab**:
    - Connect to Jupyter Lab through `http://<ip-address>:<JUPYTER_PORT>/?token=<token>`

### Synchronization between Nodes

- **Sync Script**:
    - The `sync` folder contains a script for synchronizing your working directory with remote nodes, essential for training on a cluster.
    - The script supports `start` and `stop` actions for synchronizing and managing containers on remote nodes.
    - **Starting Synchronization and Containers**:
        - Usage: `bash sync/sync.sh <local_absolute_path> <remote_relative_path> start`.
        - For example: `bash sync/sync.sh ~/my_project/ .sync/my_project start`.
    - **Stopping Containers**:
        - Usage: `bash sync/sync.sh <local_absolute_path> <remote_relative_path> stop`.
        - For example: `bash sync/sync.sh ~/my_project/ .sync/my_project stop`.
- **Configuring Sync Settings**:
    - Update the `sync/config.json` file to include your own nodes, their respective SSH access details, and keys. Ensure to replace `node1`, `node2`, etc., with your actual node details.
