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

# ============================================
# GKE HUB SERVICE ACCOUNT PERMISSIONS
# ============================================

resource "google_project_iam_member" "gke_hub_service_account_roles" {
  for_each = toset([
    "roles/gkehub.serviceAgent",
    "roles/gkehub.admin",
    "roles/container.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/serviceusage.serviceUsageAdmin",
  ])

  project = local.project.project_id
  member  = "serviceAccount:service-${local.project_number}@gcp-sa-gkehub.iam.gserviceaccount.com"
  role    = each.value

  depends_on = [
    google_container_cluster.gke_cluster,
  ]
}

resource "null_resource" "wait_for_iam_propagation" {
  depends_on = [
    google_project_iam_member.gke_hub_service_account_roles,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      ROLE_TO_CHECK="roles/gkehub.serviceAgent"
      MEMBER_TO_CHECK="serviceAccount:service-${local.project_number}@gcp-sa-gkehub.iam.gserviceaccount.com"
      PROJECT_ID="${local.project.project_id}"

      echo "Waiting for IAM propagation..."
      end_time=$$((SECONDS+120))
      while [ $$SECONDS -lt $$end_time ]; do
        if gcloud projects get-iam-policy "$$PROJECT_ID" --flatten="bindings[].members" --format="table(bindings.role)" --filter="bindings.members:$$MEMBER_TO_CHECK AND bindings.role:$$ROLE_TO_CHECK" | grep -q "$$ROLE_TO_CHECK"; then
          echo "IAM policy for $$MEMBER_TO_CHECK with role $$ROLE_TO_CHECK has propagated."
          exit 0
        fi
        sleep 5
      done
      echo "Timed out waiting for IAM propagation."
      exit 1
    EOT
  }
}


# ============================================
# GKE HUB MEMBERSHIP
# ============================================

resource "google_gke_hub_membership" "gke_cluster" {
  project       = local.project.project_id
  location      = "global"
  membership_id = var.gke_cluster
  
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/projects/${local.project.project_id}/locations/${var.region}/clusters/${var.gke_cluster}"
    }
  }
  
  authority {
    issuer = "https://container.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/clusters/${var.gke_cluster}"
  }

  lifecycle {
    ignore_changes = [
      labels,
    ]
  }

  depends_on = [
    google_container_cluster.gke_cluster,
    google_container_node_pool.preemptible_nodes,
    null_resource.wait_for_iam_propagation,
  ]
}
