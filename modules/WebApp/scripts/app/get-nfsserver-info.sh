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
REGION=$2
SERVICE_ACCOUNT=$3

if [ -n "${SERVICE_ACCOUNT}" ]; then
    SA_ARG="--impersonate-service-account=${SERVICE_ACCOUNT}"
fi

# List all zones in the specified region
ZONES=$(gcloud compute zones list --project="${PROJECT_ID}" --filter="region:($REGION)" --format="value(name)" $SA_ARG 2>/dev/null)

if [ -z "$ZONES" ]; then
    echo '{}'
    exit 0
fi

# Search for the instance with a name starting with "nfsserver"
# We handle the case where no instance is found by checking the output
INSTANCE_JSON=$(gcloud compute instances list --project="${PROJECT_ID}" --filter="name~'^nfsserver' AND zone:(${ZONES})" --format="json" $SA_ARG 2>/dev/null)

if [ -z "$INSTANCE_JSON" ] || [ "$INSTANCE_JSON" == "[]" ]; then
    echo '{}'
else
    # Parse the JSON safely
    echo "$INSTANCE_JSON" | jq -r '.[0] | {gce_instance_name: .name, gce_instance_zone: .zone, gce_instance_internalIP: .networkInterfaces[0].networkIP}' 2>/dev/null || echo '{}'
fi
