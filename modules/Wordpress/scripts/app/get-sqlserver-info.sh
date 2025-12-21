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

# set -x

# Check for required tools
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq is not installed"}' >&2
    exit 1
fi

# Parse arguments
PROJECT_ID=$1
DB_TYPE=$2
SERVICE_ACCOUNT=$3

# Validate required arguments
if [ -z "${PROJECT_ID}" ] || [ -z "${DB_TYPE}" ]; then
    echo '{"error": "Missing required arguments: PROJECT_ID and DB_TYPE"}' >&2
    exit 1
fi

# Initialize service account argument
SA_ARG=""
if [ -n "${SERVICE_ACCOUNT}" ]; then
    SA_ARG="--impersonate-service-account=${SERVICE_ACCOUNT}"
fi

# Get SQL instances across all regions (no region filter)
INSTANCE_INFO=$(gcloud sql instances list \
    --project="${PROJECT_ID}" \
    --filter="databaseVersion:${DB_TYPE}*" \
    --format="json" \
    $SA_ARG 2>/dev/null)

# Check if any instances were found
if [ -n "$INSTANCE_INFO" ] && [ "$INSTANCE_INFO" != "[]" ]; then
    # Get the first instance details
    INSTANCE_NAME=$(echo "$INSTANCE_INFO" | jq -r '.[0].name // ""')
    INSTANCE_REGION=$(echo "$INSTANCE_INFO" | jq -r '.[0].region // ""')
    DATABASE_VERSION=$(echo "$INSTANCE_INFO" | jq -r '.[0].databaseVersion // ""')
    PRIVATE_IP=$(echo "$INSTANCE_INFO" | jq -r '.[0].ipAddresses[]? | select(.type == "PRIVATE") | .ipAddress // ""')
    
    # Try to get root password from secrets
    ROOT_PASSWORD=""
    if [ -n "$INSTANCE_NAME" ]; then
        ROOT_PASSWORD=$(gcloud secrets versions access latest \
            --project="${PROJECT_ID}" \
            --secret="${INSTANCE_NAME}-root-password" \
            $SA_ARG 2>/dev/null || echo "")
    fi
    
    # Output JSON using jq for proper escaping
    jq -n \
        --arg exists "true" \
        --arg name "${INSTANCE_NAME}" \
        --arg region "${INSTANCE_REGION}" \
        --arg ip "${PRIVATE_IP}" \
        --arg version "${DATABASE_VERSION}" \
        --arg password "${ROOT_PASSWORD}" \
        '{
            sql_server_exists: $exists,
            instance_name: $name,
            instance_region: $region,
            instance_ip: $ip,
            database_version: $version,
            root_password: $password
        }'
else
    # No instances found - output using jq
    jq -n \
        --arg exists "false" \
        '{
            sql_server_exists: $exists,
            instance_name: "",
            instance_region: "",
            instance_ip: "",
            database_version: "",
            root_password: ""
        }'
fi
