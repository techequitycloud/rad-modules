/**
 * Copyright 2025 Google LLC
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

resource "time_sleep" "allow_10_minutes_for_gke_hub_api_activation" {
  depends_on = [
    google_project_service.enabled_services,
  ]

  create_duration = "10m"
}

resource "google_project_service" "gke_hub_service" {
  project = local.project.project_id
  service = "gkehub.googleapis.com"

  depends_on = [
    time_sleep.allow_10_minutes_for_gke_hub_api_activation
  ]
}

resource "google_gke_hub_membership" "gke_cluster" {
  project = local.project.project_id
  membership_id = var.gke_cluster
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/projects/${local.project.project_id}/locations/${var.region}/clusters/${var.gke_cluster}"
    }
  }
  authority {
    issuer = "https://container.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/clusters/${var.gke_cluster}"
  }

  depends_on = [
    google_container_cluster.gke_autopilot_cluster,
    google_container_cluster.gke_standard_cluster,
    google_project_iam_binding.acm_wi_trace_agent,
    google_project_iam_binding.acm_wi_metricWriter,
    google_project_iam_member.service_mesh_service_agent,
    google_project_iam_member.gke_hub_service_account_roles,
    google_container_node_pool.preemptible_nodes,
  ]
}

# Grant roles to the GKE Hub service account
resource "google_project_iam_member" "gke_hub_service_account_roles" {
  for_each = toset([
    "roles/gkehub.serviceAgent",
    "roles/gkehub.admin",
    "roles/container.admin",
  ])

  project = local.project.project_id
  member  = "serviceAccount:service-${local.project_number}@gcp-sa-gkehub.iam.gserviceaccount.com"
  role    = each.value

  depends_on = [
    google_container_cluster.gke_autopilot_cluster,
    google_container_cluster.gke_standard_cluster,
  ]
}

resource "time_sleep" "allow_10_minutes_for_fleet_synchronization" {
  depends_on = [
    google_gke_hub_feature_membership.gke_cluster_acm_feature_member,
    google_gke_hub_feature_membership.service_mesh_feature_member,
    google_gke_hub_membership.gke_cluster,
  ]

  create_duration = "10m"
}
