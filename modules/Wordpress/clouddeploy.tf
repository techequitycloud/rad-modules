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

# Resource to create a local clouddeploy file from a template, with variables substituted
resource "local_file" "app_clouddeploy_backup" {
  count    = (var.configure_development_environment || var.configure_nonproduction_environment || var.configure_production_environment) && var.configure_backups ? 1 : 0
  filename = "${path.module}/scripts/cd/clouddeploy.yaml"
  content  = templatefile("${path.module}/scripts/cd/clouddeploy.yaml.tpl", {
    PROJECT_ID    = local.project.project_id
    APP_NAME      = "bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    IMAGE_REGION  = local.region
    IMAGE_NAME    = "backup"
    IMAGE_VERSION = "${var.application_version}"
    REPO_NAME     = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    PIPELINE_NAME = "pl-bkup-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    TARGET_NAME   = "tgt-bkup-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    APP_REGION    = local.region
    CREATOR_SA    = var.resource_creator_identity
  })

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local skaffold file from a template, with variables substituted
resource "local_file" "app_skaffold_backup" {
  count    = (var.configure_development_environment || var.configure_nonproduction_environment || var.configure_production_environment) && var.configure_backups ? 1 : 0
  filename = "${path.module}/scripts/cd/skaffold.yaml"
  content  = templatefile("${path.module}/scripts/cd/skaffold.yaml.tpl", {
    PROJECT_ID    = local.project.project_id
    APP_NAME      = "bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    IMAGE_REGION  = local.region
    IMAGE_NAME    = "backup"
    IMAGE_VERSION = "${var.application_version}"
    REPO_NAME     = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

#########################################################################
# Create pipelines
#########################################################################

# Resource to build the backup pipeline
resource "null_resource" "build_cloud_deploy_backup_pipeline" {
  count    = (var.configure_development_environment || var.configure_nonproduction_environment || var.configure_production_environment) && var.configure_backups ? 1 : 0
  # Trigger based on the hash of the setup-pipeline.sh script
  triggers = {
    script_hash = filesha256("${path.module}/scripts/cd/setup-pipeline.sh")
  }
  
  # Provisioner to execute a local script that builds the Cloud Deploy pipeline
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    working_dir = "${path.module}/scripts/cd"  # The directory where build scripts are located
    command = "bash setup-pipeline.sh \"${local.project.project_id}\" \"${var.resource_creator_identity}\""
  }

  # Dependencies to ensure resources are created in the correct order
  depends_on = [
    local_file.app_clouddeploy_backup,
    local_file.app_skaffold_backup,
    null_resource.build_and_push_backup_image,
    google_cloud_run_v2_job.backup_service,
    github_repository.project_private_repo,
  ]
}
