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
data "google_client_config" "google_kubernetes_engine_server" {}

data "google_container_cluster" "google_kubernetes_engine_server" {
  count    = var.create_google_kubernetes_engine && var.google_kubernetes_engine_server != "" ? 1 : 0
  project  = local.project.project_id
  name     = var.google_kubernetes_engine_server
  location = local.region

  depends_on = [google_container_cluster.gke_autopilot_cluster]
}

locals {
  cluster_endpoint = try(data.google_container_cluster.google_kubernetes_engine_server[0].endpoint, "")
  cluster_ca_cert  = try(data.google_container_cluster.google_kubernetes_engine_server[0].master_auth[0].cluster_ca_certificate, "")
}

# Conditional Kubernetes provider configuration
provider "kubernetes" {
  alias                  = "primary"
  host                   = "https://${local.cluster_endpoint}"
  token                  = data.google_client_config.google_kubernetes_engine_server.access_token
  cluster_ca_certificate = base64decode(local.cluster_ca_cert)
}

locals {
  k8s_credentials_cmd = "gcloud container clusters get-credentials ${var.google_kubernetes_engine_server} --region ${local.region} --project ${local.project.project_id}"
}

# Data source to get the subnet details
data "google_compute_subnetwork" "gke_subnet" {
  count   = var.create_google_kubernetes_engine ? 1 : 0
  project = local.project.project_id
  name    = element(split("/", local.gke_subnet_id), length(split("/", local.gke_subnet_id)) - 1)
  region  = local.region
}

# Resource to create the GKE Autopilot cluster
resource "google_container_cluster" "gke_autopilot_cluster" {
  count                     = var.create_google_kubernetes_engine ? 1 : 0
  project                   = local.project.project_id
  name                      = var.google_kubernetes_engine_server
  location                  = local.region
  deletion_protection       = false
  enable_autopilot          = true # Enable Autopilot mode

  network                   = local.vpc_network_id  # Reference the VPC network directly
  subnetwork                = local.gce_subnet_id # Reference the GKE subnetwork by region

  cluster_autoscaling {
    auto_provisioning_defaults {
      service_account = local.gke_sa_email
      oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    }
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
    google_service_account.gke_sa_admin,

    google_compute_subnetwork.gce_subnetwork,
    google_compute_subnetwork.gke_subnetwork,
    google_service_networking_connection.psconnect,
    google_sql_database_instance.postgres_instance,
    google_sql_database_instance.mysql_instance,
  ]
}
