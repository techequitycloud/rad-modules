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

# set -x
# echo "Listing files in $(pwd):"
# ls -la

PROJECT_ID=$1
SERVICE_ACCOUNT=$2

# Only apply IAM binding if SERVICE_ACCOUNT is provided and not empty
if [ -n "${SERVICE_ACCOUNT}" ]; then
    SA_ARG="--impersonate-service-account=${SERVICE_ACCOUNT}"

    # We don't need to add IAM policy binding here as the impersonated account
    # should already have Owner permissions on the target project.
    # The previous script attempted to add roles/storage.objectViewer which might be
    # redundant or fail if the impersonating account lacks permission to set IAM policies.
    # However, to be safe and match Cyclos pattern, we can keep it but suppress errors if needed.

    echo "Using impersonation service account: ${SERVICE_ACCOUNT}"

    # Attempt to grant storage.objectViewer, but don't fail if it errors (e.g. if already exists or insufficient permission to grant)
    # This matches the behavior seen in Cyclos script (though Cyclos script doesn't explicitly suppress errors, the `builds submit` is the critical part)
    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/storage.objectViewer" --no-user-output-enabled || echo "Warning: Failed to add IAM binding, proceeding..."
else
    echo "No impersonation service account provided."
    SA_ARG=""
fi

# Attempt to submit the build
if ! gcloud --project="${PROJECT_ID}" builds submit . --config cloudbuild.yaml $SA_ARG; then
    echo "Initial build failed, retrying..."
    sleep 60  # Wait before retrying
    if ! gcloud --project="${PROJECT_ID}" builds submit . --config cloudbuild.yaml $SA_ARG; then
        echo "Retry build failed as well. Exiting."
        exit 1
    fi
fi
