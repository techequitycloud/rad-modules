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
  description = "Deployment information"
  value       = module.webapp.deployment_info
}

output "cloud_sql_info" {
  description = "Cloud SQL instance information"
  value = {
    cloudsql_instance_ip = module.webapp.database_host
    cloud_sql_studio     = module.webapp.database_instance_name != null ? "https://console.cloud.google.com/sql/instances/${module.webapp.database_instance_name}/studio?project=${module.webapp.project_id}&supportedpurview=project,organizationId,folder" : ""
    database_name        = module.webapp.database_name
    database_user        = module.webapp.database_user
  }
}

output "private_storage_info" {
  description = "Private storage bucket information"
  value = {
    gcs_private_data_bucket = try(module.webapp.storage_buckets["data"].name, length(keys(module.webapp.storage_buckets)) > 0 ? values(module.webapp.storage_buckets)[0].name : "")
  }
}

output "nfs_server_info" {
  description = "NFS server information"
  value = {
    nfs_server_ip = module.webapp.nfs_server_ip
  }
}

output "application_info" {
  description = "Application URL and related links"
  value = {
    application_url      = module.webapp.service_url
    cloud_secret_manager = "https://console.cloud.google.com/security/secret-manager?inv=1&invt=AbioWw&orgonly=true&project=${module.webapp.project_id}&supportedpurview=organizationId"
  }
}

output "service_info" {
  description = "Service URL and metrics links"
  value = {
    service_url          = module.webapp.service_url != null ? "https://console.cloud.google.com/run/detail/${module.webapp.service_location}/${module.webapp.service_name}/metrics?orgonly=true&project=${module.webapp.project_id}&supportedpurview=organizationId" : ""
    cloud_secret_manager = "https://console.cloud.google.com/security/secret-manager?inv=1&invt=AbioWw&orgonly=true&project=${module.webapp.project_id}&supportedpurview=organizationId"
  }
}

output "network_info" {
  description = "Information about the VPC network"
  value = {
    network_exists  = module.webapp.network_exists
    regions         = module.webapp.regions
    network_name    = module.webapp.network_name
  }
}
