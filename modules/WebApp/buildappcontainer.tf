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
# Create Dockerfile (if content provided)
#########################################################################

resource "local_file" "app_dockerfile" {
  count = local.enable_custom_build && var.container_build_config.dockerfile_content != null ? 1 : 0

  filename = "${path.module}/scripts/app/${var.container_build_config.dockerfile_path}"
  content  = var.container_build_config.dockerfile_content
}

#########################################################################
# Create Cloud Build configuration
#########################################################################

resource "local_file" "app_cloudbuild" {
  count = local.enable_custom_build ? 1 : 0

  filename = "${path.module}/scripts/app/cloudbuild.yaml"
  content = templatefile("${path.module}/scripts/app/cloudbuild.yaml.tpl", {
    PROJECT_ID    = local.project.project_id
    APP_NAME      = local.service_name
    IMAGE_REGION  = local.region
    IMAGE_NAME    = local.application_name
    IMAGE_VERSION = local.application_version
    REPO_NAME     = var.container_build_config.artifact_repo_name
    DOCKERFILE    = var.container_build_config.dockerfile_path
    CONTEXT_PATH  = var.container_build_config.context_path
    BUILD_ARGS    = var.container_build_config.build_args
  })
}

#########################################################################
# Build and push container image
#########################################################################

resource "null_resource" "build_and_push_application_image" {
  count = local.enable_custom_build ? 1 : 0

  # Trigger rebuild on changes
  triggers = {
    script_hash     = fileexists("${path.module}/scripts/app/build-container.sh") ? filesha256("${path.module}/scripts/app/build-container.sh") : timestamp()
    dockerfile_hash = var.container_build_config.dockerfile_content != null ? sha256(var.container_build_config.dockerfile_content) : timestamp()
    repository_id   = google_artifact_registry_repository.application_image[0].repository_id
    image_tag       = local.application_version
    build_args      = sha256(jsonencode(var.container_build_config.build_args))
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/app"
    command     = "bash build-container.sh \"${local.project.project_id}\" \"${local.impersonation_service_account}\""
  }

  depends_on = [
    local_file.app_dockerfile,
    local_file.app_cloudbuild,
    google_artifact_registry_repository.application_image,
  ]
}
