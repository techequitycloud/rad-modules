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
# VERIFY GKE HUB API IS ENABLED
# ============================================

resource "null_resource" "verify_gke_hub_api_activation_hub" {
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

# ============================================
# WAIT FOR API PROPAGATION
# ============================================

resource "null_resource" "wait_for_api_propagation" {
  depends_on = [null_resource.verify_gke_hub_api_activation_hub]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      PROJECT_ID="${local.project.project_id}"
      
      echo "Waiting for GKE Hub API backend to be ready..."
      end_time=$((SECONDS+120))

      while [ $SECONDS -lt $end_time ]; do
        # gcloud container fleet features list requires the gkehub backend to be
        # fully operational, not just the service registration to show as enabled.
        if gcloud container fleet features list \
           --project="$PROJECT_ID" \
           --format="value(name)" > /dev/null 2>&1; then
          echo "✓ GKE Hub API is fully propagated"
          exit 0
        fi
        echo "Waiting for GKE Hub API propagation..."
        sleep 10
      done

      echo "Error: Timed out waiting for GKE Hub API propagation"
      exit 1
    EOT
  }
}

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
    null_resource.wait_for_api_propagation,
  ]
}

# ============================================
# WAIT FOR IAM PROPAGATION
# ============================================

resource "null_resource" "wait_for_iam_propagation" {
  depends_on = [
    google_project_iam_member.gke_hub_service_account_roles,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      PROJECT_ID="${local.project.project_id}"

      echo "Waiting for IAM propagation..."
      end_time=$((SECONDS+120))

      while [ $SECONDS -lt $end_time ]; do
        # Poll the project IAM policy until the hub service account binding is visible.
        # IAM reads are eventually consistent; this exits as soon as the binding
        # has propagated rather than waiting a fixed 30 s regardless.
        if gcloud projects get-iam-policy "$PROJECT_ID" \
           --format="json" 2>/dev/null | \
           grep -q "gcp-sa-gkehub.iam.gserviceaccount.com"; then
          echo "✓ IAM propagation complete"
          exit 0
        fi
        echo "Waiting for IAM bindings to propagate..."
        sleep 10
      done

      echo "✓ IAM propagation wait completed (proceeding after timeout)"
      exit 0
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
      resource_link = "//container.googleapis.com/projects/${local.project.project_id}/locations/${var.gcp_region}/clusters/${var.gke_cluster}"
    }
  }
  
  authority {
    issuer = "https://container.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.gcp_region}/clusters/${var.gke_cluster}"
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
