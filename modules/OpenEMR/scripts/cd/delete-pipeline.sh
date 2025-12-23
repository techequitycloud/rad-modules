
#!/bin/bash
# set -x

# Copyright 2024 Tech Equity Ltd

# echo "Current working directory: $(pwd)"
# echo "Listing files in $(pwd):"
# ls -la

export PROJECT_ID=$1
export NFS_IP=$2
export NFS_ZONE=$3
export PIPELINE_NAME=$4
export TARGET_NAME=$5
export APP_NAME=$6
export APP_PREFIX=$7
export APP_REGION=$8
export SERVICE_ACCOUNT=$9

if [ -n "${SERVICE_ACCOUNT}" ] 
then
    SA_ARG="--impersonate-service-account=${SERVICE_ACCOUNT}"
fi

gcloud config set project ${PROJECT_ID} $SA_ARG

FLAG_FILE="./.db_script_ran_flag"

# Check if the script has run before by checking for the flag file
if [ ! -f "$FLAG_FILE" ]; then
    echo "First run detected. Waiting for 180 seconds."
    sleep 180
    # Create the flag file to indicate the script has run
    touch "$FLAG_FILE"
    for i in $(gcloud --project $PROJECT_ID compute os-login ssh-keys list $SA_ARG 2>/dev/null | grep -v FINGERPRINT); do echo $i; gcloud --project $PROJECT_ID compute os-login ssh-keys remove --key $i $SA_ARG 2>/dev/null; done # Avoid error "Login profile size exceeds 32 KiB"
else
    echo "Flag file exists. Skipping initial delay."
fi

# Maximum number of attempts
max_attempts=6
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
# Initialize a flag to determine if the delete operation was attempted
delete_attempted=false

# Function to delete Cloud Run service
delete_cloud_run_service() {
    local service_name=$1
    local attempt=0
    local max_attempts=5

    while gcloud run services describe ${service_name} --project=${PROJECT_ID} --region=${APP_REGION} $SA_ARG 2>/dev/null; do
        echo "Cloud Run service ${service_name} still exists. Attempting to delete..."
        # If the service is still there, try to delete it
        if gcloud run services delete ${service_name} --project=${PROJECT_ID} --region=${APP_REGION} --quiet $SA_ARG; then
            echo "Cloud Run service ${service_name} is being deleted."
            delete_attempted=true
            break
        else
            attempt=$((attempt + 1))
            if [ $attempt -ge $max_attempts ]; then
                echo "Failed to delete Cloud Run service ${service_name} after ${max_attempts} attempts. Exiting."
                break
            fi
            echo "Failed to delete Cloud Run service ${service_name}. Retrying... (Attempt $attempt of $max_attempts)"
            sleep 10
        fi
    done
}

# Function to delete Cloud Run job
delete_cloud_run_job() {
    local job_name=$1
    local attempt=0
    local max_attempts=5

    while gcloud run jobs describe ${job_name} --project=${PROJECT_ID} --region=${APP_REGION} $SA_ARG 2>/dev/null; do
        echo "Cloud Run job ${job_name} still exists. Attempting to delete..."
        # If the job is still there, try to delete it
        if gcloud run jobs delete ${job_name} --project=${PROJECT_ID} --region=${APP_REGION} --quiet $SA_ARG; then
            echo "Cloud Run job ${job_name} is being deleted."
            delete_attempted=true
            break
        else
            attempt=$((attempt + 1))
            if [ $attempt -ge $max_attempts ]; then
                echo "Failed to delete Cloud Run job ${job_name} after ${max_attempts} attempts. Exiting."
                break
            fi
            echo "Failed to delete Cloud Run job ${job_name}. Retrying... (Attempt $attempt of $max_attempts)"
            sleep 10
        fi
    done
}

# Delete services
delete_cloud_run_service "${APP_PREFIX}${APP_NAME}"
delete_cloud_run_job "${APP_PREFIX}${APP_NAME}"

if [ "$delete_attempted" = true ]; then
    echo "Waiting for 120 seconds for the service to be completely deleted."
    sleep 120
fi

echo "Cloud Run service deleted or does not exist. Proceeding."

gcloud --project $PROJECT_ID deploy targets delete ${TARGET_NAME}-run-env --region=${APP_REGION} --quiet $SA_ARG

gcloud deploy delivery-pipelines delete ${PIPELINE_NAME} --region=${APP_REGION} --project=${PROJECT_ID} --force --quiet $SA_ARG || true

sleep 30
