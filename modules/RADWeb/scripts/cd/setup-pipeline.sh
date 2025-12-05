#!/bin/bash
# set -x

# Copyright 2023 Google LLC
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

# echo "Current working directory: $(pwd)"
# echo "Listing files in $(pwd):"
# ls -la

PROJECT_ID=$1
APP_REGION=$2
TF_SA=$3
RELEASE_TIMESTAMP=$(date '+%Y%m%d-%H%M%S')

if [ -n "${TF_SA}" ] 
then
    SA_ARG="--impersonate-service-account=${TF_SA}"
fi

gcloud config set project ${PROJECT_ID} $SA_ARG
    
gcloud --project $PROJECT_ID deploy apply --file=clouddeploy.yaml --region=${APP_REGION} $SA_ARG
gcloud --project $PROJECT_ID beta builds submit . --config cloudbuild.yaml --substitutions=_RELEASE_TIMESTAMP=${RELEASE_TIMESTAMP} $SA_ARG

