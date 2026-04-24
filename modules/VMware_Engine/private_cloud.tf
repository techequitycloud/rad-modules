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

# Private Cloud — provisions vSphere, vSAN, NSX-T, and HCX management appliances.
# management_cidr is immutable after creation; plan this CIDR carefully.
# Provisioning typically takes 30–90 minutes; the 120m timeout reflects this.
resource "google_vmwareengine_private_cloud" "private_cloud" {
  project  = local.project.project_id
  location = var.zone
  name     = var.private_cloud_name

  network_config {
    management_cidr       = var.management_cidr
    vmware_engine_network = google_vmwareengine_network.vmware_engine_network.id
  }

  management_cluster {
    cluster_id = "${var.private_cloud_name}-mgmt-cluster"

    node_type_configs {
      node_type_id = var.node_type_id
      node_count   = var.node_count
    }
  }

  timeouts {
    create = "120m"
    update = "120m"
    delete = "120m"
  }

  depends_on = [google_vmwareengine_network.vmware_engine_network]
}
