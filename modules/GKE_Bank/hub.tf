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

// ------------------------------------------------------------------
// GKE Hub API Verification
// ------------------------------------------------------------------

resource "null_resource" "verify_gke_hub_api_activation" {
  depends_on = [
    google_project_service.enabled_services,
    google_container_cluster.gke_cluster,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      PROJECT_ID="${local.project.project_id}"
      
      echo "Verifying GKE Hub API activation..."
      end_time=$((SECONDS+300))
      
      while [ $SECONDS -lt $end_time ]; do
        if gcloud services list --enabled --project="$PROJECT_ID" \
           --filter="name:gkehub.googleapis.com" \
           --format="value(name)" | grep -q "gkehub.googleapis.com"; then
          echo "✓ GKE Hub API is enabled"
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

// ------------------------------------------------------------------
// API and IAM Propagation Waits
// ------------------------------------------------------------------

resource "null_resource" "wait_for_api_propagation" {
  depends_on = [null_resource.verify_gke_hub_api_activation]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      echo "Waiting 30 seconds for GKE Hub API to fully propagate..."
      sleep 30
      echo "✓ Propagation wait completed"
    EOT
  }
}

resource "null_resource" "wait_for_iam_propagation" {
  depends_on = [
    google_project_iam_member.gke_hub_service_account_roles,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      echo "Waiting 30 seconds for IAM propagation..."
      sleep 30
      echo "✓ IAM propagation wait completed"
    EOT
  }
}

// ------------------------------------------------------------------
// GKE Hub Service Account
// ------------------------------------------------------------------

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
    null_resource.wait_for_api_propagation,
  ]
}

// ------------------------------------------------------------------
// GKE Hub Membership
// ------------------------------------------------------------------

resource "google_gke_hub_membership" "gke_cluster_membership" {
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
    google_container_node_pool.gke_node_pool,
    null_resource.wait_for_iam_propagation,
  ]
}
