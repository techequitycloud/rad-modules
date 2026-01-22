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

# Arguments
PROJECT_ID="$1"
REGION="$2"
REPO_NAME="$3"
SOURCE_IMAGE="$4"
TARGET_IMAGE_NAME="$5"
TAG="$6"

if [ -z "$PROJECT_ID" ] || [ -z "$REGION" ] || [ -z "$REPO_NAME" ] || [ -z "$SOURCE_IMAGE" ] || [ -z "$TARGET_IMAGE_NAME" ] || [ -z "$TAG" ]; then
    echo "Usage: $0 PROJECT_ID REGION REPO_NAME SOURCE_IMAGE TARGET_IMAGE_NAME TAG"
    exit 1
fi

FULL_TARGET_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${TARGET_IMAGE_NAME}:${TAG}"

echo "----------------------------------------------------------------"
echo "Image Mirroring Utility"
echo "Source: ${SOURCE_IMAGE}"
echo "Target: ${FULL_TARGET_IMAGE}"
echo "----------------------------------------------------------------"

# Check if image already exists
echo "Checking if image exists in Artifact Registry..."
if gcloud artifacts docker images describe "${FULL_TARGET_IMAGE}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
  echo "✅ Image ${FULL_TARGET_IMAGE} already exists. Skipping mirror."
  exit 0
fi

echo "Image not found. Initiating Cloud Build to mirror image..."

# Create a temporary workspace
WORK_DIR=$(mktemp -d)
pushd "$WORK_DIR" > /dev/null

# Create cloudbuild.yaml for mirroring
cat > cloudbuild.yaml <<EOF
steps:
- name: 'gcr.io/cloud-builders/docker'
  id: 'Pull Source Image'
  args: ['pull', '${SOURCE_IMAGE}']

- name: 'gcr.io/cloud-builders/docker'
  id: 'Tag Image'
  args: ['tag', '${SOURCE_IMAGE}', '${FULL_TARGET_IMAGE}']

- name: 'gcr.io/cloud-builders/docker'
  id: 'Push to Artifact Registry'
  args: ['push', '${FULL_TARGET_IMAGE}']

images:
- '${FULL_TARGET_IMAGE}'
EOF

# Submit build
echo "Submitting Cloud Build job..."
gcloud builds submit --project="${PROJECT_ID}" --config=cloudbuild.yaml .

# Cleanup
popd > /dev/null
rm -rf "$WORK_DIR"

echo "✅ Mirror complete. Image available at ${FULL_TARGET_IMAGE}"
