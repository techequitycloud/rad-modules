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

# VPC Network Peering — connects the VMware Engine network to the peer VPC (vmaas network).
# Enabling import/export of custom routes ensures NSX-T segments created inside GCVE
# are automatically propagated to the peered VPC routing table, and vice versa.
# Depends on the private cloud because peering activates fully only after the cloud is live.
resource "google_vmwareengine_network_peering" "vpc_peering" {
  project               = local.project.project_id
  name                  = var.network_peering_name
  vmware_engine_network = google_vmwareengine_network.vmware_engine_network.id
  peer_network          = "projects/${local.project.project_id}/global/networks/${var.peer_vpc_name}"
  peer_network_type     = "STANDARD"

  export_custom_routes                = true
  import_custom_routes                = true
  export_custom_routes_with_public_ip = false
  import_custom_routes_with_public_ip = false

  description = "Peering between ${var.vmware_engine_network_name} and VPC ${var.peer_vpc_name}"

  depends_on = [
    google_vmwareengine_network.vmware_engine_network,
    google_vmwareengine_private_cloud.private_cloud,
  ]
}
