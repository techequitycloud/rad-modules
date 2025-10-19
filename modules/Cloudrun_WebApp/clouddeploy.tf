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
# Configure cloud deploy pipeline
#########################################################################

# Resource to configure cloud deploy pipeline
resource "null_resource" "build_cloud_deploy_app_pipeline" {
  count = var.configure_continuous_deployment && var.configure_development_environment ? 1 : 0

  triggers = {
    project_id    = local.project.project_id
    zone          = data.google_compute_zones.available_zones.names[0]
    pipeline_name = "app${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    target_name   = "app${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    app_name      = "${var.application_name}"
    app_prefix    = "app${var.tenant_deployment_id}${local.random_id}"
    app_region    = local.region
    creator_sa    = "${var.resource_creator_identity}"
    script_hash   = filesha256("${path.module}/scripts/cd/setup-pipeline.sh")
    # always_run    = "${timestamp()}"
  }

  # Provisioner to execute a local script that builds and pushes the container image
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/cd/app"  # The directory where build scripts are located
    command = "bash ../setup-pipeline.sh \"${local.project.project_id}\" \"${local.region}\" \"${var.resource_creator_identity}\""
  }

  # Provisioner to execute a local script that deletes the database
  provisioner "local-exec" {
    when    = destroy
    working_dir = "${path.module}/scripts/cd/app" # The directory where build scripts are located
    command = "bash ../delete-pipeline.sh \"$PROJECT_ID\" \"$PIPELINE_NAME\" \"$TARGET_NAME\" \"$APP_NAME\" \"$APP_PREFIX\" \"$APP_REGION\" \"$CREATOR_SA\""

    # Environment variables available to the command execution
    environment = {
      PROJECT_ID    = self.triggers.project_id
      ZONE          = self.triggers.zone
      PIPELINE_NAME = self.triggers.pipeline_name
      TARGET_NAME   = self.triggers.target_name
      APP_NAME      = self.triggers.app_name
      APP_PREFIX    = self.triggers.app_prefix
      APP_REGION    = self.triggers.app_region
      CREATOR_SA    = self.triggers.creator_sa
    }
  }

  # Dependencies to ensure resources are created in the correct order
  depends_on = [
    local_file.clouddeploy_dockerfile,
    local_file.clouddeploy_app_deploy_dev,
    local_file.clouddeploy_app_deploy_qa,
    local_file.clouddeploy_app_deploy_prod,
    local_file.clouddeploy_app_cloudbuild,
    local_file.clouddeploy_app_skaffold,
    null_resource.build_and_push_application_image,
    google_cloud_run_v2_service.dev_app_service,
  ]
}