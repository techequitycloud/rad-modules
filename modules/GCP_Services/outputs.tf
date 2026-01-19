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
# Artifact Registry Outputs
#########################################################################

output "artifact_registry_repository_id" {
  value       = var.create_artifact_registry ? google_artifact_registry_repository.main[0].id : null
  description = "The ID of the Artifact Registry repository."
}

output "artifact_registry_repository_url" {
  value       = var.create_artifact_registry ? "${google_artifact_registry_repository.main[0].location}-docker.pkg.dev/${local.project.project_id}/${google_artifact_registry_repository.main[0].repository_id}" : null
  description = "The URL for pushing/pulling images to/from Artifact Registry."
}

#########################################################################
# Cloud Storage Outputs
#########################################################################

output "storage_bucket_name" {
  value       = var.create_storage_bucket ? google_storage_bucket.app_storage[0].name : null
  description = "The name of the Cloud Storage bucket."
}

output "storage_bucket_url" {
  value       = var.create_storage_bucket ? google_storage_bucket.app_storage[0].url : null
  description = "The URL of the Cloud Storage bucket."
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
# VPC Connector Outputs
#########################################################################

output "vpc_connector_id" {
  value       = var.create_vpc_connector ? google_vpc_access_connector.serverless_connector[0].id : null
  description = "The ID of the VPC Access Connector."
}

output "vpc_connector_name" {
  value       = var.create_vpc_connector ? google_vpc_access_connector.serverless_connector[0].name : null
  description = "The name of the VPC Access Connector for use in Cloud Run services."
}

#########################################################################
# Pub/Sub Outputs
#########################################################################

output "pubsub_topic_name" {
  value       = var.create_pubsub_topic ? google_pubsub_topic.events[0].name : null
  description = "The name of the Pub/Sub topic."
}

output "pubsub_topic_id" {
  value       = var.create_pubsub_topic ? google_pubsub_topic.events[0].id : null
  description = "The ID of the Pub/Sub topic."
}

output "pubsub_subscription_name" {
  value       = var.create_pubsub_topic ? google_pubsub_subscription.events_subscription[0].name : null
  description = "The name of the Pub/Sub subscription."
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
