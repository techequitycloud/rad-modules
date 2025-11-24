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

// ------------------------------------------------------------------
// Kubernetes Provider Configuration
// ------------------------------------------------------------------

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

// ------------------------------------------------------------------
// GKE Cluster
// ------------------------------------------------------------------

resource "google_container_cluster" "gke_cluster" {
  project               = local.project.project_id
  name                  = "${var.gke_cluster}-${local.random_id}"
  location              = var.region
  deletion_protection   = false
  network               = google_compute_network.vpc.name
  subnetwork            = google_compute_subnetwork.subnetwork.name

  enable_autopilot = var.create_autopilot_cluster
  
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

// ------------------------------------------------------------------
// GKE Standard Cluster Configuration
// ------------------------------------------------------------------

resource "google_service_account" "gke_standard_sa" {
  count        = var.create_autopilot_cluster ? 0 : 1
  project      = local.project.project_id
  account_id   = "gke-standard-sa-${local.random_id}"
  display_name = "GKE Standard Service Account"
}

resource "google_container_node_pool" "gke_node_pool" {
  count      = var.create_autopilot_cluster ? 0 : 1
  project    = local.project.project_id
  name       = "node-pool-${local.random_id}"
  cluster    = google_container_cluster.gke_cluster.id
  node_count = 2
  node_locations = data.google_compute_zones.available_zones.names

  node_config {
    spot         = true
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type
    
    service_account = google_service_account.gke_standard_sa[0].email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",    
    ]
  }

  depends_on = [
    google_service_account.gke_standard_sa,
  ]
}

resource "google_project_iam_custom_role" "gke_custom_role" {
  count       = var.create_autopilot_cluster ? 0 : 1
  project     = local.project.project_id
  role_id     = "gkeNodeServiceAccountRole"
  title       = "GKE Node Service Account Role"
  description = "Custom role for GKE node service account with least-privilege permissions."
  permissions = [
    "storage.objects.list",
    "storage.objects.get",
    "artifactregistry.repositories.list",
    "artifactregistry.repositories.get",
    "monitoring.metricDescriptors.list",
    "monitoring.timeSeries.list",
    "logging.logEntries.create",
    "compute.networks.get",
    "stackdriver.resourceMetadata.write",
  ]
}

resource "google_project_iam_member" "gke_standard_sa_custom_role" {
  count    = var.create_autopilot_cluster ? 0 : 1
  project  = local.project.project_id
  member   = "serviceAccount:${google_service_account.gke_standard_sa[0].email}"
  role     = google_project_iam_custom_role.gke_custom_role[0].id

  depends_on = [
    google_service_account.gke_standard_sa,
    google_project_iam_custom_role.gke_custom_role,
  ]
}
