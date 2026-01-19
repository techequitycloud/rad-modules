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

# Resource for creating a Google Artifact Registry repository to store application images
# Created when either custom build is enabled OR CI/CD trigger is enabled
# Repository name is scoped to tenant_id and deployment_id for complete deployment isolation
# Note: If the repository already exists, Terraform will error. In that case, import it:
#   terraform import 'google_artifact_registry_repository.application_image[0]' projects/{project}/locations/{location}/repositories/{repo_id}
resource "google_artifact_registry_repository" "application_image" {
  count = local.enable_custom_build || local.enable_cicd_trigger ? 1 : 0

  project       = local.project.project_id
  location      = local.region
  repository_id = local.artifact_repo_id
  description   = "Artifact registry repository for ${local.application_display_name} (tenant: ${local.tenant_id}, deployment: ${local.deployment_id})"
  format        = "DOCKER"
  labels        = local.common_labels

  # Prevent accidental deletion of the repository
  lifecycle {
    prevent_destroy = false
  }
}

# Data source to reference the repository (whether newly created or existing)
data "google_artifact_registry_repository" "application_image" {
  count = local.enable_custom_build || local.enable_cicd_trigger ? 1 : 0

  project       = local.project.project_id
  location      = local.region
  repository_id = local.artifact_repo_id

  depends_on = [
    google_artifact_registry_repository.application_image
  ]
}
