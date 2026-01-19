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
# Parse GitHub Repository Information
#########################################################################

locals {
  # Parse GitHub repository URL to extract owner and repo name
  # Example: https://github.com/username/repo -> username/repo
  github_repo_parts = var.enable_cicd && var.github_repository_url != "" ? (
    split("/", trimprefix(trimprefix(var.github_repository_url, "https://github.com/"), "http://github.com/"))
  ) : []

  github_owner = length(local.github_repo_parts) >= 2 ? local.github_repo_parts[0] : ""
  github_repo  = length(local.github_repo_parts) >= 2 ? trimsuffix(local.github_repo_parts[1], ".git") : ""

  # Construct the container image URL
  container_image_url = var.enable_cicd ? (
    "${local.region}-docker.pkg.dev/${local.project.project_id}/${google_artifact_registry_repository.container_repo[0].repository_id}/app"
  ) : ""

  # Determine the image to use (custom build or prebuilt)
  use_custom_image = var.container_image_source == "custom"
}

#########################################################################
# Cloud Build Trigger for GitHub Repository
#########################################################################

resource "google_cloudbuild_trigger" "github_trigger" {
  count       = var.enable_cicd && var.github_repository_url != "" && local.use_custom_image ? 1 : 0

  project     = local.project.project_id
  name        = "github-cicd-trigger-${local.random_id}"
  description = "Automated build and deploy trigger for ${var.github_repository_url}"

  # Trigger on push to specified branch
  github {
    owner = local.github_owner
    name  = local.github_repo

    push {
      branch = "^${var.build_branch}$"
    }
  }

  # Build configuration
  build {
    timeout = "${var.build_timeout}s"

    options {
      machine_type = var.cloudbuild_machine_type
      disk_size_gb = var.cloudbuild_disk_size_gb
      logging      = "CLOUD_LOGGING_ONLY"
    }

    # Build steps
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build",
        "-t", "${local.container_image_url}:$SHORT_SHA",
        "-t", "${local.container_image_url}:latest",
        "-f", var.dockerfile_path,
        "."
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "${local.container_image_url}:$SHORT_SHA"
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "${local.container_image_url}:latest"
      ]
    }

    # Tag images
    images = [
      "${local.container_image_url}:$SHORT_SHA",
      "${local.container_image_url}:latest"
    ]

    # Substitutions for build variables
    substitutions = {
      _DOCKERFILE_PATH = var.dockerfile_path
      _REGION          = local.region
      _PROJECT_ID      = local.project.project_id
      _REPO_NAME       = google_artifact_registry_repository.container_repo[0].repository_id
    }
  }

  # Use custom Cloud Build service account
  service_account = google_service_account.cloud_build_sa_admin.id

  depends_on = [
    google_artifact_registry_repository.container_repo,
    google_service_account.cloud_build_sa_admin,
    resource.time_sleep.wait_for_apis,
  ]
}

#########################################################################
# Local values for image references
#########################################################################

locals {
  # The actual container image to use (either custom built or prebuilt)
  final_container_image = var.enable_cicd && local.use_custom_image ? (
    "${local.container_image_url}:latest"
  ) : (
    var.container_image_source != "custom" ? var.container_image_source : "gcr.io/cloudrun/hello"
  )
}
