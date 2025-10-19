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

# Resource for creating a Dockerfile from a template, which will be used to build the application's container image.
resource "local_file" "app_dockerfile" {
  count          = (var.configure_development_environment || var.configure_nonproduction_environment || var.configure_production_environment) ? 1 : 0
  filename       = "${path.module}/scripts/app/Dockerfile"
  content        = templatefile("${path.module}/scripts/app/Dockerfile.tpl", {
    APP_VERSION  = "${var.application_version}"
  })

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local cloudbuild file from a template, with variables substituted
resource "local_file" "app_cloudbuild" {
  count    = (var.configure_development_environment || var.configure_nonproduction_environment || var.configure_production_environment) ? 1 : 0
  filename = "${path.module}/scripts/app/cloudbuild.yaml"
  content  = templatefile("${path.module}/scripts/app/cloudbuild.yaml.tpl", {
    PROJECT_ID    = local.project.project_id
    APP_NAME      = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    IMAGE_REGION  = local.region
    IMAGE_NAME    = var.application_name
    IMAGE_VERSION = "${var.application_version}"
    REPO_NAME     = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

#########################################################################
# Build container image
#########################################################################

# Resource to build the container image locally and push it to the container registry
resource "null_resource" "build_and_push_application_image" {
  count    = (var.configure_development_environment || var.configure_nonproduction_environment || var.configure_production_environment) ? 1 : 0
  # Trigger based on the hash of the build-container.sh script
  triggers = {
    script_hash = filesha256("${path.module}/scripts/app/build-container.sh")
    # always_run = "${timestamp()}" # Trigger to always run on apply
  }
  
  # Provisioner to execute a local script that builds and pushes the container image
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/app"  # The directory where build scripts are located
    command = "bash build-container.sh \"${local.project.project_id}\" \"${var.resource_creator_identity}\""
  }

  # Dependencies to ensure resources are created in the correct order
  depends_on = [
    local_file.app_dockerfile,
    local_file.app_cloudbuild,
    null_resource.build_and_push_backup_image,
    google_artifact_registry_repository.application_image,
    github_repository.project_private_repo,
  ]
}


