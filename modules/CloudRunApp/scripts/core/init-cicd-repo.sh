#!/bin/bash
# Copyright 2024 (c) Tech Equity Ltd
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

set -euo pipefail

# Environment variables passed from Terraform
GIT_REPO="${GIT_REPO}"
GIT_ORG="${GIT_ORG}"
GITHUB_TOKEN="${GITHUB_TOKEN}"
PROJECT_ID="${PROJECT_ID}"
REGION="${REGION}"
SERVICE_NAME="${SERVICE_NAME}"
CONTAINER_IMAGE="${CONTAINER_IMAGE}"
BRANCH_NAME="${BRANCH_NAME:-main}"
APP_SOURCE_DIR="${APP_SOURCE_DIR:-}"
APPLICATION_NAME="${APPLICATION_NAME:-}"

# Determine if we have application-specific source files
HAS_APP_SOURCE=false
if [[ -n "$APP_SOURCE_DIR" && -d "$APP_SOURCE_DIR" ]]; then
  # Convert to absolute path to ensure it works after cd
  APP_SOURCE_DIR=$(cd "$APP_SOURCE_DIR" && pwd)
  HAS_APP_SOURCE=true
  echo "✅ Found application source directory: $APP_SOURCE_DIR"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Initializing CI/CD Repository"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Repository: ${GIT_ORG}/${GIT_REPO}"
echo "Branch: ${BRANCH_NAME}"
echo "Application: ${APPLICATION_NAME}"
echo "Source files: $([ "$HAS_APP_SOURCE" = true ] && echo 'Application-specific' || echo 'Generic samples')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create temporary directory for repository
TEMP_DIR=$(mktemp -d)
cd "${TEMP_DIR}"

echo "📁 Cloning repository..."
git clone "https://${GITHUB_TOKEN}@github.com/${GIT_ORG}/${GIT_REPO}.git" repo
cd repo

# Configure git
git config user.email "cloud-run-deploy@techequity.cloud"
git config user.name "Cloud Run Deployment"
git config pull.rebase true

# Check if branch exists remotely
if git ls-remote --heads origin "${BRANCH_NAME}" | grep -q "${BRANCH_NAME}"; then
  echo "✅ Branch '${BRANCH_NAME}' already exists remotely, checking out..."
  git checkout "${BRANCH_NAME}"
  git pull origin "${BRANCH_NAME}"
else
  echo "🌿 Creating new branch '${BRANCH_NAME}'..."
  git checkout -b "${BRANCH_NAME}"
fi

# Copy application-specific source files if provided
if [ "$HAS_APP_SOURCE" = true ]; then
  echo "📦 Copying application source files from $APP_SOURCE_DIR..."

  # Copy all files from the source directory
  cp -r "$APP_SOURCE_DIR"/* . 2>/dev/null || true
  cp -r "$APP_SOURCE_DIR"/.[!.]* . 2>/dev/null || true

  # Add all copied files
  git add -A

  echo "✅ Application source files copied successfully"
fi

# Create README.md if it doesn't exist
if [[ ! -f "README.md" ]]; then
  echo "📝 Creating README.md..."
  cat > README.md <<EOF
# Cloud Run Application

This repository contains the Cloud Run application configuration and deployment pipeline.

## Deployment

Pushes to the \`${BRANCH_NAME}\` branch automatically trigger a deployment to Cloud Run.

- **Project ID**: ${PROJECT_ID}
- **Region**: ${REGION}
- **Service Name**: ${SERVICE_NAME}

## Cloud Build

The application is built and deployed using Google Cloud Build. See \`cloudbuild.yaml\` for the build configuration.

## Container Image

The container image is built from the Dockerfile and pushed to Artifact Registry:
\`\`\`
${CONTAINER_IMAGE}
\`\`\`

## Automatic Deployments

When you push changes to the \`${BRANCH_NAME}\` branch:
1. Cloud Build automatically triggers
2. Container image is built from Dockerfile
3. Image is pushed to Artifact Registry
4. Cloud Run service is updated with the new image

---
*Managed by Terraform - Do not edit manually*
EOF
  git add README.md
fi

# Create .gitignore if it doesn't exist
if [[ ! -f ".gitignore" ]]; then
  echo "📝 Creating .gitignore..."
  cat > .gitignore <<EOF
# Terraform
*.tfstate
*.tfstate.backup
.terraform/
.terraform.lock.hcl

# Environment variables
.env
.env.local
*.secret

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# Dependencies
node_modules/
vendor/
EOF
  git add .gitignore
fi

# Create cloudbuild.yaml if it doesn't exist
if [[ ! -f "cloudbuild.yaml" ]]; then
  echo "📝 Creating cloudbuild.yaml..."
  cat > cloudbuild.yaml <<EOF
# Cloud Build configuration for automatic deployment
# Triggered on push to ${BRANCH_NAME} branch

steps:
  # Build the container image
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - '${CONTAINER_IMAGE}:\$BRANCH_NAME-\$SHORT_SHA'
      - '-t'
      - '${CONTAINER_IMAGE}:latest'
      - '.'

  # Push the container image to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - '--all-tags'
      - '${CONTAINER_IMAGE}'

  # Deploy to Cloud Run
  - name: 'gcr.io/cloud-builders/gcloud'
    args:
      - 'run'
      - 'deploy'
      - '${SERVICE_NAME}'
      - '--image=${CONTAINER_IMAGE}:\$BRANCH_NAME-\$SHORT_SHA'
      - '--region=${REGION}'
      - '--platform=managed'

# Store images in Artifact Registry
images:
  - '${CONTAINER_IMAGE}:\$BRANCH_NAME-\$SHORT_SHA'
  - '${CONTAINER_IMAGE}:latest'

# Build options
options:
  logging: CLOUD_LOGGING_ONLY
  machineType: 'E2_HIGHCPU_8'

# Timeout
timeout: '1200s'
EOF
  git add cloudbuild.yaml
fi

# Create Dockerfile if it doesn't exist
if [[ ! -f "Dockerfile" ]]; then
  echo "📝 Creating Dockerfile..."
  cat > Dockerfile <<EOF
# Multi-stage build for Cloud Run application
# Adjust this Dockerfile based on your application's requirements

# Build stage (example for Node.js - customize as needed)
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Runtime stage
FROM node:18-alpine
WORKDIR /app

# Copy dependencies from builder
COPY --from=builder /app/node_modules ./node_modules

# Copy application code
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \\
    adduser -S nodejs -u 1001 && \\
    chown -R nodejs:nodejs /app

USER nodejs

# Expose port (Cloud Run uses PORT environment variable)
EXPOSE 8080
ENV PORT=8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
  CMD node -e "require('http').get('http://localhost:8080/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Start application
CMD ["node", "server.js"]
EOF
  git add Dockerfile
fi

# Create placeholder package.json if it doesn't exist (for Node.js example)
if [[ ! -f "package.json" ]]; then
  echo "📝 Creating package.json..."
  cat > package.json <<EOF
{
  "name": "${GIT_REPO}",
  "version": "1.0.0",
  "description": "Cloud Run application",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF
  git add package.json
fi

# Create placeholder server.js if it doesn't exist
if [[ ! -f "server.js" ]]; then
  echo "📝 Creating server.js..."
  cat > server.js <<'EOF'
const express = require('express');
const app = express();
const port = process.env.PORT || 8080;

// Middleware
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Cloud Run application is running!',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'production'
  });
});

// Start server
app.listen(port, () => {
  console.log(`Server listening on port ${port}`);
});
EOF
  git add server.js
fi

# Check if there are any changes to commit
if git diff --staged --quiet; then
  echo "✅ Repository already initialized, no changes to commit"
else
  echo "💾 Committing changes..."
  git commit -m "Initialize Cloud Run CI/CD repository

- Add Cloud Build configuration
- Add Dockerfile for container builds
- Add application code and dependencies
- Configure automatic deployment pipeline

Automated commit from Terraform deployment
"
fi

# Push to remote
echo "🚀 Pushing to GitHub..."
git push -u origin "${BRANCH_NAME}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Repository initialized successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Repository URL: https://github.com/${GIT_ORG}/${GIT_REPO}"
echo "Branch: ${BRANCH_NAME}"
echo ""
echo "Next steps:"
echo "  1. Customize the Dockerfile for your application"
echo "  2. Update server.js with your application code"
echo "  3. Push changes to trigger automatic deployment"
echo ""
echo "To trigger a deployment:"
echo "  git clone https://github.com/${GIT_ORG}/${GIT_REPO}.git"
echo "  cd ${GIT_REPO}"
echo "  # Make your changes"
echo "  git add ."
echo "  git commit -m 'Your changes'"
echo "  git push origin ${BRANCH_NAME}"
echo ""

# Cleanup
cd /
rm -rf "${TEMP_DIR}"

echo "🎉 Done!"
