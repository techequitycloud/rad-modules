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

# ===========================
# Input Parameters
# ===========================
PROJECT_ID="$1"
REGION="$2"
REPO_NAME="$3"
SOURCE_IMAGE="$4"
TARGET_IMAGE_NAME="$5"
TAG="$6"
IMPERSONATE_SA="$7"

# ===========================
# Validation
# ===========================
if [ -z "$PROJECT_ID" ] || [ -z "$REGION" ] || [ -z "$REPO_NAME" ] || [ -z "$SOURCE_IMAGE" ] || [ -z "$TARGET_IMAGE_NAME" ] || [ -z "$TAG" ]; then
    echo "❌ ERROR: Missing required arguments"
    echo "Usage: $0 PROJECT_ID REGION REPO_NAME SOURCE_IMAGE TARGET_IMAGE_NAME TAG [IMPERSONATE_SA]"
    exit 1
fi

FULL_TARGET_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${TARGET_IMAGE_NAME}:${TAG}"

echo "================================================================"
echo "🔄 Image Mirroring Utility (Enhanced with Crane)"
echo "================================================================"
echo "Source:      ${SOURCE_IMAGE}"
echo "Target:      ${FULL_TARGET_IMAGE}"
if [ -n "$IMPERSONATE_SA" ]; then
    echo "Impersonate: ${IMPERSONATE_SA}"
fi
echo "================================================================"

# ===========================
# Prepare gcloud arguments
# ===========================
gcloud_args=("--project=${PROJECT_ID}")
if [ -n "$IMPERSONATE_SA" ]; then
    gcloud_args+=("--impersonate-service-account=$IMPERSONATE_SA")
fi

# ===========================
# Check if image already exists
# ===========================
echo "🔍 Checking if image exists in Artifact Registry..."
if gcloud artifacts docker images describe "${FULL_TARGET_IMAGE}" "${gcloud_args[@]}" > /dev/null 2>&1; then
  echo "✅ Image ${FULL_TARGET_IMAGE} already exists. Skipping mirror."
  exit 0
fi

echo "📦 Image not found. Initiating Cloud Build to mirror image..."

# ===========================
# Create temporary workspace
# ===========================
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

pushd "$WORK_DIR" > /dev/null

# ===========================
# Create cloudbuild.yaml with Crane
# CRITICAL: NO 'images:' section - Crane pushes directly to registry
# ===========================
cat > cloudbuild.yaml <<'EOF_CRANE'
steps:
  # Step 1: Copy image using Crane
  - name: 'gcr.io/go-containerregistry/crane:latest'
    id: 'Copy Image with Crane'
    args:
      - 'copy'
      - '${SOURCE_IMAGE}'
      - '${FULL_TARGET_IMAGE}'
      - '--platform=linux/amd64'
    timeout: '1200s'

  # Step 2: Verify the image in Artifact Registry
  - name: 'gcr.io/go-containerregistry/crane:latest'
    id: 'Verify Image in Registry'
    args:
      - 'manifest'
      - '${FULL_TARGET_IMAGE}'
    timeout: '60s'

# NO images: section - this is what causes the error!
# Crane pushes directly to registry, image is not local

options:
  logging: CLOUD_LOGGING_ONLY

timeout: '1800s'
EOF_CRANE

# Substitute variables in the cloudbuild.yaml
sed -i "s|\${SOURCE_IMAGE}|${SOURCE_IMAGE}|g" cloudbuild.yaml
sed -i "s|\${FULL_TARGET_IMAGE}|${FULL_TARGET_IMAGE}|g" cloudbuild.yaml

# ===========================
# Submit Cloud Build job
# ===========================
echo "☁️ Submitting Cloud Build job with Crane..."
echo "================================================================"

if gcloud builds submit "${gcloud_args[@]}" --config=cloudbuild.yaml --no-source; then
  echo "================================================================"
  echo "✅ Mirror complete! Image available at:"
  echo "   ${FULL_TARGET_IMAGE}"
  echo "================================================================"
  popd > /dev/null
  exit 0
else
  echo "================================================================"
  echo "⚠️ Crane method encountered an issue. Trying Docker fallback..."
  echo "================================================================"
  
  # ===========================
  # Fallback: Docker-based cloudbuild.yaml
  # ===========================
  cat > cloudbuild-docker.yaml <<'EOF_DOCKER'
steps:
  # Step 1: Pull source image with retry
  - name: 'gcr.io/cloud-builders/docker'
    id: 'Pull Source Image'
    entrypoint: 'sh'
    args:
      - '-c'
      - |
        set -e
        MAX_RETRIES=3
        RETRY_COUNT=0
        
        while [ $$RETRY_COUNT -lt $$MAX_RETRIES ]; do
          echo "📥 Attempt $$((RETRY_COUNT + 1)) of $$MAX_RETRIES"
          
          if docker pull "${SOURCE_IMAGE}"; then
            echo "✅ Image pulled successfully"
            exit 0
          fi
          
          RETRY_COUNT=$$((RETRY_COUNT + 1))
          
          if [ $$RETRY_COUNT -lt $$MAX_RETRIES ]; then
            echo "⚠️ Pull failed. Retrying in 10 seconds..."
            sleep 10
            docker system prune -f || true
          fi
        done
        
        echo "❌ Failed to pull image after $$MAX_RETRIES attempts"
        exit 1
    timeout: '1200s'

  # Step 2: Tag image
  - name: 'gcr.io/cloud-builders/docker'
    id: 'Tag Image'
    args:
      - 'tag'
      - '${SOURCE_IMAGE}'
      - '${FULL_TARGET_IMAGE}'

  # Step 3: Push to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    id: 'Push to Artifact Registry'
    args:
      - 'push'
      - '${FULL_TARGET_IMAGE}'

# Docker method DOES need images: section
images:
  - '${FULL_TARGET_IMAGE}'

options:
  logging: CLOUD_LOGGING_ONLY

timeout: '1800s'
EOF_DOCKER

  # Substitute variables
  sed -i "s|\${SOURCE_IMAGE}|${SOURCE_IMAGE}|g" cloudbuild-docker.yaml
  sed -i "s|\${FULL_TARGET_IMAGE}|${FULL_TARGET_IMAGE}|g" cloudbuild-docker.yaml

  echo "☁️ Submitting fallback Cloud Build job with Docker..."
  
  if gcloud builds submit "${gcloud_args[@]}" --config=cloudbuild-docker.yaml --no-source; then
    echo "================================================================"
    echo "✅ Mirror complete (via Docker)! Image available at:"
    echo "   ${FULL_TARGET_IMAGE}"
    echo "================================================================"
    popd > /dev/null
    exit 0
  else
    echo "================================================================"
    echo "❌ Both Crane and Docker methods failed."
    echo "Check Cloud Build logs for details."
    echo "================================================================"
    popd > /dev/null
    exit 1
  fi
fi
