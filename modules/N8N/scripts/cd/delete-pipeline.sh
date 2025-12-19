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

set -e

# Delete services
delete_cloud_run_service() {
    local service_name=$1
    echo "Deleting Cloud Run service: $service_name"

    while gcloud run services describe ${service_name} --project=${PROJECT_ID} --region=${APP_REGION} $SA_ARG 2>/dev/null; do
        gcloud run services delete ${service_name} --project=${PROJECT_ID} --region=${APP_REGION} --quiet $SA_ARG 2>/dev/null || true
        sleep 5
    done
}

# Delete jobs
delete_cloud_run_job() {
    local job_name=$1
    echo "Deleting Cloud Run job: $job_name"

    while gcloud run jobs describe ${job_name} --project=${PROJECT_ID} --region=${APP_REGION} $SA_ARG 2>/dev/null; do
        gcloud run jobs delete ${job_name} --project=${PROJECT_ID} --region=${APP_REGION} --quiet $SA_ARG 2>/dev/null || true
        sleep 5
    done
}

if [ -n "${RESOURCE_CREATOR_IDENTITY}" ]; then
  SA_ARG="--impersonate-service-account=${RESOURCE_CREATOR_IDENTITY}"
fi

# Clean up os-login ssh-keys to avoid "Login profile size exceeds 32 KiB" error
if [ -z "${RESOURCE_CREATOR_IDENTITY}" ]; then
    for i in $(gcloud --project $PROJECT_ID compute os-login ssh-keys list $SA_ARG 2>/dev/null | grep -v FINGERPRINT); do echo $i; gcloud --project $PROJECT_ID compute os-login ssh-keys remove --key $i $SA_ARG 2>/dev/null; done # Avoid error "Login profile size exceeds 32 KiB"
fi

# Delete services
delete_cloud_run_service "${APP_PREFIX}${APP_NAME}"
delete_cloud_run_job "${APP_PREFIX}${APP_NAME}"

# Delete targets
gcloud --project $PROJECT_ID deploy targets delete ${TARGET_NAME}-env --region=${APP_REGION} --quiet $SA_ARG

# Delete delivery pipeline
gcloud --project $PROJECT_ID deploy delivery-pipelines delete ${PIPELINE_NAME} --region=${APP_REGION} --force --quiet $SA_ARG
