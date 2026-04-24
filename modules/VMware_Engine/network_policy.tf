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

# Network Policy — controls internet egress and external IP allocation for VMware workload VMs.
# Activation can take up to 15 minutes after apply; the edge_services_cidr must
# not overlap with management_cidr or any peered VPC subnets.
resource "google_vmwareengine_network_policy" "network_policy" {
  project               = local.project.project_id
  location              = var.region
  name                  = var.network_policy_name
  edge_services_cidr    = var.edge_services_cidr
  vmware_engine_network = google_vmwareengine_network.vmware_engine_network.id

  internet_access {
    enabled = var.enable_internet_access
  }

  external_ip {
    enabled = var.enable_external_ip
  }

  depends_on = [google_vmwareengine_network.vmware_engine_network]
}
