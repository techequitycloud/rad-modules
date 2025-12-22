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
# Create config files
#########################################################################

# Resource for creating a Dockerfile from a template, with variables substituted
resource "local_file" "dockerfile" {
  count    = var.configure_development_environment ? 1 : 0
    filename = "${path.module}/scripts/bkup/dockerfile"
    content         = templatefile("${path.module}/scripts/bkup/Dockerfile.tpl", {
    BACKUP_SCRIPT   = "backup.sh"
  })
}

# Resource for creating a local Cloud Build configuration file from a template.
resource "local_file" "cloudbuild" {
  count    = var.configure_development_environment ? 1 : 0
    filename        = "${path.module}/scripts/bkup/cloudbuild.yaml"
    content         = templatefile("${path.module}/scripts/bkup/cloudbuild.yaml.tpl", {
    PROJECT_ID      = local.project.project_id
    IMAGE_REGION    = local.region
    IMAGE_NAME      = "backup"
    IMAGE_VERSION   = "${var.application_version}"
    DOCKERFILE      = "dockerfile"
    REPO_NAME       = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })
}

#########################################################################
# Build container image
#########################################################################

# Null resource to trigger local scripts for building and pushing the container image.
resource "null_resource" "build_and_push_backup_image" {
  count    = var.configure_development_environment ? 1 : 0
  triggers = {
    # always_run    = "${timestamp()}" # Trigger to always run on apply
  }
    
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/bkup"
    command     = "bash build-container.sh ${local.project.project_id} ${var.resource_creator_identity}"
  }

  # Dependencies for this resource.
  depends_on = [
    local_file.cloudbuild,
    local_file.dockerfile,
    google_artifact_registry_repository.application_image,
  ]
}
