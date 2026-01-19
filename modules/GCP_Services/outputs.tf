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

output "deployment_id" {
  description = "Deployment ID" 
  value       = var.deployment_id 
}

output "primary_deployment_region" {
  description = "the primary Google Cloud region for resource deployment."
  value       = local.region
}

output "host_project_id" {
  description = "The project ID" 
  value = var.existing_project_id
}

output "nfs_server_ip" {
  value       = var.create_network_filesystem ? google_compute_address.static_internal_ip[0].address : null # Reference the static IP address
  description = "The static internal IP address for the NFS server."
}

output "mysql_instance_ip" {
  value       = var.create_mysql ? google_sql_database_instance.mysql_instance[0].private_ip_address : null # Reference the instance IP from the module
  description = "The IP address of the Cloud SQL database instance."
}

output "postgres_instance_ip" {
  value       = var.create_postgres ? google_sql_database_instance.postgres_instance[0].private_ip_address : null
  description = "The IP address of the PostgreSQL Cloud SQL database instance."
}

output "postgres_instance_connection_name" {
  value       = var.create_postgres ? google_sql_database_instance.postgres_instance[0].connection_name : null
  description = "The connection name of the PostgreSQL instance for Cloud SQL Proxy."
}

output "mysql_instance_connection_name" {
  value       = var.create_mysql ? google_sql_database_instance.mysql_instance[0].connection_name : null
  description = "The connection name of the MySQL instance for Cloud SQL Proxy."
}

#########################################################################
# Redis Outputs
#########################################################################

output "redis_host" {
  value       = var.create_redis ? google_redis_instance.cache[0].host : null
  description = "The IP address of the Redis instance."
}

output "redis_port" {
  value       = var.create_redis ? google_redis_instance.cache[0].port : null
  description = "The port number of the Redis instance."
}

output "redis_connection_string" {
  value       = var.create_redis ? "${google_redis_instance.cache[0].host}:${google_redis_instance.cache[0].port}" : null
  description = "The Redis connection string (host:port)."
}

#########################################################################
# Service Account Outputs
#########################################################################

output "cloudrun_service_account" {
  value       = local.cloudrun_sa_email
  description = "The email of the Cloud Run service account."
}

output "cloudbuild_service_account" {
  value       = local.cloudbuild_sa_email
  description = "The email of the Cloud Build service account."
}

output "project_service_account" {
  value       = local.project_sa_email
  description = "The email of the project service account."
}

#########################################################################
# Network Outputs
#########################################################################

output "vpc_network_name" {
  value       = google_compute_network.vpc_network.name
  description = "The name of the VPC network."
}

output "vpc_network_id" {
  value       = google_compute_network.vpc_network.id
  description = "The ID of the VPC network."
}

#########################################################################
# CI/CD and Deployment Outputs
#########################################################################

output "cicd_enabled" {
  value       = var.enable_cicd
  description = "Whether CI/CD pipeline is enabled."
}

output "artifact_registry_repository_id" {
  value       = var.enable_cicd ? google_artifact_registry_repository.container_repo[0].id : null
  description = "The ID of the Artifact Registry repository."
}

output "artifact_registry_repository_name" {
  value       = var.enable_cicd ? google_artifact_registry_repository.container_repo[0].name : null
  description = "The name of the Artifact Registry repository."
}

output "artifact_registry_repository_url" {
  value       = var.enable_cicd ? "${local.region}-docker.pkg.dev/${local.project.project_id}/${google_artifact_registry_repository.container_repo[0].repository_id}" : null
  description = "The base URL of the Artifact Registry repository for pushing/pulling images."
}

output "container_image_url" {
  value       = var.enable_cicd ? local.container_image_url : null
  description = "The full container image URL (without tag) in Artifact Registry."
}

output "container_image_latest" {
  value       = var.enable_cicd ? "${local.container_image_url}:latest" : null
  description = "The container image URL with 'latest' tag."
}

output "final_container_image" {
  value       = var.enable_cicd ? local.final_container_image : "gcr.io/cloudrun/hello"
  description = "The actual container image to use for deployments (custom built or prebuilt)."
}

output "github_repository_url" {
  value       = var.enable_cicd ? var.github_repository_url : null
  description = "The GitHub repository URL configured for CI/CD."
}

output "github_repository_owner" {
  value       = var.enable_cicd ? local.github_owner : null
  description = "The GitHub repository owner extracted from the repository URL."
}

output "github_repository_name" {
  value       = var.enable_cicd ? local.github_repo : null
  description = "The GitHub repository name extracted from the repository URL."
}

output "build_branch" {
  value       = var.enable_cicd ? var.build_branch : null
  description = "The GitHub branch configured to trigger builds."
}

output "cloudbuild_trigger_id" {
  value       = var.enable_cicd && local.use_custom_image && length(google_cloudbuild_trigger.github_trigger) > 0 ? google_cloudbuild_trigger.github_trigger[0].id : null
  description = "The ID of the Cloud Build trigger."
}

output "cloudbuild_trigger_name" {
  value       = var.enable_cicd && local.use_custom_image && length(google_cloudbuild_trigger.github_trigger) > 0 ? google_cloudbuild_trigger.github_trigger[0].name : null
  description = "The name of the Cloud Build trigger."
}

output "github_token_secret_id" {
  value       = var.enable_cicd && var.github_token != "" ? google_secret_manager_secret.github_token[0].secret_id : null
  description = "The Secret Manager secret ID storing the GitHub token."
}

output "dockerfile_path" {
  value       = var.enable_cicd ? var.dockerfile_path : null
  description = "The path to the Dockerfile in the repository."
}

output "container_image_source" {
  value       = var.container_image_source
  description = "The container image source configuration (custom or prebuilt URL)."
}

#########################################################################
# Web Application Configuration Summary
#########################################################################

output "web_app_configuration" {
  value = var.enable_cicd ? {
    cicd_enabled          = true
    github_repository     = var.github_repository_url
    github_owner          = local.github_owner
    github_repo           = local.github_repo
    build_branch          = var.build_branch
    dockerfile_path       = var.dockerfile_path
    artifact_registry_url = "${local.region}-docker.pkg.dev/${local.project.project_id}/${google_artifact_registry_repository.container_repo[0].repository_id}"
    container_image       = local.final_container_image
    build_trigger_id      = local.use_custom_image && length(google_cloudbuild_trigger.github_trigger) > 0 ? google_cloudbuild_trigger.github_trigger[0].id : "N/A - Using prebuilt image"
    build_timeout         = var.build_timeout
    project_id            = local.project.project_id
    region                = local.region
  } : {
    cicd_enabled = false
    message      = "CI/CD pipeline is not enabled. Set enable_cicd=true to configure automated builds."
  }
  description = "Complete web application and CI/CD configuration summary."
}
