#!/bin/bash
# Copyright 2024 Tech Equity Ltd
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

PROJECT_ID=$1
APP_VERSION=$2
APP_DOWNLOAD_FILEID=$3
SERVICE_ACCOUNT=$4

if [ -n "${SERVICE_ACCOUNT}" ] 
then
    SA_ARG="--impersonate-service-account=${SERVICE_ACCOUNT}"
    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/storage.objectViewer" --no-user-output-enabled 
fi

echo "Listing files in $(pwd):"
ls -la

cat <<EOF > $(pwd)/Dockerfile # to create Dockerfile
FROM cyclos/cyclos:latest
ADD cyclos.properties \\\$CYCLOS_HOME/WEB-INF/classes
ADD hazelcast.xml \\\$CYCLOS_HOME/WEB-INF/classes
EOF
  
# Attempt to submit the build
if ! gcloud --project="${PROJECT_ID}" builds submit . --config cloudbuild.yaml $SA_ARG; then
    echo "Initial build failed, retrying..."
    sleep 60  # Wait before retrying
    if ! gcloud --project="${PROJECT_ID}" builds submit . --config cloudbuild.yaml $SA_ARG; then
        echo "Retry build failed as well. Exiting."
        exit 1
    fi
fi

rm -rf cyclos-${APP_VERSION}*

