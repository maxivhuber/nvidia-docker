#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

# Check if exactly two arguments are passed (source and target folders)
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <source_folder> <target_folder>"
    exit 1
fi

# Assign arguments to variables for clarity
source_directory="$1"
target_directory="$2"
config_file="${source_directory}/sync/config.json"

# Iterate over the peers defined in the JSON config file
jq -r '.peers | to_entries[] | "\(.key) \(.value.hostname) \(.value.username) \(.value.ssh_key)"' "$config_file" | while IFS=' ' read -r peer_name peer_host peer_user peer_ssh_key; do
  # Comment: Check if the host is reachable and the SSH key exists
  if ping -c 1 "$peer_host" &> /dev/null && [[ -e "$peer_ssh_key" ]]; then
    # Display the details of the current peer
    echo "Peer: $peer_name, Host: $peer_host, User: $peer_user, SSH Key: $peer_ssh_key"

    # Execute rsync command to synchronize files
    rsync --mkpath -acqz --delete -e "ssh -i $peer_ssh_key" "$source_directory" "${peer_user}@${peer_host}:~/${target_directory}" --exclude='/.git'

    # SSH into the remote host and run docker-compose up
    ssh -n -i "$peer_ssh_key" "${peer_user}@${peer_host}" "bash -l -c 'cd ~/${target_directory} && docker compose up -d --build --force-recreate'" > /dev/null 2>&1

  else
    echo "$peer_host is unreachable or $peer_ssh_key does not exist"
  fi
done
