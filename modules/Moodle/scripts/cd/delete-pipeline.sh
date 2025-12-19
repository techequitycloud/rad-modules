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

#!/bin/bash

# Arguments
PROJECT_ID=$1
NFS_IP=$2
ZONE=$3
PIPELINE_NAME=$4
TARGET_NAME=$5
APP_NAME=$6
APP_PREFIX=$7
APP_REGION=$8
CREATOR_SA=$9

# Set SA_ARG if CREATOR_SA is provided
if [ -n "$CREATOR_SA" ]; then
  SA_ARG="--impersonate-service-account=$CREATOR_SA"
else
  SA_ARG=""
fi

# Function to delete Cloud Run service
delete_cloud_run_service() {
  local service_name=$1
  echo "Deleting Cloud Run service: $service_name"
  if gcloud run services describe $service_name --region=$APP_REGION --project=$PROJECT_ID $SA_ARG >/dev/null 2>&1; then
    gcloud run services delete $service_name --region=$APP_REGION --project=$PROJECT_ID --quiet $SA_ARG
    echo "Deleted Cloud Run service: $service_name"
  else
    echo "Cloud Run service $service_name not found."
  fi
}

# Function to delete Cloud Run job
delete_cloud_run_job() {
  local job_name=$1
  echo "Deleting Cloud Run job: $job_name"
  if gcloud run jobs describe $job_name --region=$APP_REGION --project=$PROJECT_ID $SA_ARG >/dev/null 2>&1; then
    gcloud run jobs delete $job_name --region=$APP_REGION --project=$PROJECT_ID --quiet $SA_ARG
    echo "Deleted Cloud Run job: $job_name"
  else
    echo "Cloud Run job $job_name not found."
  fi
}

# Function to delete Artifact Registry repository
delete_artifact_registry() {
  local repo_name=$1
  echo "Deleting Artifact Registry repository: $repo_name"
  if gcloud artifacts repositories describe $repo_name --location=$APP_REGION --project=$PROJECT_ID $SA_ARG >/dev/null 2>&1; then
    gcloud artifacts repositories delete $repo_name --location=$APP_REGION --project=$PROJECT_ID --quiet $SA_ARG
    echo "Deleted Artifact Registry repository: $repo_name"
  else
    echo "Artifact Registry repository $repo_name not found."
  fi
}

# Function to delete Cloud Build trigger
delete_cloud_build_trigger() {
  local trigger_name=$1
  echo "Deleting Cloud Build trigger: $trigger_name"
  if gcloud builds triggers describe $trigger_name --region=$APP_REGION --project=$PROJECT_ID $SA_ARG >/dev/null 2>&1; then
    gcloud builds triggers delete $trigger_name --region=$APP_REGION --project=$PROJECT_ID --quiet $SA_ARG
    echo "Deleted Cloud Build trigger: $trigger_name"
  else
    echo "Cloud Build trigger $trigger_name not found."
  fi
}

# Delete Cloud Deploy pipeline
echo "Deleting Cloud Deploy pipeline: $PIPELINE_NAME"
if gcloud deploy delivery-pipelines describe $PIPELINE_NAME --region=$APP_REGION --project=$PROJECT_ID $SA_ARG >/dev/null 2>&1; then
  gcloud deploy delivery-pipelines delete $PIPELINE_NAME --region=$APP_REGION --project=$PROJECT_ID --force --quiet $SA_ARG
  echo "Deleted Cloud Deploy pipeline: $PIPELINE_NAME"
else
  echo "Cloud Deploy pipeline $PIPELINE_NAME not found."
fi

# Delete Cloud Deploy target
echo "Deleting Cloud Deploy target: $TARGET_NAME"
if gcloud deploy targets describe $TARGET_NAME --region=$APP_REGION --project=$PROJECT_ID $SA_ARG >/dev/null 2>&1; then
  gcloud deploy targets delete $TARGET_NAME --region=$APP_REGION --project=$PROJECT_ID --quiet $SA_ARG
  echo "Deleted Cloud Deploy target: $TARGET_NAME"
else
  echo "Cloud Deploy target $TARGET_NAME not found."
fi

# Delete services
delete_cloud_run_service "${APP_PREFIX}"
delete_cloud_run_job "${APP_PREFIX}"

# Delete Artifact Registry repository
# Note: Be careful with deleting repositories as they might contain images used by other services or historical data.
# Uncomment the line below if you want to delete the repository.
# delete_artifact_registry "${APP_NAME}"

# Delete Cloud Build trigger
# Note: Cloud Build triggers might be managed via Terraform, so deleting them here might cause inconsistencies.
# Uncomment the line below if you want to delete the trigger.
# delete_cloud_build_trigger "${APP_NAME}-trigger"

# Delete NFS directory
echo "Deleting NFS directory: /share/${APP_PREFIX}"
# This requires SSH access to the NFS server and might be complex to execute from here.
# Assuming the NFS server is accessible and we can run commands on it.
# You might need to adjust this part based on your NFS setup.

# Get NFS VM name
NFS_VM=$(gcloud compute instances list --project $PROJECT_ID --filter="INTERNAL_IP=${NFS_IP}" --format="value(name)" $SA_ARG)

if [ -n "$NFS_VM" ]; then
    gcloud compute ssh $NFS_VM --project $PROJECT_ID --zone $ZONE --command "sudo rm -rf /share/${APP_PREFIX}" --quiet $SA_ARG
    echo "Deleted NFS directory: /share/${APP_PREFIX}"
else
    echo "NFS VM not found for IP: $NFS_IP"
fi

echo "Cleanup completed."
