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
#!/bin/bash
PROJECT_ID=$1
DB_TYPE=$2
SERVICE_ACCOUNT=$3

if [ -n "${SERVICE_ACCOUNT}" ]; then
    SA_ARG="--impersonate-service-account=${SERVICE_ACCOUNT}"
fi

# Get SQL instances across all regions (no region filter)
INSTANCE_INFO=$(gcloud sql instances list --project="${PROJECT_ID}" --filter="databaseVersion:${DB_TYPE}*" --format="json" $SA_ARG 2>/dev/null)

# Check if any instances were found
if [ -n "$INSTANCE_INFO" ] && [ "$INSTANCE_INFO" != "[]" ]; then
    # Get the first instance details
    INSTANCE_NAME=$(echo "$INSTANCE_INFO" | jq -r '.[0].name // ""')
    INSTANCE_REGION=$(echo "$INSTANCE_INFO" | jq -r '.[0].region // ""')
    DATABASE_VERSION=$(echo "$INSTANCE_INFO" | jq -r '.[0].databaseVersion // ""')
    PRIVATE_IP=$(echo "$INSTANCE_INFO" | jq -r '.[0].ipAddresses[]? | select(.type == "PRIVATE") | .ipAddress // ""')

    # Try to get root password from secrets
    if [ -n "$INSTANCE_NAME" ]; then
        ROOT_PASSWORD=$(gcloud secrets versions access latest --project="${PROJECT_ID}" --secret="${INSTANCE_NAME}-root-password" $SA_ARG 2>/dev/null || echo "")
    else
        ROOT_PASSWORD=""
    fi

    # Output with sql_server_exists = true
    echo '{'
    echo '"sql_server_exists": "true",'
    echo '"instance_name": "'"${INSTANCE_NAME}"'",'
    echo '"instance_region": "'"${INSTANCE_REGION}"'",'
    echo '"instance_ip": "'"${PRIVATE_IP}"'",'
    echo '"database_version": "'"${DATABASE_VERSION}"'",'
    echo '"root_password": "'"${ROOT_PASSWORD}"'"'
    echo '}'
else
    # No instances found
    echo '{'
    echo '"sql_server_exists": "false",'
    echo '"instance_name": "",'
    echo '"instance_region": "",'
    echo '"instance_ip": "",'
    echo '"database_version": "",'
    echo '"root_password": ""'
    echo '}'
fi
