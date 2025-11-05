/**
 * Copyright 2025 Tech Equity Ltd
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

# ============================================
# Wait for API Activation
# ============================================
resource "time_sleep" "await_for_gke_hub_api_activation" {
  depends_on = [
    google_project_service.enabled_services,
  ]

  create_duration = "5m"
}

resource "google_gke_hub_feature" "service_mesh" {
  count       = var.enable_cloud_service_mesh ? 1 : 0
  project     = local.project.project_id
  name        = "servicemesh"
  location    = "global"
  fleet_default_member_config {
    mesh {
      management = "MANAGEMENT_AUTOMATIC"
    }
  }

  depends_on = [
    time_sleep.await_for_gke_hub_api_activation,
  ]
}

resource "google_gke_hub_feature_membership" "service_mesh_feature_member" {
  count      = var.enable_cloud_service_mesh ? 1 : 0
  project    = local.project.project_id
  location   = "global"
  feature    = google_gke_hub_feature.service_mesh[0].name
  membership = google_gke_hub_membership.gke_cluster.membership_id

  mesh {
    management = "MANAGEMENT_AUTOMATIC"
  }

  depends_on = [
    google_container_cluster.gke_cluster,
    google_gke_hub_membership.gke_cluster,
    google_gke_hub_feature.service_mesh,
  ]
}

# ============================================
# SERVICE MESH READINESS CHECK (MANAGED ASM)
# ============================================

resource "time_sleep" "wait_for_service_mesh" {
  count = var.enable_cloud_service_mesh ? 1 : 0
  depends_on = [
    google_gke_hub_feature_membership.service_mesh_feature_member,
    kubernetes_namespace.bank_of_anthos,
  ]
  create_duration = "5m"
}
