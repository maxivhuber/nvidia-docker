#!/bin/bash

# Set flags for script behavior: 
# -e stops on first error, -u treats unset variables as an error, -o pipefail makes pipelines fail on the first command which fails
set -euo pipefail

# Use newline and tab as field separators for input and output
IFS=$'\n\t'

# Extract PROJECT_NAME from the first occurrence in the .env file
PROJECT_NAME=$(grep -m 1 '^PROJECT_NAME=' .env | cut -d '=' -f2)

# Ensure exactly three arguments are provided (source folder, target folder, action)
if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <source_folder> <target_folder> <action>"
    exit 1
fi

# Assign script arguments to variables for better readability
source_directory="$1"
target_directory="$2"
action="$3"
config_file="${source_directory}/sync/config.json"

# Check if provided action is either 'start' or 'stop'
if [[ "$action" != "start" ]] && [[ "$action" != "stop" ]]; then
    echo "Invalid action: $action. Use 'start' or 'stop'."
    exit 1
fi

# Counter to track the number of peers processed
counter=0

# Read each peer entry from the JSON config and execute actions
jq -r '.peers | to_entries[] | "\(.key) \(.value.hostname) \(.value.username) \(.value.ssh_key)"' "$config_file" | while IFS=' ' read -r peer_name peer_host peer_user peer_ssh_key; do
  # Increment peer counter
  counter=$((counter + 1))
  
  # Verify if the peer host is reachable and the SSH key file exists
  if ping -c 1 "$peer_host" &> /dev/null && [[ -e "$peer_ssh_key" ]]; then
    # Log the details of the current peer being processed
    echo "Peer: $peer_name, Host: $peer_host, User: $peer_user, SSH Key: $peer_ssh_key"

    if [[ "$action" == "start" ]]; then
      # Synchronize the source directory to the target directory on the peer host using rsync
      rsync --mkpath -acqz --delete -e "ssh -i $peer_ssh_key" "$source_directory"/ "${peer_user}@${peer_host}:~/${target_directory}" --exclude='/.git'

      # Execute commands on the remote host to start the container
      ssh -i "$peer_ssh_key" -T "${peer_user}@${peer_host}" PROJECT_NAME="$PROJECT_NAME" COUNTER="$counter" TARGET_DIR="$target_directory" bash << 'EOF' > /dev/null 2>&1
      cd ~/$TARGET_DIR
      sed -i "s/^NODE_RANK=.*/NODE_RANK=$COUNTER/" .env
      podman stop $PROJECT_NAME-$COUNTER || true
      podman build --build-arg-file=./argfile.conf --tag ml-lab:latest -f ./Dockerfile
      podman images -f dangling=true -q | xargs --no-run-if-empty podman rmi
      podman run -d --rm --name $PROJECT_NAME-$COUNTER \
        --device=nvidia.com/gpu=all \
        --security-opt=label=disable \
        --net=host \
        --env-file=.env \
        -v ./${PROJECT_NAME}:/workspace/${PROJECT_NAME} \
        -v ./data:/workspace/data \
        ml-lab:latest
EOF

    elif [[ "$action" == "stop" ]]; then
      # Execute commands on the remote host to stop the container
      ssh -i "$peer_ssh_key" -T "${peer_user}@${peer_host}" PROJECT_NAME="$PROJECT_NAME" COUNTER="$counter" TARGET_DIR="$target_directory" bash << 'EOF' > /dev/null 2>&1
      cd ~/$TARGET_DIR
      podman stop $PROJECT_NAME-$COUNTER || true
EOF
    fi
  else
    # Log an error message if the peer host is unreachable or the SSH key file is missing
    echo "$peer_host is unreachable or $peer_ssh_key does not exist"
  fi
done

echo "Success"
