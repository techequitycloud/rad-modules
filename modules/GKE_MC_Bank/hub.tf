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
resource "time_sleep" "allow_10_minutes_for_gke_hub_api_activation" {
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
    time_sleep.allow_10_minutes_for_gke_hub_api_activation
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
    google_container_cluster.gke_autopilot_cluster_1,
    google_container_cluster.gke_standard_cluster_1,
    google_container_cluster.gke_autopilot_cluster_2,
    google_container_cluster.gke_standard_cluster_2,
    google_project_service.gke_hub_service,
  ]
}

# ============================================
# Pre-cleanup for Hub Membership 1
# ============================================
resource "null_resource" "pre_cleanup_hub_membership_1" {
  triggers = {
    cluster       = var.gke_cluster_1
    region        = var.region_1
    project       = local.project.project_id
    membership_id = var.gke_cluster_1
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
# Pre-cleanup for Hub Membership 2
# ============================================
resource "null_resource" "pre_cleanup_hub_membership_2" {
  triggers = {
    cluster       = var.gke_cluster_2
    region        = var.region_2
    project       = local.project.project_id
    membership_id = var.gke_cluster_2
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
# GKE Hub Membership for Cluster 1
# ============================================
resource "google_gke_hub_membership" "gke_cluster_1" {
  project       = local.project.project_id
  membership_id = var.gke_cluster_1
  
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/projects/${local.project.project_id}/locations/${var.region_1}/clusters/${var.gke_cluster_1}"
    }
  }
  
  authority {
    issuer = "https://container.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region_1}/clusters/${var.gke_cluster_1}"
  }

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [
    google_container_cluster.gke_autopilot_cluster_1,
    google_container_cluster.gke_standard_cluster_1,
    google_project_iam_member.service_mesh_service_agent,
    google_project_iam_member.gke_hub_service_account_roles,
    google_project_service.gke_hub_service,
    null_resource.pre_cleanup_hub_membership_1,
  ]
}

# ============================================
# GKE Hub Membership for Cluster 2
# ============================================
resource "google_gke_hub_membership" "gke_cluster_2" {
  project       = local.project.project_id
  membership_id = var.gke_cluster_2
  
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/projects/${local.project.project_id}/locations/${var.region_2}/clusters/${var.gke_cluster_2}"
    }
  }
  
  authority {
    issuer = "https://container.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region_2}/clusters/${var.gke_cluster_2}"
  }

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [
    google_container_cluster.gke_autopilot_cluster_2,
    google_container_cluster.gke_standard_cluster_2,
    google_project_iam_member.service_mesh_service_agent,
    google_project_iam_member.gke_hub_service_account_roles,
    google_project_service.gke_hub_service,
    null_resource.pre_cleanup_hub_membership_2,
  ]
}

# ============================================
# Wait for Fleet Synchronization - Cluster 1
# ============================================
resource "time_sleep" "allow_10_minutes_for_fleet_synchronization_1" {
  depends_on = [
    google_gke_hub_feature_membership.service_mesh_feature_member_1,
    google_gke_hub_feature.multicluster_ingress,
    google_gke_hub_membership.gke_cluster_1,
  ]

  create_duration = "10m"
}

# ============================================
# Wait for Fleet Synchronization - Cluster 2
# ============================================
resource "time_sleep" "allow_10_minutes_for_fleet_synchronization_2" {
  depends_on = [
    google_gke_hub_feature_membership.service_mesh_feature_member_2,
    google_gke_hub_feature.multicluster_ingress,
    google_gke_hub_membership.gke_cluster_2,
  ]

  create_duration = "10m"
}