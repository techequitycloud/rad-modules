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
    APP_SHA      = "${var.application_sha}"
  })

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
  triggers = {
    script_hash = filesha256("${path.module}/scripts/app/build-container.sh")
    # always_run = "${timestamp()}" # Trigger to always run on apply
  }
  
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/app"  # The directory where build scripts are located
    command = "bash build-container.sh \"${local.project.project_id}\" \"${var.resource_creator_identity}\""
  }

  # Dependencies to ensure resources are created in the correct order
  depends_on = [
    null_resource.build_and_push_backup_image,
    google_artifact_registry_repository.application_image,
    github_repository.project_private_repo,
    local_file.app_dockerfile,
    local_file.app_cloudbuild,
    local_file.dev_autoscale_horizontal,
    local_file.dev_backend_config,
    local_file.dev_frontend_config,
    local_file.dev_base_kustomization,
    local_file.dev_service_cluster,
    local_file.dev_ingress_app,
    local_file.dev_overlay_kustomization,
    local_file.dev_managedcert_app,
    local_file.dev_deployment_app,
    local_file.dev_cloudbuild,
    data.local_file.dev_docker_entrypoint,
    data.local_file.dev_wp_config_docker,
    local_file.dev_dockerfile,
    local_file.dev_skaffold,
    local_file.qa_autoscale_horizontal,
    local_file.qa_backend_config,
    local_file.qa_frontend_config,
    local_file.qa_base_kustomization,
    local_file.qa_service_cluster,
    local_file.qa_ingress_app,
    local_file.qa_overlay_kustomization,
    local_file.qa_managedcert_app,
    local_file.qa_deployment_app,
    local_file.qa_cloudbuild,
    data.local_file.qa_docker_entrypoint,
    data.local_file.qa_wp_config_docker,
    local_file.qa_dockerfile,
    local_file.qa_skaffold,
    local_file.prod_autoscale_horizontal,
    local_file.prod_backend_config,
    local_file.prod_frontend_config,
    local_file.prod_base_kustomization,
    local_file.prod_service_cluster,
    local_file.prod_ingress_app,
    local_file.prod_overlay_kustomization,
    local_file.prod_managedcert_app,
    local_file.prod_deployment_app,
    local_file.prod_cloudbuild,
    data.local_file.prod_docker_entrypoint,
    data.local_file.prod_wp_config_docker,
    local_file.prod_dockerfile,
    local_file.prod_skaffold,
  ]
}