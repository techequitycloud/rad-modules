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

resource "null_resource" "poll_for_cloud_service_mesh_api_activation" {
  count       = (var.create_google_kubernetes_engine && var.configure_cloud_service_mesh) ? 1 : 0

  depends_on = [
    google_project_service.enabled_services,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      echo "Waiting for 'mesh.googleapis.com' API to be enabled..."
      MAX_ATTEMPTS=60
      SLEEP_SECONDS=10
      for i in $(seq 1 $MAX_ATTEMPTS); do
        if gcloud services list --enabled --project="${local.project.project_id}" --filter="config.name:mesh.googleapis.com" --format="value(config.name)" | grep -q "mesh.googleapis.com"; then
          echo "'mesh.googleapis.com' API is enabled."
          exit 0
        fi
        echo "Attempt $i of $MAX_ATTEMPTS: API not enabled yet. Retrying in $SLEEP_SECONDS seconds..."
        sleep $SLEEP_SECONDS
      done
      echo "Error: Timeout waiting for 'mesh.googleapis.com' API to be enabled."
      exit 1
    EOT
  }
}

resource "google_gke_hub_feature" "cloud_service_mesh" {
  count       = (var.create_google_kubernetes_engine && var.configure_cloud_service_mesh) ? 1 : 0
  project     = local.project.project_id
  name        = "servicemesh"
  location    = "global"
  fleet_default_member_config {
    mesh {
      management = "MANAGEMENT_AUTOMATIC"
    }
  }

  depends_on = [
    null_resource.poll_for_cloud_service_mesh_api_activation
  ]
}

resource "google_gke_hub_feature_membership" "cloud_service_mesh_feature_member" {
  count       = (var.create_google_kubernetes_engine && var.configure_cloud_service_mesh) ? 1 : 0
  project     = local.project.project_id
  location    = "global"

  feature     = google_gke_hub_feature.cloud_service_mesh[count.index].name
  membership  = google_gke_hub_membership.gke_cluster[count.index].membership_id # local.project.project_id

  mesh {
    management = "MANAGEMENT_AUTOMATIC"
  }

  depends_on = [
    google_container_cluster.gke_autopilot_cluster,
    google_project_iam_member.cloud_service_mesh_service_agent,
  ]
}

resource "google_project_iam_member" "cloud_service_mesh_service_agent" {
  count   = (var.create_google_kubernetes_engine && var.configure_cloud_service_mesh) ? 1 : 0
  project = local.project.project_id
  role    = "roles/anthosservicemesh.serviceAgent"
  member  = "serviceAccount:service-${local.project_number}@gcp-sa-servicemesh.iam.gserviceaccount.com"

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    google_container_cluster.gke_autopilot_cluster,
  ]
}
