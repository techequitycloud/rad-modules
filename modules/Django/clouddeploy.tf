# Copyright 2024 Tech Equity Ltd
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
# Cloud Deploy
#########################################################################


resource "null_resource" "deploy_application_pipeline" {
  count = var.configure_continuous_deployment && var.configure_environment ? 1 : 0
  triggers = {
    # always_run    = "${timestamp()}" # Trigger to always run on apply
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    working_dir = "${path.module}/scripts/cd"
    command     = "bash setup-pipeline.sh ${local.project.project_id} ${local.nfs_internal_ip} ${data.google_compute_zones.available_zones.names[0]} app${var.application_name}-${var.tenant_deployment_id}-${local.random_id} app${var.application_name}-${var.tenant_deployment_id}-${local.random_id} ${local.region}"
  }

  depends_on = [
    null_resource.init_git_repo,
    local_file.clouddeploy_app_skaffold,
    local_file.clouddeploy_app_deploy,
    local_file.clouddeploy_app_cloudbuild,
    local_file.app_clouddeploy,
    google_cloud_run_v2_job.backup_service,
    google_cloud_run_v2_service.app_service,
    google_artifact_registry_repository.application_image
  ]
}

resource "null_resource" "deploy_backup_pipeline" {
  count = var.configure_continuous_deployment && var.configure_environment ? 1 : 0
  triggers = {
    # always_run    = "${timestamp()}" # Trigger to always run on apply
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    working_dir = "${path.module}/scripts/cd"
    command     = "bash setup-pipeline.sh ${local.project.project_id} ${local.nfs_internal_ip} ${data.google_compute_zones.available_zones.names[0]} bkup${var.application_name}-${var.tenant_deployment_id}-${local.random_id} bkup${var.application_name}-${var.tenant_deployment_id}-${local.random_id} ${local.region}"
  }

  depends_on = [
    null_resource.init_git_repo,
    local_file.clouddeploy_backup_skaffold,
    local_file.clouddeploy_backup_deploy,
    local_file.clouddeploy_backup_cloudbuild,
    local_file.backup_clouddeploy,
    google_cloud_run_v2_job.backup_service,
    google_cloud_run_v2_service.app_service,
    google_artifact_registry_repository.application_image
  ]
}

resource "null_resource" "delete_application_pipeline" {
  triggers = {
    project_id      = local.project.project_id
    nfs_ip          = local.nfs_internal_ip
    nfs_zone        = data.google_compute_zones.available_zones.names[0]
    pipeline_name   = "app${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    target_name     = "app${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    app_name        = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    app_prefix      = "app"
    app_region      = local.region
    service_account = var.resource_creator_identity
  }

  provisioner "local-exec" {
    when       = destroy
    interpreter = ["/bin/bash", "-c"]
    working_dir = "${path.module}/scripts/cd"
    command     = "bash delete-pipeline.sh ${self.triggers.project_id} ${self.triggers.nfs_ip} ${self.triggers.nfs_zone} ${self.triggers.pipeline_name} ${self.triggers.target_name} ${self.triggers.app_name} ${self.triggers.app_prefix} ${self.triggers.app_region} ${self.triggers.service_account}"
  }
}

resource "null_resource" "delete_backup_pipeline" {
  triggers = {
    project_id      = local.project.project_id
    nfs_ip          = local.nfs_internal_ip
    nfs_zone        = data.google_compute_zones.available_zones.names[0]
    pipeline_name   = "bkup${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    target_name     = "bkup${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    app_name        = "bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    app_prefix      = "bkup"
    app_region      = local.region
    service_account = var.resource_creator_identity
  }

  provisioner "local-exec" {
    when       = destroy
    interpreter = ["/bin/bash", "-c"]
    working_dir = "${path.module}/scripts/cd"
    command     = "bash delete-pipeline.sh ${self.triggers.project_id} ${self.triggers.nfs_ip} ${self.triggers.nfs_zone} ${self.triggers.pipeline_name} ${self.triggers.target_name} ${self.triggers.app_name} ${self.triggers.app_prefix} ${self.triggers.app_region} ${self.triggers.service_account}"
  }
}

resource "null_resource" "delete_git_repo" {
  triggers = {
    git_repo      = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    git_org       = var.application_git_organization
    github_token  = var.application_git_token
  }

  provisioner "local-exec" {
    when       = destroy
    interpreter = ["/bin/bash", "-c"]
    working_dir = "${path.module}/scripts/ci"
    command     = "bash delete_git_repo.sh"

    environment = {
      GIT_REPO      = self.triggers.git_repo
      GIT_ORG       = self.triggers.git_org
      GITHUB_TOKEN  = self.triggers.github_token
    }
  }
}
