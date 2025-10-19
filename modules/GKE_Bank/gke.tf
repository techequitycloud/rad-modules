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
  cluster_name = var.create_autopilot_cluster ? google_container_cluster.gke_autopilot_cluster[0].name : google_container_cluster.gke_standard_cluster[0].name
  cluster_location = var.create_autopilot_cluster ? google_container_cluster.gke_autopilot_cluster[0].location : google_container_cluster.gke_standard_cluster[0].location
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
    google_container_cluster.gke_autopilot_cluster,
    google_container_cluster.gke_standard_cluster
  ]
}

provider "kubernetes" {
  alias = "primary"
  host  = "https://${data.google_container_cluster.gke_cluster.endpoint}"
  token = data.google_client_config.gke_cluster.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.gke_cluster.master_auth[0].cluster_ca_certificate,
  )
}

locals {
  k8s_credentials_cmd = "gcloud container clusters get-credentials ${var.gke_cluster} --region ${var.region} --project ${local.project.project_id}"
}

# Module to create the GKE private cluster
resource "google_container_cluster" "gke_autopilot_cluster" {
  count                 = var.create_autopilot_cluster ? 1 : 0
  project               = local.project.project_id
  enable_autopilot      = true
  name                  = var.gke_cluster
  location              = var.region
  deletion_protection   = false
  network               = google_compute_network.vpc.name
  subnetwork            = google_compute_subnetwork.subnetwork.name

  ip_allocation_policy {
    cluster_secondary_range_name = var.pod_ip_range
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
    google_project_service.gke_hub_service,
    google_gke_hub_feature.acm_feature,
    google_gke_hub_feature.service_mesh,
  ]
}

resource "google_service_account" "gke_standard" {
  project      = local.project.project_id
  account_id   = "gke-standard-sa"
  display_name = "GKE Standard Service Account"
}


# Module to create the GKE private cluster
resource "google_container_cluster" "gke_standard_cluster" {
  count                     = var.create_autopilot_cluster ? 0 : 1
  project                   = local.project.project_id
  name                      = var.gke_cluster
  location                  = var.region
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
    google_project_service.gke_hub_service,
    google_gke_hub_feature.acm_feature,
    google_gke_hub_feature.service_mesh,
  ]
}

resource "google_container_node_pool" "preemptible_nodes" {
  project    = local.project.project_id
  count      = var.create_autopilot_cluster ? 0 : 1
  name       = "node-pool"
  cluster    = google_container_cluster.gke_standard_cluster[0].id
  node_count = 2
  node_locations = data.google_compute_zones.available_zones.names  # Automatically retrieves valid zones

  node_config {
    preemptible  = true
    machine_type = "e2-standard-2"
    disk_size_gb = 50
    disk_type    = "pd-ssd" 
    
    service_account = google_service_account.gke_standard.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",    
    ]
  }

  # Ensures that this resource is created
  depends_on   = [
    google_service_account.gke_standard,
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
resource "google_project_iam_member" "gke_standard_sa_role" {
  for_each = toset(local.gke_sa_project_roles) # Looping over the set of roles
  project  = local.project.project_id          # The project ID
  member   = "serviceAccount:${google_service_account.gke_standard.email}" # The service account to assign the role to
  role     = each.value                        # The role from the set to be assigned

  # Ensures that this resource is created
  depends_on   = [
    google_service_account.gke_standard,
  ]
}