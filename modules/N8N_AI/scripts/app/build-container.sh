#!/bin/bash
# Copyright 2025 Tech Equity Ltd
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

PROJECT_ID=$1
SERVICE_ACCOUNT=$2

if [ -n "${SERVICE_ACCOUNT}" ]; then
    SA_ARG="--impersonate-service-account=${SERVICE_ACCOUNT}"
else
    SA_ARG=""
fi

MAX_ATTEMPTS=4
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "Attempting build (attempt $ATTEMPT/$MAX_ATTEMPTS)..."
    
    if gcloud --project="${PROJECT_ID}" builds submit . \
        --config cloudbuild.yaml \
        --timeout=30m \
        --suppress-logs \
        $SA_ARG; then
        echo "✅ Build completed successfully!"
        exit 0
    fi
    
    if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
        WAIT_TIME=$((30 * ATTEMPT))
        echo "Build failed. Retrying in ${WAIT_TIME} seconds (attempt $((ATTEMPT + 1))/$MAX_ATTEMPTS)..."
        sleep $WAIT_TIME
    fi
    
    ATTEMPT=$((ATTEMPT + 1))
done

echo "❌ Build failed after $MAX_ATTEMPTS attempts. Exiting."
exit 1
