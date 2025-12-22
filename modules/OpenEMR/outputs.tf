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

output "deployment_info" {
  value = {
    deployment_id  = var.deployment_id
    region         = local.region
    project_id = local.project.project_id
  }
}

output "cloud_sql_info" {
  value = {
    cloudsql_instance_ip = local.sql_server_exists ? local.db_internal_ip : "" 
    cloud_sql_studio = length(local.db_instance_name) > 0 ? "https://console.cloud.google.com/sql/instances/${local.db_instance_name}/studio?project=${local.project.project_id}&supportedpurview=project,organizationId,folder" : ""
    development_database_name =  var.configure_development_environment ? "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev" : ""
    development_database_user = var.configure_development_environment ? "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev" : ""
  }
}

output "private_storage_info" {
  value = {
    gcs_private_backup_bucket  = var.create_cloud_storage ? local.backup_bucket_name : ""
    gcs_private_data_bucket = var.create_cloud_storage ? local.data_bucket_name : "" 
    gcs_private_restore_bucket = var.create_cloud_storage ? local.restore_bucket_name : ""
  }
}

output "nfs_server_info" {
  value = {
    nfs_server_ip = local.nfs_server_exists ? local.nfs_internal_ip : "" 
  }
}

output "application_info" {
  value = {
    application_dev_url  = var.configure_development_environment ? "https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev-${local.project_number}.${local.region}.run.app" : ""
    cloud_secret_manager = var.configure_development_environment ? "https://console.cloud.google.com/security/secret-manager?inv=1&invt=AbioWw&orgonly=true&project=${local.project.project_id}&supportedpurview=organizationId" : ""
    cloud_scheduler      = var.configure_backups ? "https://console.cloud.google.com/cloudscheduler?inv=1&invt=AbioeA&orgonly=true&project=${local.project.project_id}&supportedpurview=organizationId" : ""
  }
}

output "service_info" {
  value = {
    service_dev_url  = var.configure_development_environment ? "https://console.cloud.google.com/run/detail/${local.region}/app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev/metrics?orgonly=true&project=${local.project.project_id}&supportedpurview=organizationId" : ""
    cloud_secret_manager = var.configure_development_environment ? "https://console.cloud.google.com/security/secret-manager?inv=1&invt=AbioWw&orgonly=true&project=${local.project.project_id}&supportedpurview=organizationId" : ""
    cloud_scheduler = var.configure_backups ? "https://console.cloud.google.com/cloudscheduler?project=${local.project.project_id}&supportedpurview=project,organizationId,folder" : ""
  }
}

