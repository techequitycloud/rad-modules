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

#########################################################################
# GitHub Repository Connection
#########################################################################

# Wait for IAM permissions to propagate before creating Cloud Build v2 connection
resource "time_sleep" "wait_for_iam" {
  count = local.enable_cicd_trigger && local.github_token_secret != null ? 1 : 0

  create_duration = "30s"

  depends_on = [
    google_secret_manager_secret_iam_member.github_token_default_sa
  ]
}

# Create GitHub connection for Cloud Build
# Connection name is scoped to tenant_id and deployment_id for complete deployment isolation
resource "google_cloudbuildv2_connection" "github_connection" {
  count    = local.enable_cicd_trigger ? 1 : 0
  project  = local.project.project_id
  location = local.region
  name     = "${local.tenant_id}-${local.deployment_id}-${local.application_name}-github-conn"

  github_config {
    app_installation_id = null # Will use GitHub App installation

    dynamic "authorizer_credential" {
      for_each = local.github_token_secret != null ? [1] : []
      content {
        oauth_token_secret_version = "projects/${local.project.project_id}/secrets/${local.github_token_secret}/versions/latest"
      }
    }
  }

  depends_on = [
    time_sleep.wait_for_iam
  ]
}

# Wait for GitHub connection to complete installation
# The GitHub App installation must be in COMPLETE state before creating repository
resource "time_sleep" "wait_for_github_connection" {
  count = local.enable_cicd_trigger ? 1 : 0

  create_duration = "300s"

  depends_on = [
    google_cloudbuildv2_connection.github_connection
  ]
}

# Create repository link
# Repository name is scoped to tenant_id and deployment_id for complete deployment isolation
resource "google_cloudbuildv2_repository" "github_repository" {
  count             = local.enable_cicd_trigger ? 1 : 0
  project           = local.project.project_id
  location          = local.region
  name              = local.github_repository_resource_name
  parent_connection = google_cloudbuildv2_connection.github_connection[0].name
  remote_uri        = local.github_repo_url

  depends_on = [
    time_sleep.wait_for_github_connection
  ]
}

#########################################################################
# Cloud Build Trigger for CI/CD
#########################################################################

resource "google_cloudbuild_trigger" "cicd_trigger" {
  count       = local.enable_cicd_trigger ? 1 : 0
  project     = local.project.project_id
  location    = local.region
  name        = local.cicd_trigger_name
  description = var.cicd_trigger_config.description

  # GitHub trigger configuration
  repository_event_config {
    repository = google_cloudbuildv2_repository.github_repository[0].id

    push {
      branch = var.cicd_trigger_config.branch_pattern
    }
  }

  # Inline build configuration (no cloudbuild.yaml required in repo)
  build {
    # Build container image with Kaniko
    step {
      name = "gcr.io/kaniko-project/executor:latest"
      args = concat(
        [
          "--dockerfile=$${_DOCKERFILE}",
          "--context=dir://$${_CONTEXT_PATH}",
          "--destination=$${_IMAGE_REGION}-docker.pkg.dev/$${_PROJECT_ID}/$${_REPO_NAME}/$${_IMAGE_NAME}:$${_IMAGE_VERSION}",
          "--destination=$${_IMAGE_REGION}-docker.pkg.dev/$${_PROJECT_ID}/$${_REPO_NAME}/$${_IMAGE_NAME}:latest",
          "--destination=$${_IMAGE_REGION}-docker.pkg.dev/$${_PROJECT_ID}/$${_REPO_NAME}/$${_IMAGE_NAME}:$$COMMIT_SHA",
          "--cache=true",
          "--cache-ttl=24h"
        ],
        [for k, v in var.container_build_config.build_args : "--build-arg=${k}=${v}"]
      )
      timeout = "1800s"
    }

    # Deploy to Cloud Run
    step {
      name       = "gcr.io/google.com/cloudsdktool/cloud-sdk:slim"
      entrypoint = "gcloud"
      args = [
        "run",
        "services",
        "update",
        "$${_CLOUD_RUN_SERVICE}",
        "--platform=managed",
        "--region=$${_CLOUD_RUN_REGION}",
        "--image=$${_IMAGE_REGION}-docker.pkg.dev/$${_PROJECT_ID}/$${_REPO_NAME}/$${_IMAGE_NAME}:$$COMMIT_SHA",
        "--quiet"
      ]
      timeout = "600s"
    }

    # Build timeout
    timeout = "3600s"

    # Substitutions for build variables
    substitutions = merge(
      {
        _PROJECT_ID        = local.project.project_id
        _APP_NAME          = local.service_name
        _IMAGE_REGION      = local.region
        _IMAGE_NAME        = local.application_name
        _IMAGE_VERSION     = local.application_version
        _REPO_NAME         = local.artifact_repo_id
        _DOCKERFILE        = var.container_build_config.dockerfile_path
        _CONTEXT_PATH      = var.container_build_config.context_path
        _CLOUD_RUN_SERVICE = local.service_name
        _CLOUD_RUN_REGION  = local.region
      },
      var.cicd_trigger_config.substitutions
    )

    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }

  # Service account for builds
  service_account = "projects/${local.project.project_id}/serviceAccounts/${local.cloudbuild_sa}@${local.project.project_id}.iam.gserviceaccount.com"

  tags = ["cicd", "automated", local.application_name]

  depends_on = [
    google_cloudbuildv2_repository.github_repository,
    data.google_artifact_registry_repository.application_image
  ]
}

#########################################################################
# Initial Placeholder Image Build
#########################################################################

# Create a placeholder Dockerfile for initial deployment
resource "local_file" "placeholder_dockerfile" {
  count = local.enable_cicd_trigger && local.container_image_source == "custom" ? 1 : 0

  filename = "${path.module}/scripts/app/Dockerfile.placeholder"
  content  = <<-EOF
    # Placeholder container for initial deployment
    # This will be replaced by your application container from GitHub
    FROM nginx:alpine

    # Add a simple health check page
    RUN echo '<!DOCTYPE html><html><head><title>Application Starting</title></head><body><h1>Application Deployment In Progress</h1><p>Your application is being deployed. The CI/CD pipeline will build and deploy your actual application container.</p></body></html>' > /usr/share/nginx/html/index.html

    # Health check
    HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
      CMD wget --no-verbose --tries=1 --spider http://localhost:80/ || exit 1

    EXPOSE 80

    CMD ["nginx", "-g", "daemon off;"]
  EOF
}

# Build and push placeholder image
resource "null_resource" "build_placeholder_image" {
  count = local.enable_cicd_trigger && local.container_image_source == "custom" ? 1 : 0

  triggers = {
    dockerfile_hash = local_file.placeholder_dockerfile[0].content
    repository_id   = data.google_artifact_registry_repository.application_image[0].repository_id
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/app"
    command     = <<-EOT
      # Create a cloudbuild.yaml for the placeholder image
      cat > cloudbuild-placeholder.yaml <<'YAML'
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - '${local.region}-docker.pkg.dev/${local.project.project_id}/${local.artifact_repo_id}/${local.application_name}:${local.application_version}'
      - '-t'
      - '${local.region}-docker.pkg.dev/${local.project.project_id}/${local.artifact_repo_id}/${local.application_name}:latest'
      - '-f'
      - 'Dockerfile.placeholder'
      - '.'
images:
  - '${local.region}-docker.pkg.dev/${local.project.project_id}/${local.artifact_repo_id}/${local.application_name}:${local.application_version}'
  - '${local.region}-docker.pkg.dev/${local.project.project_id}/${local.artifact_repo_id}/${local.application_name}:latest'
YAML

      # Build placeholder image with Cloud Build
      gcloud builds submit \
        --project="${local.project.project_id}" \
        --region="${local.region}" \
        --config=cloudbuild-placeholder.yaml \
        --service-account="projects/${local.project.project_id}/serviceAccounts/${local.cloudbuild_sa}@${local.project.project_id}.iam.gserviceaccount.com" \
        ${local.impersonation_service_account != "" ? "--impersonate-service-account=${local.impersonation_service_account}" : ""} \
        --timeout=10m \
        .

      # Clean up temporary file
      rm -f cloudbuild-placeholder.yaml
    EOT
  }

  depends_on = [
    local_file.placeholder_dockerfile,
    google_artifact_registry_repository.application_image,
    data.google_artifact_registry_repository.application_image
  ]
}
