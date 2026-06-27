/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

output "deployment_id" {
  description = "Module Deployment ID"
  value       = local.random_id
}

output "project_id" {
  description = "GCP Project ID"
  value       = local.project.project_id
}

output "gke_cluster_name" {
  description = "Name of the GKE cluster that receives migrated container workloads"
  value       = google_container_cluster.m2c_guide.name
}

output "gke_cluster_location" {
  description = "Zone where the GKE cluster is deployed"
  value       = google_container_cluster.m2c_guide.location
}

output "postgres_vm_name" {
  description = "Instance name of the PostgreSQL source VM"
  value       = google_compute_instance.petclinic_postgres.name
}

output "postgres_vm_internal_ip" {
  description = "Internal IP address of the PostgreSQL source VM"
  value       = google_compute_instance.petclinic_postgres.network_interface[0].network_ip
  sensitive   = true
}

output "tomcat_vm_name" {
  description = "Instance name of the Tomcat source VM"
  value       = google_compute_instance.tomcat_petclinic.name
}

output "tomcat_vm_external_ip" {
  description = "External IP address of the Tomcat VM — use this to browse the PetClinic app"
  value       = google_compute_instance.tomcat_petclinic.network_interface[0].access_config[0].nat_ip
}

output "m2c_cli_vm_name" {
  description = "Instance name of the Migrate to Containers CLI VM"
  value       = google_compute_instance.m2c_cli.name
}

output "petclinic_url" {
  description = "Browser URL for the PetClinic application running on Tomcat"
  value       = "http://${google_compute_instance.tomcat_petclinic.network_interface[0].access_config[0].nat_ip}:8080/petclinic/"
}

output "vpc_name" {
  description = "Name of the VPC network created for the lab"
  value       = local.vpc_name
}
