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

#########################################################################
# Data source — look up existing cluster when create_cluster = false
#########################################################################

data "google_container_cluster" "existing_cluster" {
  count    = var.create_cluster ? 0 : 1
  project  = local.project.project_id
  name     = var.gke_cluster
  location = var.gcp_region
}

#########################################################################
# Local — unified cluster reference regardless of create_cluster
#########################################################################

locals {
  cluster = var.create_cluster ? google_container_cluster.gke_cluster[0] : data.google_container_cluster.existing_cluster[0]
}

#########################################################################
# Kubernetes provider
#########################################################################

data "google_client_config" "gke_cluster" {}

provider "kubernetes" {
  alias = "primary"
  host  = "https://${local.cluster.endpoint}"
  token = data.google_client_config.gke_cluster.access_token
  cluster_ca_certificate = base64decode(
    local.cluster.master_auth[0].cluster_ca_certificate,
  )
}

#########################################################################
# GKE cluster (only when create_cluster = true)
#########################################################################

resource "google_container_cluster" "gke_cluster" {
  count               = var.create_cluster ? 1 : 0
  project             = local.project.project_id
  name                = var.gke_cluster
  location            = var.gcp_region
  deletion_protection = false
  network             = local.network.name
  subnetwork          = local.subnet.name

  enable_autopilot         = var.create_autopilot_cluster
  remove_default_node_pool = var.create_autopilot_cluster ? null : true
  initial_node_count       = var.create_autopilot_cluster ? null : 1

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

#########################################################################
# Service account, node pool, and IAM (Standard clusters created here only)
#########################################################################

resource "google_service_account" "gke_standard" {
  count        = (var.create_autopilot_cluster || !var.create_cluster) ? 0 : 1
  project      = local.project.project_id
  account_id   = "gke-standard-sa"
  display_name = "GKE Standard Service Account"
}

resource "google_container_node_pool" "preemptible_nodes" {
  count          = (var.create_autopilot_cluster || !var.create_cluster) ? 0 : 1
  project        = local.project.project_id
  name           = "node-pool"
  cluster        = google_container_cluster.gke_cluster[0].id
  node_count     = 2
  node_locations = data.google_compute_zones.available_zones.names

  node_config {
    spot         = true
    machine_type = "e2-standard-2"
    disk_size_gb = 50
    disk_type    = "pd-ssd"

    service_account = google_service_account.gke_standard[0].email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

  depends_on = [
    google_service_account.gke_standard,
  ]
}

locals {
  gke_sa_project_roles = [
    # 🛡️ Sentinel Security Fix: Reduced `roles/storage.objectAdmin` to `roles/storage.objectViewer`.
    # Impact: Prevented the GKE node service account from having project-wide destructive access to all GCS buckets.
    "roles/storage.objectViewer",
    "roles/artifactregistry.reader",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/logging.logWriter",
    "roles/compute.networkViewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/container.defaultNodeServiceAccount",
  ]
}

resource "google_project_iam_member" "gke_standard_sa_role" {
  for_each = (var.create_autopilot_cluster || !var.create_cluster) ? toset([]) : toset(local.gke_sa_project_roles)
  project  = local.project.project_id
  member   = "serviceAccount:${google_service_account.gke_standard[0].email}"
  role     = each.value

  depends_on = [
    google_service_account.gke_standard,
  ]
}
