#!/bin/bash

# Set flags for script behavior: 
# -e stops on first error, -u treats unset variables as an error, -o pipefail makes pipelines fail on the first command which fails
set -euo pipefail

# Use newline and tab as field separators for input and output
IFS=$'\n\t'

# Extract PROJECT_NAME from the first occurrence in the .env file
PROJECT_NAME=$(grep -m 1 '^PROJECT_NAME=' .env | cut -d '=' -f2)

# Ensure that a minimum of three arguments are provided (source folder, target folder, action)
if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <source_folder> <target_folder> <action> <optional: bash get file extension
    file_path>"
    exit 1
fi

# Assign script arguments to variables for better readability
source_directory="$1"
target_directory="$2"
action="$3"
config_file="${source_directory}/sync/config.json"
run_args_string=""

# Check if a fourth argument (file path) is provided and assign it to a variable if it is
if [[ $# -ge 4 ]]; then
    exec_file_path="$4"
    exec_file_path_extension="${exec_file_path##*.}"

    # Validate the file type (Python script or Jupyter notebook)
    if [[ "$exec_file_path_extension" != "py" ]] && [[ "$exec_file_path_extension" != "ipynb" ]]; then
        echo "Invalid file type: $exec_file_path_extension. Expected a Python script (.py) or a Jupyter notebook (.ipynb)."
        exit 1
    fi

    # Prepare additional command line arguments e.g. the Python command
    shift 4
    run_args=("$@")
    run_args_string=$(printf "%q " "${run_args[@]}")
else
    exec_file_path="" # Ensure file_path is empty if no fourth argument is provided
    exec_file_path_extension=""
fi

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
      ssh -i "$peer_ssh_key" -T "${peer_user}@${peer_host}" \
        EXEC_FILE="$exec_file_path" \
        FILE_EXTENSION="$exec_file_path_extension" \
        PROJECT_NAME="$PROJECT_NAME" \
        COUNTER="$counter" \
        TARGET_DIR="$target_directory" bash -l -s -- "$run_args_string" << 'EOF' > /dev/null 2>&1
        
        # "$@" has access to run_args_string
        # Change directory to the target directory
        cd ~/$TARGET_DIR

        # Update the NODE_RANK in the .env file
        sed -i "s/^NODE_RANK=.*/NODE_RANK=$COUNTER/" .env

        # Update the machine_rank in the .config.yaml file
        if [ -f "$PROJECT_NAME/default_config.yaml" ]; then
            yq e ".machine_rank = $COUNTER" -i "$PROJECT_NAME/default_config.yaml"
        fi

        # Stop the existing podman container
        podman stop $PROJECT_NAME-$COUNTER || true

        # Build the new image with podman
        podman build --format docker --build-arg-file=./argfile.conf --tag ml-lab:latest -f ./Dockerfile

        # Remove dangling images
        podman images -f dangling=true -q | xargs --no-run-if-empty podman rmi

        # Run the podman container
        podman run --init --rm --name $PROJECT_NAME-$COUNTER \
            --device=nvidia.com/gpu=all \
            --security-opt=label=disable \
            --ipc=host \
            --net=host \
            --env-file=.env \
            -v ./${PROJECT_NAME}:/workspace/${PROJECT_NAME} \
            -v ./"${PROJECT_NAME}"/default_config.yaml:/workspace/.huggingface/accelerate/default_config.yaml \
            -v ./data:/workspace/data \
            -d ml-lab:latest

        # Define the execution path
        EXEC_PATH="/workspace/${PROJECT_NAME}/$EXEC_FILE"
        LOG=$PROJECT_NAME-$COUNTER.log

        # Case statement for different file extensions
        case $FILE_EXTENSION in
            ipynb)
                if podman exec $PROJECT_NAME-$COUNTER test -f "$EXEC_PATH"; then
                    nohup podman exec $PROJECT_NAME-$COUNTER conda run --live-stream -n accelerate jupyter nbconvert --execute --to notebook --inplace $EXEC_PATH > $LOG 2>&1 & echo $! > run.pid
                else
                    echo "File $EXEC_PATH does not exist."
                fi
                ;;
            py)
                if podman exec $PROJECT_NAME-$COUNTER test -f "$EXEC_PATH"; then
                    if [[ -n "$@" ]]; then
                        nohup podman exec $PROJECT_NAME-$COUNTER conda run --live-stream -n accelerate accelerate launch $EXEC_PATH "$@" > $PROJECT_NAME-$COUNTER.log 2>&1 & echo $! > run.pid
                    else
                        nohup podman exec $PROJECT_NAME-$COUNTER conda run --live-stream -n accelerate accelerate launch $EXEC_PATH > $PROJECT_NAME-$COUNTER.log 2>&1 & echo $! > run.pid
                    fi
                else
                    echo "File $EXEC_PATH does not exist."
                fi
                ;;
            *)
                echo "No execute: $FILE_EXTENSION"
                ;;
        esac
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