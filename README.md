## Deep Learning Container Setup and Usage Guide

This guide provides instructions for setting up and using Docker containers for running deep learning applications with PyTorch and NVIDIA GPUs.

### Useful Resources

- **Containers For Deep Learning**: [NVIDIA User Guide](https://docs.nvidia.com/deeplearning/frameworks/user-guide/index.html)
- **Running PyTorch in Docker Containers with NVIDIA GPUs**: [NVIDIA PyTorch Notes](https://docs.nvidia.com/deeplearning/frameworks/pytorch-release-notes/running.html)

### Setup Instructions

1. **Project Folder**:
    - Rename your project folder `my-project`.
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
