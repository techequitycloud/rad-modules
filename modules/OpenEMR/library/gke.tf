/**
 * Copyright 2023 Google LLC
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

# Configure kubernetes provider with Oauth2 access token.
data "google_client_config" "google_kubernetes_engine_server" {
}

# Defer reading the cluster data until the GKE cluster exists.
data "google_container_cluster" "google_kubernetes_engine_server" {
  count      = var.create_google_kubernetes_engine ? 1 : 0
  project    = local.project.project_id
  name       = var.google_kubernetes_engine_server
  location   = local.region

  depends_on = [
    google_container_cluster.gke_autopilot_cluster,
  ]
}

provider "kubernetes" {
  alias = "primary"
  host  = "https://${data.google_container_cluster.google_kubernetes_engine_server.endpoint}"
  token = data.google_client_config.google_kubernetes_engine_server.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.google_kubernetes_engine_server.master_auth[0].cluster_ca_certificate,
  )
}

locals {
  k8s_credentials_cmd = "gcloud container clusters get-credentials ${var.google_kubernetes_engine_server} --region ${local.region} --project ${local.project.project_id}"
}

# Resource to create the GKE Autopilot cluster
resource "google_container_cluster" "gke_autopilot_cluster" {
  count                     = var.create_google_kubernetes_engine ? 1 : 0
  project                   = local.project.project_id
  name                      = var.google_kubernetes_engine_server
  location                  = local.region
  initial_node_count        = 1
  deletion_protection       = false
  network                   = "https://www.googleapis.com/compute/v1/projects/${var.existing_project_id}/global/networks/${var.network_name}"
  subnetwork                = "https://www.googleapis.com/compute/v1/projects/${var.existing_project_id}/regions/${local.region}/subnetworks/gke-vpc-subnet-${local.region}"
  enable_autopilot          = true # Enable Autopilot mode

  cluster_autoscaling {
    auto_provisioning_defaults {
      service_account = google_service_account.gke_sa.email
      oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    }
  }

  # Specify secondary IP ranges for Pods and Services
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods-range"  # Directly use the range name
    services_secondary_range_name = "services-range"  # Directly use the range name
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }

    horizontal_pod_autoscaling {
      disabled = false
    }

    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }

  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  cost_management_config {
    enabled = true
  }

  security_posture_config {
    mode = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  depends_on    = [
    google_compute_subnetwork.gce_subnetwork,
    google_compute_subnetwork.gke_subnetwork,
    google_service_networking_connection.psconnect,
  ]
}
