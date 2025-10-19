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

# echo "Current working directory: $(pwd)"
# echo "Listing files in $(pwd):"
# ls -la

export PROJECT_ID=$1
export PIPELINE_NAME=$2
export TARGET_NAME=$3
export APP_REGION=$4
export SERVICE_ACCOUNT=$5

if [ -n "${SERVICE_ACCOUNT}" ] 
then
    SA_ARG="--impersonate-service-account=${SERVICE_ACCOUNT}"
fi

gcloud --project $PROJECT_ID deploy targets delete ${TARGET_NAME}-dev-env --region=${APP_REGION} --quiet $SA_ARG
gcloud --project $PROJECT_ID deploy targets delete ${TARGET_NAME}-qa-env --region=${APP_REGION} --quiet $SA_ARG
gcloud --project $PROJECT_ID deploy targets delete ${TARGET_NAME}-prod-env --region=${APP_REGION} --quiet $SA_ARG

gcloud --project ${PROJECT_ID} deploy delivery-pipelines delete ${PIPELINE_NAME} --region=${APP_REGION} --force --quiet $SA_ARG || true

sleep 30