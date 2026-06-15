#
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# GKE cluster that receives the migrated container workloads.
# Zonal cluster matching the lab configuration (us-central1-a by default).
# The default node pool is removed immediately and replaced by default_pool
# so node machine type and count are controlled by module variables.
resource "google_container_cluster" "m2c_guide" {
  project             = local.project.project_id
  name                = local.gke_cluster_name
  location            = var.zone
  deletion_protection = false

  network    = data.google_compute_network.vpc.self_link
  subnetwork = data.google_compute_network.vpc.self_link

  remove_default_node_pool = true
  initial_node_count       = 1

  ip_allocation_policy {}

  depends_on = [
    google_project_service.enabled_services,
    google_compute_network.vpc,
  ]
}

resource "google_container_node_pool" "default_pool" {
  project    = local.project.project_id
  name       = "default-pool"
  cluster    = google_container_cluster.m2c_guide.name
  location   = var.zone
  node_count = var.gke_node_count

  node_config {
    machine_type = var.gke_node_machine_type
    disk_size_gb = 50
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}
