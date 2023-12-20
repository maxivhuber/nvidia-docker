#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

PROJECT_NAME=$(grep -m 1 '^PROJECT_NAME=' .env | cut -d '=' -f2)

# Check if exactly three arguments are passed (source and target folders, and action)
if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <source_folder> <target_folder> <action>"
    exit 1
fi

# Assign arguments to variables for clarity
source_directory="$1"
target_directory="$2"
action="$3"
config_file="${source_directory}/sync/config.json"

# Validate the action argument
if [[ "$action" != "start" ]] && [[ "$action" != "stop" ]]; then
    echo "Invalid action: $action. Use 'start' or 'stop'."
    exit 1
fi

# Iterate over the peers defined in the JSON config file
counter=0
jq -r '.peers | to_entries[] | "\(.key) \(.value.hostname) \(.value.username) \(.value.ssh_key)"' "$config_file" | while IFS=' ' read -r peer_name peer_host peer_user peer_ssh_key; do
  counter=$((counter + 1))
  # Check if the host is reachable and the SSH key exists
  if ping -c 1 "$peer_host" &> /dev/null && [[ -e "$peer_ssh_key" ]]; then
    # Display the details of the current peer
    echo "Peer: $peer_name, Host: $peer_host, User: $peer_user, SSH Key: $peer_ssh_key"

    if [[ "$action" == "start" ]]; then
      # Execute rsync command to synchronize files
      rsync --mkpath -acqz --delete -e "ssh -i $peer_ssh_key" "$source_directory"/ "${peer_user}@${peer_host}:~/${target_directory}" --exclude='/.git'
      
      # SSH into the remote host and run build, clean and run container
      ssh -n -i "$peer_ssh_key" "${peer_user}@${peer_host}" "bash -l -c 'cd ~/${target_directory} && \
      sed -i 's/^NODE_RANK=.*/NODE_RANK=${counter}/' .env && \
      podman stop ml-lab-$counter || true && \
      podman build --build-arg-file=./argfile.conf --tag ml-lab:latest -f ./Dockerfile && \
      podman images -f dangling=true -q | xargs --no-run-if-empty podman rmi && \
      podman run -d --rm --name ${PROJECT_NAME}-$counter \
      --device=nvidia.com/gpu=all \
      --security-opt=label=disable \
      --net=host \
      --env-file=.env \
      -v ./\${PROJECT_NAME}:/workspace/\${PROJECT_NAME} \
      -v ./data:/workspace/data \
      ml-lab:latest'" > /dev/null 2>&1
      
    elif [[ "$action" == "stop" ]]; then
      # SSH into the remote host and stop docker-compose
      ssh -n -i "$peer_ssh_key" "${peer_user}@${peer_host}" "bash -l -c 'cd ~/${target_directory} && podman stop ${PROJECT_NAME}-$counter || true'" > /dev/null 2>&1
    fi
  else
    echo "$peer_host is unreachable or $peer_ssh_key does not exist"
  fi
done

echo "Success"