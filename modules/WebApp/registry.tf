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
# Configure Artifact Registry
#########################################################################

# Check if the Artifact Registry repository already exists
data "external" "check_artifact_repo" {
  count = local.enable_custom_build || local.enable_cicd_trigger ? 1 : 0

  program = ["bash", "-c", <<-EOT
    PROJECT_ID="${local.project.project_id}"
    REPO_NAME="${var.container_build_config.artifact_repo_name}"
    LOCATION="${local.region}"

    if [ -n "${local.impersonation_service_account}" ]; then
      SA_ARG="--impersonate-service-account=${local.impersonation_service_account}"
    fi

    # Check if repository exists
    if gcloud artifacts repositories describe "$REPO_NAME" \
      --project="$PROJECT_ID" \
      --location="$LOCATION" \
      $SA_ARG >/dev/null 2>&1; then
      echo '{"exists": "true"}'
    else
      echo '{"exists": "false"}'
    fi
  EOT
  ]
}

# Resource for creating a Google Artifact Registry repository to store application images
# Created when either custom build is enabled OR CI/CD trigger is enabled
# Only creates if the repository doesn't already exist
resource "google_artifact_registry_repository" "application_image" {
  count = (local.enable_custom_build || local.enable_cicd_trigger) && try(data.external.check_artifact_repo[0].result.exists, "false") == "false" ? 1 : 0

  project       = local.project.project_id
  location      = local.region
  repository_id = var.container_build_config.artifact_repo_name
  description   = "Artifact registry repository for ${local.application_display_name}"
  format        = "DOCKER"
  labels        = local.common_labels
}

# Data source to reference the repository (whether newly created or existing)
data "google_artifact_registry_repository" "application_image" {
  count = local.enable_custom_build || local.enable_cicd_trigger ? 1 : 0

  project       = local.project.project_id
  location      = local.region
  repository_id = var.container_build_config.artifact_repo_name

  depends_on = [
    google_artifact_registry_repository.application_image
  ]
}
