#!/bin/bash

# Copyright 2024 Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -x

# Copyright 2024 Tech Equity Ltd

echo "Current working directory: $(pwd)"
echo "Listing files in $(pwd):"
ls -la

export PROJECT_ID=$1
export NFS_IP=$2
export NFS_ZONE=$3
export BACKUP_BUCKET=$4
export DB_IP=$5
export DB_NAME=$6
export DB_USER=$7
export DB_PASS=$8
export PG_PASS=$9
export SERVICE_ACCOUNT=${10}

if [ -n "${SERVICE_ACCOUNT}" ] 
then
    SA_ARG="--impersonate-service-account=${SERVICE_ACCOUNT}"
fi

FLAG_FILE="./.db_script_ran_flag"

# Check if the script has run before by checking for the flag file
if [ ! -f "$FLAG_FILE" ]; then
    echo "First run detected. Waiting for 180 seconds."
    sleep 180
    # Create the flag file to indicate the script has run
    touch "$FLAG_FILE"
    for i in $(gcloud --project="${PROJECT_ID}" compute os-login ssh-keys list $SA_ARG 2>/dev/null | grep -v FINGERPRINT); do echo $i; gcloud --project="${PROJECT_ID}" compute os-login ssh-keys remove --key $i $SA_ARG 2>/dev/null; done # Avoid error "Login profile size exceeds 32 KiB"
else
    echo "Flag file exists. Skipping initial delay."
fi

# Maximum number of attempts
max_attempts=3
attempt=0

# Loop until the NFS VM instance is in RUNNING status or max attempts reached
while [ $attempt -lt $max_attempts ]; do
  # Get the instance name using the internal IP address
  NFS_VM=$(gcloud --project $PROJECT_ID compute instances list --filter="INTERNAL_IP=${NFS_IP}" --format="value(NAME)" $SA_ARG)
  
  # Check the status of the instance
  status=$(gcloud --project $PROJECT_ID compute instances list --filter="INTERNAL_IP=${NFS_IP}" --format="value(status)" $SA_ARG)
  
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

# Display database user
gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="export PGPASSWORD=${DB_PASS} && psql -U ${DB_USER} -h ${DB_IP} -d postgres -c '\l'"

# Variables
MAX_RETRIES=10
RETRY_COUNT=0
BACKUP_SUCCESS=0
TIMESTAMP=$(date +%Y%m%d%H%M%S)

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    # Execute the gcloud command
    # gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="sudo mkdir -p /share/${DB_USER} && export PGPASSWORD=${DB_PASS} && sudo pg_dump --no-owner -U ${DB_USER} -h ${DB_IP} -d ${DB_NAME} > /share/${DB_USER}/dump.sql && sudo gzip /share/${DB_USER}/dump.sql"
    gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="sudo bash -c 'mkdir -p /share/${DB_USER} && sudo rm -rf /share/${DB_USER}/dump.sql && export PGPASSWORD=${DB_PASS} && pg_dump --no-owner -U ${DB_USER} -h ${DB_IP} -d ${DB_NAME} > /share/${DB_USER}/dump.sql'"

    # Check if the command was successful
    if [ $? -eq 0 ]; then
        BACKUP_SUCCESS=1
        break
    else
        echo "Backup failed, retrying..."
        ((RETRY_COUNT++))
    fi
done

if [ $BACKUP_SUCCESS -eq 0 ]; then
    echo "Backup failed after $MAX_RETRIES attempts."
    exit 0
fi

# Get the current timestamp
TIMESTAMP=$(date +%Y%m%d%H%M%S)

# Backup the filesystem
gcloud --project ${PROJECT_ID} --quiet compute ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="sudo rm -rf /share/temp && cd /share/${DB_USER} && sudo cp -rf filestore /share/temp && sudo mv /share/temp/* /share/temp/filestore && sudo cp -rf /share/${DB_USER}/addons /share/temp/ && sudo cp /share/${DB_USER}/dump.sql /share/temp/ && cd /share/temp && sudo chown -R nobody.nogroup /share && sudo zip -r ${DB_NAME}_${TIMESTAMP}.zip dump.sql addons filestore"

echo "Backup file in GCS"
# Copy the application data backup file from GCS to the Filestore instance
gcloud --project ${PROJECT_ID} --quiet compute ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="sudo gsutil cp /share/temp/${DB_NAME}_${TIMESTAMP}.zip gs://${BACKUP_BUCKET}/${DB_NAME}_${TIMESTAMP}.zip && sudo rm -rf /share/${DB_USER}/dump.sql && sudo rm -rf /share/temp"