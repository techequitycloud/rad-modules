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
# Service Information Outputs
#########################################################################

output "service_name" {
  description = "Name of the Cloud Run service"
  value = local.configure_environment && length(google_cloud_run_v2_service.app_service) > 0 ? google_cloud_run_v2_service.app_service[0].name : null
}

output "service_url" {
  description = "URL of the Cloud Run service"
  value = local.configure_environment && length(google_cloud_run_v2_service.app_service) > 0 ? google_cloud_run_v2_service.app_service[0].uri : null
}

output "service_location" {
  description = "Location of the Cloud Run service"
  value = local.configure_environment && length(google_cloud_run_v2_service.app_service) > 0 ? google_cloud_run_v2_service.app_service[0].location : null
}

#########################################################################
# Database Information Outputs
#########################################################################

output "database_instance_name" {
  description = "Name of the Cloud SQL instance"
  value       = local.sql_server_exists ? local.db_instance_name : null
}

output "database_name" {
  description = "Name of the application database"
  value       = local.sql_server_exists ? local.database_name_full : null
}

output "database_user" {
  description = "Name of the application database user"
  value       = local.sql_server_exists ? local.database_user_full : null
}

output "database_password_secret" {
  description = "Secret Manager secret name for database password"
  value       = local.sql_server_exists ? local.db_password_secret_name : null
}

output "database_host" {
  description = "Database host IP address"
  value       = local.sql_server_exists ? local.db_internal_ip : null
  sensitive   = true
}

output "database_port" {
  description = "Database port"
  value       = local.database_port
}

#########################################################################
# Storage Information Outputs
#########################################################################

output "storage_buckets" {
  description = "Created storage buckets"
  value = local.create_cloud_storage ? {
    for key, bucket in google_storage_bucket.buckets :
    key => {
      name     = bucket.name
      url      = bucket.url
      location = bucket.location
    }
  } : {}
}

#########################################################################
# Network Information Outputs
#########################################################################

output "network_name" {
  description = "VPC network name"
  value       = local.network_name
}

output "network_exists" {
  description = "Whether the VPC network exists"
  value       = local.network_exists
}

output "regions" {
  description = "Available regions in the VPC"
  value       = local.available_regions
}

#########################################################################
# NFS Information Outputs
#########################################################################

output "nfs_server_ip" {
  description = "NFS server internal IP"
  value       = local.nfs_enabled && local.nfs_server_exists ? local.nfs_internal_ip : null
  sensitive   = true
}

output "nfs_mount_path" {
  description = "NFS mount path in containers"
  value       = local.nfs_enabled ? local.nfs_mount_path : null
}

output "nfs_share_path" {
  description = "NFS share path on server"
  value       = local.nfs_enabled && local.nfs_server_exists ? local.nfs_share_path : null
}

#########################################################################
# Container Information Outputs
#########################################################################

output "container_image" {
  description = "Container image used for the service"
  value       = local.container_image
}

output "container_registry" {
  description = "Artifact Registry repository name"
  value       = local.enable_custom_build ? data.google_artifact_registry_repository.application_image[0].name : null
}

#########################################################################
# Monitoring Information Outputs
#########################################################################

output "monitoring_enabled" {
  description = "Whether monitoring is configured"
  value       = local.configure_monitoring
}

output "monitoring_notification_channels" {
  description = "Monitoring notification channel names"
  value       = local.configure_monitoring && length(local.trusted_users) > 0 ? google_monitoring_notification_channel.email[*].name : []
}

output "uptime_check_names" {
  description = "Uptime check configuration names"
  value       = local.uptime_check_enabled && local.configure_environment ? google_monitoring_uptime_check_config.https[*].name : []
}

#########################################################################
# Deployment Information Outputs
#########################################################################

output "deployment_id" {
  description = "Unique deployment identifier"
  value       = local.deployment_id
}

output "tenant_id" {
  description = "Tenant identifier"
  value       = local.tenant_id
}

output "resource_prefix" {
  description = "Resource naming prefix"
  value       = local.resource_prefix
}

output "project_id" {
  description = "GCP project ID"
  value       = local.project.project_id
}

output "project_number" {
  description = "GCP project number"
  value       = local.project.project_number
}

#########################################################################
# Job Information Outputs
#########################################################################

output "initialization_jobs" {
  description = "Created initialization job names"
  value       = { for job_name, job in google_cloud_run_v2_job.initialization_jobs : job_name => job.name }
}

output "nfs_setup_job" {
  description = "NFS setup job name"
  value       = local.nfs_enabled && local.nfs_server_exists ? google_cloud_run_v2_job.nfs_setup_job[0].name : null
}

#########################################################################
# Summary Output
#########################################################################

output "deployment_summary" {
  description = "Summary of the deployment"
  value = {
    application_name    = local.application_display_name
    service_url         = local.configure_environment && length(google_cloud_run_v2_service.app_service) > 0 ? google_cloud_run_v2_service.app_service[0].uri : null
    database_type       = local.database_type
    database_name       = local.sql_server_exists ? local.database_name_full : null
    storage_buckets     = local.create_cloud_storage ? keys(local.storage_buckets) : []
    nfs_enabled         = local.nfs_enabled
    monitoring_enabled  = local.configure_monitoring
    deployment_region   = local.region
    container_image     = local.container_image
  }
}

#########################################################################
# CI/CD Configuration Outputs
#########################################################################

output "cicd_enabled" {
  description = "Whether CI/CD pipeline is enabled"
  value       = local.enable_cicd_trigger
}

output "github_repository_url" {
  description = "GitHub repository URL connected for CI/CD"
  value       = local.enable_cicd_trigger ? local.github_repo_url : null
}

output "github_repository_owner" {
  description = "GitHub repository owner/organization"
  value       = local.enable_cicd_trigger ? local.github_repo_owner : null
}

output "github_repository_name" {
  description = "GitHub repository name"
  value       = local.enable_cicd_trigger ? local.github_repo_name : null
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository for container images"
  value = local.enable_custom_build || local.enable_cicd_trigger ? {
    name     = data.google_artifact_registry_repository.application_image[0].name
    location = data.google_artifact_registry_repository.application_image[0].location
    url      = "${data.google_artifact_registry_repository.application_image[0].location}-docker.pkg.dev/${local.project.project_id}/${data.google_artifact_registry_repository.application_image[0].repository_id}"
  } : null
}

output "cloudbuild_trigger_name" {
  description = "Cloud Build trigger name for CI/CD"
  value       = local.enable_cicd_trigger ? google_cloudbuild_trigger.cicd_trigger[0].name : null
}

output "cloudbuild_trigger_id" {
  description = "Cloud Build trigger ID for CI/CD"
  value       = local.enable_cicd_trigger ? google_cloudbuild_trigger.cicd_trigger[0].trigger_id : null
}

output "cicd_configuration" {
  description = "Complete CI/CD configuration details"
  value = local.enable_cicd_trigger ? {
    trigger_name        = google_cloudbuild_trigger.cicd_trigger[0].name
    trigger_id          = google_cloudbuild_trigger.cicd_trigger[0].trigger_id
    github_repo_url     = local.github_repo_url
    github_repo_owner   = local.github_repo_owner
    github_repo_name    = local.github_repo_name
    branch_pattern      = local.cicd_trigger_config.branch_pattern
    artifact_registry   = "${data.google_artifact_registry_repository.application_image[0].location}-docker.pkg.dev/${local.project.project_id}/${data.google_artifact_registry_repository.application_image[0].repository_id}"
    container_image_url = local.container_image
    cloudbuild_sa       = "${local.cloudbuild_sa}@${local.project.project_id}.iam.gserviceaccount.com"
  } : null
}
