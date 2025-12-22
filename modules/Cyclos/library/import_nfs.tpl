#!/bin/bash
# Copyright 2024 (c) Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License. 

set -x

# Remove spaces from the region variables
APP_REGION_1=$(echo "${APP_REGION_1}" | tr -d '[:space:]')
APP_REGION_2=$(echo "${APP_REGION_2}" | tr -d '[:space:]')

# Maximum number of attempts
max_attempts=3
attempt=0
delete_attempted=false

# Loop until the service no longer exists or max attempts reached
while [ $attempt -lt $max_attempts ]; do
  services_found=false # Flag to track if any services were found

  # Check and delete service in APP_REGION_1
  if gcloud run services describe "${APP_NAME}" --project="${PROJECT_ID}" --region="$APP_REGION_1" 2>/dev/null; then
    echo "Cloud Run service still exists in region $APP_REGION_1. Attempting to delete..."
    
    # Try to delete the service
    if gcloud run services delete "${APP_NAME}" --project="${PROJECT_ID}" --region="$APP_REGION_1" --quiet; then
      echo "Cloud Run service is being deleted in region $APP_REGION_1."
      delete_attempted=true
      services_found=true # A service was found and is being deleted
    else
      echo "Failed to delete Cloud Run service in region $APP_REGION_1. Retrying..."
      services_found=true # A service was found but deletion failed
    fi
  else
    echo "Cloud Run service does not exist in region $APP_REGION_1."
  fi

  # Check and delete service in APP_REGION_2
  if gcloud run services describe "${APP_NAME}" --project="${PROJECT_ID}" --region="$APP_REGION_2" 2>/dev/null; then
    echo "Cloud Run service still exists in region $APP_REGION_2. Attempting to delete..."
    
    # Try to delete the service
    if gcloud run services delete "${APP_NAME}" --project="${PROJECT_ID}" --region="$APP_REGION_2" --quiet; then
      echo "Cloud Run service is being deleted in region $APP_REGION_2."
      delete_attempted=true
      services_found=true # A service was found and is being deleted
    else
      echo "Failed to delete Cloud Run service in region $APP_REGION_2. Retrying..."
      services_found=true # A service was found but deletion failed
    fi
  else
    echo "Cloud Run service does not exist in region $APP_REGION_2."
  fi

  # If no services were found, exit the loop
  if ! $services_found; then
    echo "No Cloud Run services found. Exiting..."
    break
  fi

  # If services were found and attempted, increment attempt and retry
  attempt=$((attempt + 1))
  echo "Retrying... Attempt $attempt of $max_attempts."
  sleep 10
done

# FLAG_FILE="./.script_ran_flag"

# Check if the script has run before by checking for the flag file
# if [ ! -f "$FLAG_FILE" ]; then
#     echo "First run detected. Waiting for 180 seconds."
#     sleep 180
#     # Create the flag file to indicate the script has run
#     touch "$FLAG_FILE"
#     for i in $(gcloud --project="${PROJECT_ID}" compute os-login ssh-keys list 2>/dev/null | grep -v FINGERPRINT); do echo $i; gcloud --project="${PROJECT_ID}" compute os-login ssh-keys remove --key $i 2>/dev/null; done # Avoid error "Login profile size exceeds 32 KiB"
# else
#     echo "Flag file exists. Skipping initial delay."
# fi

# Maximum number of attempts
max_attempts=3
attempt=0

# Loop until the NFS VM instance is in RUNNING status or max attempts reached
while [ $attempt -lt $max_attempts ]; do
    # Get the instance name using the internal IP address
    NFS_VM=$(gcloud --project ${PROJECT_ID} compute instances list --filter="INTERNAL_IP=${NFS_IP}" --format="value(NAME)")
    
    # Check the status of the instance
    status=$(gcloud --project ${PROJECT_ID} compute instances list --filter="INTERNAL_IP=${NFS_IP}" --format="value(status)")
    
    if [ "$status" = "RUNNING" ]; then
        echo "Instance is running."
        break
    else
        echo "Waiting for instance to be running... (Attempt $((attempt + 1)) of $max_attempts)"
        sleep 10 # wait before retrying
    fi
    
    attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
    echo "Max attempts reached. Instance is not running."
fi


# Ensure application directory is empty
gcloud compute ssh --project ${PROJECT_ID} --quiet $NFS_VM --zone ${NFS_ZONE} --command="sudo mkdir -p /share/${DB_USER} && sudo rm -rf /share/${DB_USER}/* && sudo chown -R nobody:nogroup /share/${DB_USER} && sudo chmod 775 /share/${DB_USER}"

# Update package list and install Python, pip
echo "Installing Python and pip..."
apt-get update -qq &>/dev/null
apt-get install -y python3 python3-pip unzip wget curl &>/dev/null

# Install gdown with proper error checking
echo "Installing gdown..."
pip3 install --upgrade gdown --user &>/dev/null

# Check if installation was successful
if [ $? -eq 0 ]; then
    echo "gdown installed successfully"
else
    echo "Failed to install gdown with pip3, trying pip..."
    pip install --upgrade gdown --user &>/dev/null
fi

# Set proper PATH - use full path for root user
export PATH="$HOME/.local/bin:/root/.local/bin:$PATH"

# Verify gdown is available
which gdown
if [ $? -eq 0 ]; then
    echo "gdown found in PATH: $(which gdown)"
else
    echo "gdown not found in PATH, trying common locations..."
    # Try common installation paths
    if [ -f "$HOME/.local/bin/gdown" ]; then
        export PATH="$HOME/.local/bin:$PATH"
        echo "Found gdown at $HOME/.local/bin/gdown"
    elif [ -f "/root/.local/bin/gdown" ]; then
        export PATH="/root/.local/bin:$PATH"
        echo "Found gdown at /root/.local/bin/gdown"
    else
        echo "ERROR: gdown not found after installation"
        exit 1
    fi
fi

# Attempt to download the backup file only if BACKUP_FILEID is not empty
if [ -n "${BACKUP_FILEID}" ] ; then
    echo "Attempting to download the backup file using gdown..."
    echo "Using gdown from: $(which gdown)"
    
    # Try downloading with full path if needed
    if gdown ${BACKUP_FILEID} -O backup.zip; then
        echo "Backup file downloaded successfully"
        if [ -f backup.zip ]; then
            echo "Backup file exists and is $(du -h backup.zip | cut -f1) in size"
        fi
    else
        echo "Warning: Failed to download the backup file using gdown."
    fi
else
    echo "Skipping download as BACKUP_FILEID is empty."
fi

# Check if the backup file exists locally
if [ -f "backup.zip" ]; then
    echo "Backup file exists locally."

    # Copy the data backup file to NFS VM
    gcloud compute scp --project "${PROJECT_ID}" --zone ${NFS_ZONE} backup.zip $NFS_VM:~/backup.zip
    
    # Extract the backup file and set  permissions
    gcloud compute ssh --project ${PROJECT_ID} --quiet $NFS_VM --zone ${NFS_ZONE} --command="sudo mkdir -p ${DB_NAME} && sudo rm -rf ${DB_NAME}/* && sudo unzip backup.zip -d ${DB_NAME}"
    
    # Move directory
    gcloud compute ssh --project ${PROJECT_ID} --quiet $NFS_VM --zone ${NFS_ZONE} --command="sudo rm -rf /share/${DB_USER}/* && sudo mv ${DB_NAME}/* /share/${DB_USER}/"

    # Change ownership
    gcloud compute ssh --project ${PROJECT_ID} --quiet $NFS_VM --zone ${NFS_ZONE} --command="sudo chmod -R 0777 /share/${DB_USER} && sudo chown -R nobody:nogroup /share/${DB_USER}"

    # Delete Backup from bastion host
    gcloud compute ssh --project ${PROJECT_ID} --quiet $NFS_VM --zone ${NFS_ZONE} --command="sudo rm -rf backup.zip && sudo rm -rf ${DB_NAME}"
fi

# Check if the shared directory exists
gcloud --project ${PROJECT_ID} --quiet compute ssh $NFS_VM --zone ${NFS_ZONE} --command="if [ ! -d /share/${DB_USER} ]; then echo 'Error: /share/${DB_USER} does not exist.'; exit 1; fi"

echo "Script completed successfully!"

