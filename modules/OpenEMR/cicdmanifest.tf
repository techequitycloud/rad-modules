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
# Create CI/CD manifests
#########################################################################

# Generate clouddeploy.yaml from template
resource "local_file" "clouddeploy_yaml" {
  filename = "${path.module}/scripts/cd/clouddeploy.yaml"
  content = templatefile("${path.module}/scripts/cd/clouddeploy.yaml.tpl", {
    PIPELINE_NAME = "app-pipeline"
    APP_NAME      = var.application_name
    TARGET_NAME   = "app-target"
    PROJECT_ID    = local.project.project_id
    APP_REGION    = local.region
    CREATOR_SA    = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
  })
}

# Generate skaffold.yaml from template
resource "local_file" "skaffold_yaml" {
  filename = "${path.module}/scripts/cd/skaffold.yaml"
  content = templatefile("${path.module}/scripts/cd/skaffold.yaml.tpl", {
    APP_NAME = var.application_name
  })
}

# Generate application deploy.yaml from template
resource "local_file" "app_deploy_yaml" {
  filename = "${path.module}/scripts/cd/app/deploy.yaml"
  content = templatefile("${path.module}/scripts/cd/app/deploy.yaml.tpl", {
    SERVICE_NAME   = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_REGION     = local.region
    PROJECT_ID     = local.project.project_id
    SERVICE_ACCOUNT= "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
    IMAGE          = "app"
    DB_IP          = local.db_internal_ip
    DB_USER        = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
    DB_PASS_SECRET = "${local.db_instance_name}-${var.application_database_name}-password-${var.tenant_deployment_id}-${local.random_id}"
    DB_NAME        = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
    NFS_IP         = local.nfs_internal_ip
  })
}

# Generate backup deploy.yaml from template
resource "local_file" "backup_deploy_yaml" {
  filename = "${path.module}/scripts/cd/backup/deploy.yaml"
  content = templatefile("${path.module}/scripts/cd/backup/deploy.yaml.tpl", {
    SERVICE_NAME   = "app${var.application_name}-backup${var.tenant_deployment_id}${local.random_id}"
    APP_REGION     = local.region
    PROJECT_ID     = local.project.project_id
    SERVICE_ACCOUNT= "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
    IMAGE          = "backup"
    DB_IP          = local.db_internal_ip
    DB_USER        = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
    DB_PASS_SECRET = "${local.db_instance_name}-${var.application_database_name}-password-${var.tenant_deployment_id}-${local.random_id}"
    DB_NAME        = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
    GCS_BUCKET     = local.backup_bucket_name
    NFS_IP         = local.nfs_internal_ip
  })
}
