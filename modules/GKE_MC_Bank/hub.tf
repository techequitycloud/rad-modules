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
# Wait for API Activation
# ============================================
resource "time_sleep" "wait_for_gke_hub_api" {
  depends_on = [
    google_project_service.enabled_services,
  ]

  create_duration = "10m"
}

# ============================================
# Enable GKE Hub Service
# ============================================
resource "google_project_service" "gke_hub_service" {
  project = local.project.project_id
  service = "gkehub.googleapis.com"

  disable_on_destroy = false

  depends_on = [
    time_sleep.wait_for_gke_hub_api
  ]
}

# ============================================
# Grant roles to the GKE Hub service account
# ============================================
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
    google_container_cluster.gke_cluster,
    google_project_service.gke_hub_service,
  ]
}

# ============================================
# Pre-cleanup for Hub Membership
# ============================================
resource "null_resource" "pre_cleanup_hub_membership" {
  for_each = var.cluster_configs

  triggers = {
    cluster       = each.value.gke_cluster_name
    region        = each.value.region
    project       = local.project.project_id
    membership_id = each.value.gke_cluster_name
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOF
      set -e
      echo "======================================"
      echo "Pre-cleanup for Hub Membership: ${self.triggers.membership_id}"
      echo "======================================"
      
      # Try to unregister the membership
      gcloud container fleet memberships unregister ${self.triggers.membership_id} \
        --project=${self.triggers.project} \
        --gke-cluster=${self.triggers.region}/${self.triggers.cluster} \
        --quiet 2>/dev/null || true
      
      # Force delete if still exists
      gcloud container fleet memberships delete ${self.triggers.membership_id} \
        --project=${self.triggers.project} \
        --quiet 2>/dev/null || true
      
      echo "Pre-cleanup completed for Hub Membership: ${self.triggers.membership_id}"
      
      exit 0
    EOF
  }

  lifecycle {
    create_before_destroy = false
  }
}

# ============================================
# GKE Hub Membership
# ============================================
resource "google_gke_hub_membership" "gke_cluster" {
  for_each      = var.cluster_configs
  project       = local.project.project_id
  membership_id = each.value.gke_cluster_name
  
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/projects/${local.project.project_id}/locations/${each.value.region}/clusters/${each.value.gke_cluster_name}"
    }
  }
  
  authority {
    issuer = "https://container.googleapis.com/v1/projects/${local.project.project_id}/locations/${each.value.region}/clusters/${each.value.gke_cluster_name}"
  }

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [
    google_container_cluster.gke_cluster,
    google_project_iam_member.service_mesh_service_agent,
    google_project_iam_member.gke_hub_service_account_roles,
    google_project_service.gke_hub_service,
    null_resource.pre_cleanup_hub_membership,
  ]
}

# ============================================
# Wait for Fleet Synchronization
# ============================================
resource "time_sleep" "wait_for_fleet_registration" {
  for_each = var.cluster_configs

  depends_on = [
    google_gke_hub_feature_membership.service_mesh_feature_member,
    google_gke_hub_feature.multicluster_ingress,
    google_gke_hub_membership.gke_cluster,
  ]

  create_duration = "10m"
}
