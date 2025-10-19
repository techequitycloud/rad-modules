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

PROJECT_ID=$1
SERVICE_ACCOUNT=$2

if [ -n "${SERVICE_ACCOUNT}" ]; then
    SA_ARG="--impersonate-service-account=${SERVICE_ACCOUNT}"
fi

# Get all GKE clusters in the project (any region)
CLUSTER_INFO=$(gcloud container clusters list --project="${PROJECT_ID}" --format="value(name,location)" $SA_ARG | head -1)

# Check if any cluster was found
if [ -n "$CLUSTER_INFO" ]; then
    # Extract cluster name and location from the output
    CLUSTER_NAME=$(echo "$CLUSTER_INFO" | cut -f1)
    CLUSTER_LOCATION=$(echo "$CLUSTER_INFO" | cut -f2)
    
    # Output the cluster name, region, and exists flag in valid JSON format
    echo '{'
    echo '"gke_cluster_name": "'"${CLUSTER_NAME}"'",'
    echo '"gke_cluster_region": "'"${CLUSTER_LOCATION}"'",'
    echo '"gke_cluster_exists": "true"'
    echo '}'
else
    echo '{'
    echo '"gke_cluster_name": "",'
    echo '"gke_cluster_region": "",'
    echo '"gke_cluster_exists": "false"'
    echo '}'
fi
