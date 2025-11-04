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
    google_container_cluster.gke_autopilot_cluster,
    google_container_cluster.gke_standard_cluster,
  ]
}

resource "time_sleep" "wait_for_iam_propagation" {
  create_duration = "60s"

  depends_on = [
    google_project_iam_member.gke_hub_service_account_roles,
  ]
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
    google_container_cluster.gke_autopilot_cluster,
    google_container_cluster.gke_standard_cluster,
    google_container_node_pool.preemptible_nodes,
    google_project_iam_member.gke_hub_service_account_roles,
    time_sleep.wait_for_iam_propagation,
  ]
}

# ============================================
# CLEANUP RESOURCES (DESTROY-TIME)
# ============================================

# Step 0: Delete Network Endpoint Groups (NEGs) FIRST
resource "null_resource" "cleanup_negs" {
  triggers = {
    project_id   = local.project.project_id
    cluster_name = var.gke_cluster
    region       = var.region
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      echo "============================================"
      echo "Step 0: Cleaning up Network Endpoint Groups"
      echo "============================================"
      
      PROJECT_ID="${self.triggers.project_id}"
      
      # Configure kubectl
      echo "Configuring kubectl..."
      gcloud container clusters get-credentials ${self.triggers.cluster_name} \
        --region ${self.triggers.region} \
        --project $PROJECT_ID 2>/dev/null || true
      
      # ===== Delete Kubernetes Services (creates NEGs) =====
      echo ""
      echo "Deleting Kubernetes Services..."
      kubectl delete svc --all --all-namespaces --timeout=60s 2>/dev/null || true
      
      # ===== Delete Ingress resources (creates NEGs) =====
      echo ""
      echo "Deleting Ingress resources..."
      kubectl delete ingress --all --all-namespaces --timeout=60s 2>/dev/null || true
      
      # Wait for Kubernetes to trigger NEG deletion
      echo ""
      echo "Waiting 30 seconds for Kubernetes to delete NEGs..."
      sleep 30
      
      # ===== Force delete any remaining NEGs =====
      echo ""
      echo "Force deleting remaining Network Endpoint Groups..."
      
      # Delete zonal NEGs
      for zone in us-central1-a us-central1-b us-central1-c us-central1-f; do
        echo "Checking zone: $zone"
        
        NEGS=$(gcloud compute network-endpoint-groups list \
          --zones=$zone \
          --project=$PROJECT_ID \
          --format="value(name)" 2>/dev/null || true)
        
        if [ -n "$NEGS" ]; then
          echo "$NEGS" | while read neg; do
            if [ -n "$neg" ]; then
              echo "  Deleting NEG: $neg in $zone"
              gcloud compute network-endpoint-groups delete "$neg" \
                --zone=$zone \
                --project=$PROJECT_ID \
                --quiet 2>/dev/null || true
            fi
          done
        else
          echo "  No NEGs found in $zone"
        fi
      done
      
      # Delete global NEGs
      echo ""
      echo "Checking for global NEGs..."
      GLOBAL_NEGS=$(gcloud compute network-endpoint-groups list \
        --global \
        --project=$PROJECT_ID \
        --format="value(name)" 2>/dev/null || true)
      
      if [ -n "$GLOBAL_NEGS" ]; then
        echo "$GLOBAL_NEGS" | while read neg; do
          if [ -n "$neg" ]; then
            echo "  Deleting global NEG: $neg"
            gcloud compute network-endpoint-groups delete "$neg" \
              --global \
              --project=$PROJECT_ID \
              --quiet 2>/dev/null || true
          fi
        done
      fi
      
      # ===== Delete Backend Services =====
      echo ""
      echo "Deleting Backend Services..."
      BACKEND_SERVICES=$(gcloud compute backend-services list \
        --project=$PROJECT_ID \
        --format="value(name)" 2>/dev/null || true)
      
      if [ -n "$BACKEND_SERVICES" ]; then
        echo "$BACKEND_SERVICES" | while read bs; do
          if [ -n "$bs" ]; then
            echo "  Deleting backend service: $bs"
            gcloud compute backend-services delete "$bs" \
              --global \
              --project=$PROJECT_ID \
              --quiet 2>/dev/null || true
          fi
        done
      fi
      
      # ===== Delete Forwarding Rules =====
      echo ""
      echo "Deleting Forwarding Rules..."
      
      # Global forwarding rules
      GLOBAL_FRS=$(gcloud compute forwarding-rules list \
        --global \
        --project=$PROJECT_ID \
        --format="value(name)" 2>/dev/null || true)
      
      if [ -n "$GLOBAL_FRS" ]; then
        echo "$GLOBAL_FRS" | while read fr; do
          if [ -n "$fr" ]; then
            echo "  Deleting global forwarding rule: $fr"
            gcloud compute forwarding-rules delete "$fr" \
              --global \
              --project=$PROJECT_ID \
              --quiet 2>/dev/null || true
          fi
        done
      fi
      
      # Regional forwarding rules
      for region in us-central1 us-east1 us-west1; do
        REGIONAL_FRS=$(gcloud compute forwarding-rules list \
          --regions=$region \
          --project=$PROJECT_ID \
          --format="value(name)" 2>/dev/null || true)
        
        if [ -n "$REGIONAL_FRS" ]; then
          echo "$REGIONAL_FRS" | while read fr; do
            if [ -n "$fr" ]; then
              echo "  Deleting regional forwarding rule: $fr in $region"
              gcloud compute forwarding-rules delete "$fr" \
                --region=$region \
                --project=$PROJECT_ID \
                --quiet 2>/dev/null || true
            fi
          done
        fi
      done
      
      # ===== Final verification =====
      echo ""
      echo "Verifying NEG cleanup..."
      REMAINING_NEGS=$(gcloud compute network-endpoint-groups list \
        --project=$PROJECT_ID \
        --format="value(name)" 2>/dev/null | wc -l || echo "0")
      
      if [ "$REMAINING_NEGS" -eq 0 ]; then
        echo "✓ All NEGs deleted successfully"
      else
        echo "⚠️  Warning: $REMAINING_NEGS NEG(s) still exist"
        gcloud compute network-endpoint-groups list --project=$PROJECT_ID 2>/dev/null || true
      fi
      
      echo ""
      echo "Waiting 30 seconds for GCP to finalize NEG deletion..."
      sleep 30
      
      echo ""
      echo "✓ NEG cleanup complete"
    EOT
    
    interpreter = ["/bin/bash", "-c"]
    on_failure  = continue
  }

  depends_on = [
    google_gke_hub_membership.gke_cluster,
  ]
}

# Step 1: Cleanup before membership deletion
resource "null_resource" "cleanup_before_membership_delete" {
  triggers = {
    membership_id  = google_gke_hub_membership.gke_cluster.membership_id
    project_id     = local.project.project_id
    cluster_name   = var.gke_cluster
    region         = var.region
    project_number = local.project_number
    neg_cleanup_id = null_resource.cleanup_negs.id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      echo "============================================"
      echo "Step 1: Pre-deletion Cleanup"
      echo "============================================"
      
      FLEET_SA="service-${self.triggers.project_number}@gcp-sa-gkehub.iam.gserviceaccount.com"
      
      for role in roles/gkehub.serviceAgent roles/iam.serviceAccountAdmin roles/iam.workloadIdentityPoolAdmin; do
        gcloud projects add-iam-policy-binding ${self.triggers.project_id} \
          --member="serviceAccount:$FLEET_SA" \
          --role="$role" \
          --condition=None \
          --quiet --no-user-output-enabled 2>/dev/null || true
      done
      
      echo "Waiting 30 seconds for IAM propagation..."
      sleep 30
      
      gcloud container clusters get-credentials ${self.triggers.cluster_name} \
        --region ${self.triggers.region} \
        --project ${self.triggers.project_id} 2>/dev/null || true
      
      echo "Disabling service mesh feature..."
      gcloud container fleet mesh update \
        --membership ${self.triggers.membership_id} \
        --management manual \
        --project ${self.triggers.project_id} \
        --quiet 2>/dev/null || true
      
      sleep 15
      
      kubectl delete validatingwebhookconfigurations -l app=istiod --ignore-not-found=true --timeout=30s 2>/dev/null || true
      kubectl delete mutatingwebhookconfigurations -l app=istiod --ignore-not-found=true --timeout=30s 2>/dev/null || true
      
      kubectl get crd -o name 2>/dev/null | grep -E "istio.io|mesh.cloud.google.com" | \
        xargs -r kubectl delete --timeout=30s 2>/dev/null || true
      
      echo "✓ Pre-deletion cleanup complete"
    EOT
    
    interpreter = ["/bin/bash", "-c"]
    on_failure  = continue
  }

  depends_on = [
    google_gke_hub_membership.gke_cluster,
    null_resource.cleanup_negs,
  ]
}

# Step 2: Cleanup membership resources
resource "null_resource" "cleanup_membership_resources" {
  triggers = {
    membership_id  = google_gke_hub_membership.gke_cluster.membership_id
    project_id     = local.project.project_id
    cluster_name   = var.gke_cluster
    region         = var.region
    cleanup_before = null_resource.cleanup_before_membership_delete.id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      echo "============================================"
      echo "Step 2: Cleaning up GKE Hub Membership Resources"
      echo "============================================"
      
      gcloud container clusters get-credentials ${self.triggers.cluster_name} \
        --region ${self.triggers.region} \
        --project ${self.triggers.project_id} 2>/dev/null || true
      
      if kubectl get crd memberships.hub.gke.io 2>/dev/null; then
        kubectl get memberships.hub.gke.io -A -o json 2>/dev/null | \
          jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | \
          while read namespace name; do
            if [ -n "$namespace" ] && [ -n "$name" ]; then
              kubectl patch membership "$name" -n "$namespace" \
                --type json \
                -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
            fi
          done
      fi
      
      kubectl delete memberships.hub.gke.io --all -A \
        --ignore-not-found=true \
        --timeout=30s 2>/dev/null || true
      
      sleep 10
      echo "✓ Membership resources cleanup complete"
    EOT
    
    interpreter = ["/bin/bash", "-c"]
    on_failure  = continue
  }

  depends_on = [
    google_gke_hub_membership.gke_cluster,
    null_resource.cleanup_before_membership_delete,
  ]
}

# Step 3: Final cleanup - unregister membership
resource "null_resource" "unregister_membership" {
  triggers = {
    membership_id     = google_gke_hub_membership.gke_cluster.membership_id
    project_id        = local.project.project_id
    cluster_name      = var.gke_cluster
    region            = var.region
    cleanup_resources = null_resource.cleanup_membership_resources.id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      echo "============================================"
      echo "Step 3: Unregistering GKE Hub Membership"
      echo "============================================"
      
      gcloud container fleet memberships unregister ${self.triggers.membership_id} \
        --project=${self.triggers.project_id} \
        --gke-cluster="${self.triggers.region}/${self.triggers.cluster_name}" \
        --quiet 2>/dev/null || true
      
      gcloud container fleet memberships delete ${self.triggers.membership_id} \
        --project=${self.triggers.project_id} \
        --quiet 2>/dev/null || true
      
      for i in {1..30}; do
        if ! gcloud container fleet memberships describe ${self.triggers.membership_id} \
          --project=${self.triggers.project_id} 2>/dev/null; then
          echo "✓ Membership deleted successfully"
          exit 0
        fi
        sleep 2
      done
      
      echo "⚠️  Membership deletion timeout (continuing anyway)"
    EOT
    
    interpreter = ["/bin/bash", "-c"]
    on_failure  = continue
  }

  depends_on = [
    google_gke_hub_membership.gke_cluster,
    null_resource.cleanup_membership_resources,
  ]
}
