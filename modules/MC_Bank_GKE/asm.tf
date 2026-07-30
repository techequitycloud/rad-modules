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

resource "google_gke_hub_feature" "service_mesh_feature" {
  count    = var.enable_cloud_service_mesh ? 1 : 0
  provider = google-beta

  project  = local.project.project_id
  name     = "servicemesh"
  location = "global"

  depends_on = [
    google_project_service.enabled_services,
  ]
}

resource "google_gke_hub_feature_membership" "service_mesh_feature_member" {
  for_each   = var.enable_cloud_service_mesh ? local.cluster_configs : {}
  provider   = google-beta
  project    = local.project.project_id
  feature    = google_gke_hub_feature.service_mesh_feature[0].name
  location   = google_gke_hub_feature.service_mesh_feature[0].location
  membership = google_gke_hub_membership.hub_membership[each.key].membership_id
  mesh {
    management = "MANAGEMENT_AUTOMATIC"
  }

  depends_on = [
    google_gke_hub_feature.service_mesh_feature,
    google_gke_hub_membership.hub_membership,
  ]
}
