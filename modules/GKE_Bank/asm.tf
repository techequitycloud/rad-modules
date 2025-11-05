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
# Verify GKE Hub API Activation
# ============================================
resource "null_resource" "verify_gke_hub_api_activation" {
  depends_on = [
    google_project_service.enabled_services,
  ]
  provisioner "local-exec" {
    command = <<EOT
      set -e
      end_time=$((SECONDS+300))
      while [ $SECONDS -lt $end_time ]; do
        if gcloud services list --project "${local.project.project_id}" --filter="gkehub.googleapis.com" --format="value(state)" | grep -q "ENABLED"; then
          echo "GKE Hub API is enabled."
          exit 0
        fi
        echo "Waiting for GKE Hub API to be enabled..."
        sleep 10
      done
      echo "Timed out waiting for GKE Hub API to be enabled."
      exit 1
    EOT
  }
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
    null_resource.verify_gke_hub_api_activation,
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

resource "null_resource" "wait_for_service_mesh" {
  count = var.enable_cloud_service_mesh ? 1 : 0
  depends_on = [
    google_gke_hub_feature_membership.service_mesh_feature_member,
    kubernetes_namespace.bank_of_anthos,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Waiting for ASM control plane to be ready..."
      end_time=$((SECONDS+600))
      while [ $SECONDS -lt $end_time ]; do
        status=$(kubectl get controlplanerevision -n istio-system -o=jsonpath='{.items[?(@.spec.type=="managed")].status.conditions[?(@.type=="Reconciled")].status}')
        if [ "$status" == "True" ]; then
          echo "ASM control plane is ready."
          exit 0
        fi
        sleep 15
      done
      echo "Timed out waiting for ASM control plane to be ready."
      exit 1
    EOT
  }
}
