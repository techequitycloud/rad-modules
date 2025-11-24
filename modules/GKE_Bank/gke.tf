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
data "google_client_config" "gke_cluster" {
}

provider "kubernetes" {
  alias = "primary"
  host  = "https://${google_container_cluster.gke_cluster.endpoint}"
  token = data.google_client_config.gke_cluster.access_token
  cluster_ca_certificate = base64decode(
    google_container_cluster.gke_cluster.master_auth[0].cluster_ca_certificate,
  )
}

# Module to create the GKE private cluster
resource "google_container_cluster" "gke_cluster" {
  project               = local.project.project_id
  name                  = var.gke_cluster
  location              = var.region
  deletion_protection   = false
  network               = google_compute_network.vpc.name
  subnetwork            = google_compute_subnetwork.subnetwork.name

  # Conditional attributes based on cluster type
  enable_autopilot             = var.create_autopilot_cluster
  
  # Only set these for Standard clusters (not Autopilot)
  remove_default_node_pool     = var.create_autopilot_cluster ? null : true
  initial_node_count           = var.create_autopilot_cluster ? null : 1

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pod_ip_range
    services_secondary_range_name = var.service_ip_range
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

  # Workload Identity is only needed for Standard clusters
  dynamic "workload_identity_config" {
    for_each = var.create_autopilot_cluster ? [] : [1]
    content {
      workload_pool = "${local.project.project_id}.svc.id.goog"
    }
  }

  security_posture_config {
    mode               = "BASIC"
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
    channel = var.release_channel
  }

  depends_on = [
    google_compute_network.vpc,
    google_compute_subnetwork.subnetwork,
  ]
}

# Service Account for Standard GKE cluster
resource "google_service_account" "gke_standard" {
  count        = var.create_autopilot_cluster ? 0 : 1
  project      = local.project.project_id
  account_id   = "gke-standard-sa"
  display_name = "GKE Standard Service Account"
}

# Node pool for Standard GKE cluster
resource "google_container_node_pool" "preemptible_nodes" {
  count      = var.create_autopilot_cluster ? 0 : 1
  project    = local.project.project_id
  name       = "node-pool"
  cluster    = google_container_cluster.gke_cluster.id
  node_count = 2
  node_locations = data.google_compute_zones.available_zones.names

  node_config {
    spot         = true
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type
    
    service_account = google_service_account.gke_standard[0].email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",    
    ]
  }

  depends_on = [
    google_service_account.gke_standard,
  ]
}

# Local values for IAM roles
locals {
  gke_sa_project_roles = [
    "roles/storage.objectViewer",
    "roles/artifactregistry.reader",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/logging.logWriter",
    "roles/stackdriver.resourceMetadata.writer",
  ]
}

resource "google_project_iam_custom_role" "gke_node_service_account" {
  count       = var.create_autopilot_cluster ? 0 : 1
  project     = local.project.project_id
  role_id     = "gkeNodeServiceAccount"
  title       = "GKE Node Service Account"
  description = "Custom role for GKE node service account"
  permissions = [
    "logging.logWriter",
    "monitoring.metricWriter",
    "monitoring.viewer",
    "stackdriver.resourceMetadata.writer",
    "storage.objectViewer",
    "artifactregistry.reader",
  ]
}

# IAM permissions for GKE Standard service account
resource "google_project_iam_member" "gke_standard_sa_role" {
  for_each = var.create_autopilot_cluster ? [] : toset(local.gke_sa_project_roles)
  project  = local.project.project_id
  member   = "serviceAccount:${google_service_account.gke_standard[0].email}"
  role     = each.value

  depends_on = [
    google_service_account.gke_standard,
  ]
}

resource "google_project_iam_member" "gke_standard_sa_custom_role" {
  count    = var.create_autopilot_cluster ? 0 : 1
  project  = local.project.project_id
  member   = "serviceAccount:${google_service_account.gke_standard[0].email}"
  role     = google_project_iam_custom_role.gke_node_service_account[0].id

  depends_on = [
    google_service_account.gke_standard,
    google_project_iam_custom_role.gke_node_service_account,
  ]
}
