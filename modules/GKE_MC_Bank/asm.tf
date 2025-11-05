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
}

resource "google_gke_hub_feature_membership" "service_mesh_feature_member" {
  for_each    = var.enable_cloud_service_mesh ? var.cluster_configs : {}
  project     = local.project.project_id
  location    = "global"

  feature     = google_gke_hub_feature.service_mesh[0].name
  membership  = google_gke_hub_membership.gke_cluster[each.key].membership_id

  mesh {
    management = "MANAGEMENT_AUTOMATIC"
  }

  depends_on = [
    google_container_cluster.gke_cluster,
    google_project_iam_member.service_mesh_service_agent
  ]
}

resource "google_project_iam_member" "service_mesh_service_agent" {
  count   = var.enable_cloud_service_mesh ? 1 : 0
  project = local.project.project_id
  role    = "roles/anthosservicemesh.serviceAgent"
  member  = "serviceAccount:service-${local.project_number}@gcp-sa-servicemesh.iam.gserviceaccount.com"

  depends_on = [
    google_container_cluster.gke_cluster,
  ]
}
