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

resource "time_sleep" "allow_5_minutes_after_gke_cluster_creation" {
  count   = var.create_google_kubernetes_engine && (var.configure_config_management || var.configure_cloud_service_mesh) ? 1 : 0
  depends_on = [
    google_container_cluster.gke_autopilot_cluster,
  ]

  create_duration = "5m"
}

resource "google_gke_hub_membership" "gke_cluster" {
  count   = var.create_google_kubernetes_engine && (var.configure_config_management || var.configure_cloud_service_mesh) ? 1 : 0
  project = local.project.project_id
  membership_id = var.google_kubernetes_engine_server
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/projects/${local.project.project_id}/locations/${local.region}/clusters/${var.google_kubernetes_engine_server}"
    }
  }
  authority {
    issuer = "https://container.googleapis.com/v1/projects/${local.project.project_id}/locations/${local.region}/clusters/${var.google_kubernetes_engine_server}"
  }

  depends_on = [
    time_sleep.allow_5_minutes_after_gke_cluster_creation,
    google_project_iam_binding.config_management_trace_agent,
    google_project_iam_binding.config_management_metric_writer,
    google_project_iam_member.cloud_service_mesh_service_agent,
    google_project_iam_member.gke_hub_service_account_roles,
  ]
}

resource "google_project_iam_member" "gke_hub_service_account_roles" {
  for_each = var.create_google_kubernetes_engine && (var.configure_config_management || var.configure_cloud_service_mesh) ? toset([
    "roles/gkehub.serviceAgent",
    "roles/gkehub.admin",
    "roles/container.admin",
  ]) : toset([]) 

  project = local.project.project_id
  member  = "serviceAccount:service-${local.project_number}@gcp-sa-gkehub.iam.gserviceaccount.com"
  role    = each.value

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    google_container_cluster.gke_autopilot_cluster,
  ]
}

