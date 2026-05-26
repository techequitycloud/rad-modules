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

output "windows_vm_name" {
  description = "Name of the Windows Server 2022 VM that hosts MCDCv6. Use this to locate the instance in the GCP Console."
  value       = var.create_windows_vm ? google_compute_instance.windows_vm[0].name : null
}

output "windows_vm_external_ip" {
  description = "External IP address of the Windows VM — use this to connect via RDP. Username: migrationcenter. Password is in Secret Manager."
  value       = var.create_windows_vm ? google_compute_instance.windows_vm[0].network_interface[0].access_config[0].nat_ip : null
}

output "windows_vm_password_secret_id" {
  description = "Secret Manager secret ID containing the randomly generated RDP password for the Windows VM."
  value       = var.create_windows_vm ? google_secret_manager_secret.windows_vm_password[0].id : null
  sensitive   = true
}

output "linux_vm_names" {
  description = "Names of the Debian Linux VMs deployed as MCDCv6 discovery scan targets."
  value       = [for vm in google_compute_instance.linux_vm : vm.name]
}

output "linux_vm_internal_ips" {
  description = "Internal IP addresses of the Linux target VMs. Use the first three octets to define the MCDCv6 IP scan range (e.g. if IPs are 10.128.0.2–10.128.0.4, scan 10.128.0.1 to 10.128.0.8)."
  value       = [for vm in google_compute_instance.linux_vm : vm.network_interface[0].network_ip]
}

output "ssh_key_bucket_name" {
  description = "Cloud Storage bucket containing the SSH private key (lab-ssh-key.pem). Download this file and load it into MCDCv6 as the 'Lab-key' SSH credential."
  value       = var.create_ssh_key_bucket ? google_storage_bucket.ssh_key_bucket[0].name : null
}

output "ssh_key_user" {
  description = "Linux username that corresponds to the SSH private key stored in GCS. Enter this as the 'Username for this key' field in MCDCv6."
  value       = local.ssh_key_user
}

output "mc_discovery_client_name" {
  description = "Name to enter in the MCDCv6 'Add a discovery client name' field during login. Must match exactly."
  value       = var.mc_discovery_client_name
}

output "migration_center_url" {
  description = "Direct URL to the Migration Center console for this project."
  value       = "https://console.cloud.google.com/migration/center?project=${local.project.project_id}"
}

output "mc_source_id" {
  description = "Migration Center discovery source ID created by this module."
  value       = var.initialize_migration_center ? local.mc_source_name : null
}

output "vpc_name" {
  description = "Name of the VPC network created for this lab."
  value       = local.peer_vpc_name
}
