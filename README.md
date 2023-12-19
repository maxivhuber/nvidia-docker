## Deep Learning Container Setup and Usage Guide

This guide provides instructions for setting up and using Docker containers for running deep learning applications with PyTorch and NVIDIA GPUs.

### Useful Resources

- **Containers For Deep Learning**: [NVIDIA User Guide](https://docs.nvidia.com/deeplearning/frameworks/user-guide/index.html)
- **Running PyTorch in Docker Containers with NVIDIA GPUs**: [NVIDIA PyTorch Notes](https://docs.nvidia.com/deeplearning/frameworks/pytorch-release-notes/running.html)

### Setup Instructions

1. **Project Folder**:
    - Rename your project folder `my_project`.
2. **Environment Variables**:
    - Open the `.env` file in the root directory.
    - Set your project name as an environment variable (e.g., `PROJECT_NAME=my_project`).
    - Choose a token for Jupyter Lab and set it in the `.env` file (e.g., `JUPYTER_TOKEN=your_token`).
3. **Requirements File**:
    - Add any necessary pip dependencies to the `requirements.txt` file.

### Usage

- **Starting the Container**:
    - Run `docker compose up -d --build` to build and start the container in detached mode.
- **Accessing Jupyter Lab**:
    - Connect to Jupyter Lab through `http://<ip-address>:<port>/?token=<token>`

### Synchronization between Nodes

- **Sync Script**:
    - The `sync` folder contains a script for synchronizing your working directory with remote nodes, essential for training on a cluster.
    - Execute the script using `bash sync/sync.sh <local_absolute_path> <remote_relative_path>`.
    - For example: `bash sync/sync.sh ~/my_project/ .sync/my_project`.
- **Configuring Sync Settings**:
    - Adapt the `sync/config.json` file to include your own nodes, their respective SSH access details, and keys. The structure of the file is as follows:
      ```json
      {
          "peers": {
              "node1": {
                  "hostname": "node1.example.com",
                  "username": "your_username",
                  "ssh_key": "/path/to/your/ssh_key"
              },
              "node2": {
                  "hostname": "node2.example.com",
                  "username": "your_username",
                  "ssh_key": "/path/to/your/ssh_key"
              }
          }
      }
      ```
    - Ensure to replace `node1`, `node2`, `your_username`, and the SSH key paths with your actual node details.
- **Automatic Docker Container Start**:
    - Upon successful synchronization, the Docker container will automatically start on the remote nodes using the provided script.

