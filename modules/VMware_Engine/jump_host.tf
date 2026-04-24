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

# Windows Server 2022 jump host for accessing vCenter, NSX-T, and HCX management
# consoles via RDP. Deployed on the peer VPC so it has routed access to the
# GCVE management appliances once VPC peering is active.
# NOTE: The Windows administrator password must be set manually via
# "Set Windows Password" in the GCP console after the instance is created.
resource "google_compute_instance" "jump_host" {
  count        = var.create_jump_host ? 1 : 0
  project      = local.project.project_id
  name         = var.jump_host_name
  machine_type = var.jump_host_machine_type
  zone         = var.zone

  tags = ["jump-host"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2022"
      size  = var.jump_host_boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = var.jump_host_subnetwork == "" ? data.google_compute_network.peer_vpc.self_link : null
    subnetwork = var.jump_host_subnetwork != "" ? var.jump_host_subnetwork : null

    access_config {}
  }

  # Full API access is required for Cloud Shell and gcloud operations from the jump host.
  service_account {
    scopes = ["cloud-platform"]
  }

  depends_on = [google_project_service.enabled_services]
}
