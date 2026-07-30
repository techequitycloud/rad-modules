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

output "vmware_engine_network_id" {
  description = "Full resource ID of the VMware Engine Network"
  value       = google_vmwareengine_network.vmware_engine_network.id
}

output "private_cloud_id" {
  description = "Full resource ID of the Private Cloud"
  value       = google_vmwareengine_private_cloud.private_cloud.id
}

output "vcenter_fqdn" {
  description = "vCenter Server FQDN — use this URL from the jump host browser to access vSphere Client"
  value       = google_vmwareengine_private_cloud.private_cloud.vcenter[0].fqdn
}

output "nsx_fqdn" {
  description = "NSX-T Manager FQDN — use this URL from the jump host browser to access the NSX-T console"
  value       = google_vmwareengine_private_cloud.private_cloud.nsx[0].fqdn
}

output "hcx_fqdn" {
  description = "HCX Manager FQDN"
  value       = google_vmwareengine_private_cloud.private_cloud.hcx[0].fqdn
}

output "network_peering_state" {
  description = "Current state of the VPC Network Peering (Active once the private cloud is fully provisioned)"
  value       = google_vmwareengine_network_peering.vpc_peering.state
}

output "network_policy_id" {
  description = "Full resource ID of the VMware Engine Network Policy"
  value       = google_vmwareengine_network_policy.network_policy.id
}
