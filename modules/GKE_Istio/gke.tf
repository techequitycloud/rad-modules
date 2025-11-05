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

locals {
  cluster_name = google_container_cluster.gke_standard_cluster.name
  cluster_location = google_container_cluster.gke_standard_cluster.location
}

# Configure kubernetes provider with Oauth2 access token.
data "google_client_config" "gke_cluster" {
}

# Defer reading the cluster data until the GKE cluster exists.
data "google_container_cluster" "gke_cluster" {
  project    = local.project.project_id
  name       = local.cluster_name
  location   = local.cluster_location

  depends_on = [
    google_container_cluster.gke_standard_cluster
  ]
}

locals {
  k8s_credentials_cmd = "gcloud container clusters get-credentials ${var.gke_cluster} --region ${var.region} --project ${local.project.project_id}"
}

# Module to create the GKE private cluster
resource "google_container_cluster" "gke_standard_cluster" {
  project                   = local.project.project_id
  name                      = var.gke_cluster
  location                  = var.region
  allow_net_admin           = true
  networking_mode           = "VPC_NATIVE"
  datapath_provider         = "ADVANCED_DATAPATH" # enable dataplane v2
  remove_default_node_pool  = true
  initial_node_count        = 1
  deletion_protection       = false
  network                   = google_compute_network.vpc.name
  subnetwork                = google_compute_subnetwork.subnetwork.name

  ip_allocation_policy {
    cluster_secondary_range_name = var.pod_ip_range
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

  workload_identity_config {
    workload_pool = "${local.project.project_id}.svc.id.goog"
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
    channel = var.release_channel
  }

/**

  fleet {
    project = local.project.project_id
  }

**/

  depends_on = [
    google_compute_network.vpc,
    google_compute_subnetwork.subnetwork,
    google_project_iam_member.gke_sa_role,
  ]
}

resource "google_container_node_pool" "preemptible_nodes" {
  for_each   = var.node_pools
  project    = local.project.project_id
  name       = each.key
  cluster    = google_container_cluster.gke_standard_cluster.id
  node_count = each.value.node_count
  node_locations = data.google_compute_zones.available_zones.names  # Automatically retrieves valid zones

  node_config {
    preemptible  = each.value.preemptible
    machine_type = each.value.machine_type
    disk_size_gb = each.value.disk_size_gb
    disk_type    = each.value.disk_type

    service_account = google_service_account.gke_sa.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

  # Ensures that this resource is created
  depends_on   = [
    google_service_account.gke_sa,
  ]
}

# Service account for GCP identity within Kubernetes
resource "google_service_account" "gke_sa" {
  project      = local.project.project_id
  account_id   = "gke-sa"        # Account ID for the service account
  description  = "GKE Service Account"      # Description of the service account
  display_name = "GKE Service Account"      # Display name for the service account

  depends_on = [
    google_project_service.enabled_services
  ]
}

# Local values that can be used throughout the Terraform configuration
locals {
  # List of roles assigned to the GKE service account within the project
  gke_sa_project_roles = [
    "roles/storage.objectAdmin",
    "roles/storage.objectViewer",
    "roles/artifactregistry.reader",
    "roles/storage.admin",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/logging.logWriter",
    "roles/compute.networkViewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/container.defaultNodeServiceAccount",
  ]
}

# IAM permissions for GKE service account on the project
resource "google_project_iam_member" "gke_sa_role" {
  for_each = toset(local.gke_sa_project_roles) # Looping over the set of roles
  project  = local.project.project_id          # The project ID
  member   = "serviceAccount:${google_service_account.gke_sa.email}" # The service account to assign the role to
  role     = each.value                        # The role from the set to be assigned

  # Ensures that this resource is created
  depends_on   = [
    google_service_account.gke_sa,
  ]
}
