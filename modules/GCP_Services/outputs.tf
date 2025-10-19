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

output "gke_cluster" {
  value       = var.create_google_kubernetes_engine ? data.google_container_cluster.google_kubernetes_engine_server[0].name : null  # Reference the cluster name from the module
  description = "The name of the GKE cluster."
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
  value       = var.create_postgres ? google_sql_database_instance.postgres_instance[0].private_ip_address : null # Reference the instance IP from the module
  description = "The IP address of the Cloud SQL database instance."
}
