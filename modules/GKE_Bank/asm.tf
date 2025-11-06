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
    command = <<-EOT
      set -e
      PROJECT_ID="${local.project.project_id}"
      
      echo "Verifying GKE Hub API activation..."
      end_time=$$((SECONDS+300))
      
      while [ $$SECONDS -lt $$end_time ]; do
        if gcloud services list --enabled --project="$$PROJECT_ID" \
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

  triggers = {
    project_id = local.project.project_id
  }
}

# ============================================
# Verify Service Mesh API Activation
# ============================================
resource "null_resource" "verify_mesh_api_activation" {
  count = var.enable_cloud_service_mesh ? 1 : 0
  
  depends_on = [
    google_project_service.enabled_services,
    null_resource.verify_gke_hub_api_activation,
  ]
  
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      PROJECT_ID="${local.project.project_id}"
      
      echo "Verifying Service Mesh API activation..."
      end_time=$$((SECONDS+300))
      
      while [ $$SECONDS -lt $$end_time ]; do
        # Check mesh.googleapis.com
        if gcloud services list --enabled --project="$$PROJECT_ID" \
           --filter="name:mesh.googleapis.com" \
           --format="value(name)" | grep -q "mesh.googleapis.com"; then
          echo "✓ Service Mesh API (mesh.googleapis.com) is enabled"
          
          # Also verify meshconfig.googleapis.com
          if gcloud services list --enabled --project="$$PROJECT_ID" \
             --filter="name:meshconfig.googleapis.com" \
             --format="value(name)" | grep -q "meshconfig.googleapis.com"; then
            echo "✓ Mesh Config API (meshconfig.googleapis.com) is enabled"
            exit 0
          else
            echo "Waiting for Mesh Config API..."
          fi
        else
          echo "Waiting for Service Mesh API..."
        fi
        sleep 10
      done
      
      echo "Timed out waiting for Service Mesh APIs to be enabled."
      exit 1
    EOT
  }

  triggers = {
    project_id = local.project.project_id
  }
}

# ============================================
# Service Mesh Feature
# ============================================
resource "google_gke_hub_feature" "service_mesh" {
  count    = var.enable_cloud_service_mesh ? 1 : 0
  project  = local.project.project_id
  name     = "servicemesh"
  location = "global"
  
  fleet_default_member_config {
    mesh {
      management = "MANAGEMENT_AUTOMATIC"
    }
  }

  depends_on = [
    null_resource.verify_gke_hub_api_activation,
    null_resource.verify_mesh_api_activation,
  ]
}

# ============================================
# Verify Service Mesh Feature is Active
# ============================================
resource "null_resource" "verify_mesh_feature_active" {
  count = var.enable_cloud_service_mesh ? 1 : 0
  
  depends_on = [
    google_gke_hub_feature.service_mesh,
  ]
  
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      PROJECT_ID="${local.project.project_id}"
      
      echo "Verifying Service Mesh feature is active..."
      end_time=$$((SECONDS+300))
      
      while [ $$SECONDS -lt $$end_time ]; do
        FEATURE_STATE=$$(gcloud container hub features describe servicemesh \
          --project="$$PROJECT_ID" \
          --format="value(state.state)" 2>/dev/null || echo "NOT_FOUND")
        
        echo "Current feature state: $$FEATURE_STATE"
        
        if [ "$$FEATURE_STATE" = "ACTIVE" ]; then
          echo "✓ Service Mesh feature is ACTIVE"
          exit 0
        elif [ "$$FEATURE_STATE" = "NOT_FOUND" ]; then
          echo "Service Mesh feature not found yet, waiting..."
        else
          echo "Service Mesh feature state: $$FEATURE_STATE (waiting for ACTIVE)"
        fi
        
        sleep 15
      done
      
      echo "Timed out waiting for Service Mesh feature to be ACTIVE."
      echo "Final state: $$FEATURE_STATE"
      exit 1
    EOT
  }

  triggers = {
    project_id  = local.project.project_id
    feature_id  = google_gke_hub_feature.service_mesh[0].name
  }
}

# ============================================
# Service Mesh Feature Membership
# ============================================
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
    null_resource.verify_mesh_feature_active,
  ]
}

# ============================================
# Verify Hub Membership is Registered
# ============================================
resource "null_resource" "verify_hub_membership" {
  count = var.enable_cloud_service_mesh ? 1 : 0
  
  depends_on = [
    google_gke_hub_membership.gke_cluster,
  ]
  
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      PROJECT_ID="${local.project.project_id}"
      CLUSTER_NAME="${var.gke_cluster}"
      
      echo "Verifying GKE Hub membership registration..."
      end_time=$$((SECONDS+180))
      
      while [ $$SECONDS -lt $$end_time ]; do
        if gcloud container hub memberships list --project="$$PROJECT_ID" \
           --format="value(name)" | grep -q "$$CLUSTER_NAME"; then
          echo "✓ GKE Hub membership '$$CLUSTER_NAME' is registered"
          
          # Also check membership state
          MEMBERSHIP_STATE=$$(gcloud container hub memberships describe "$$CLUSTER_NAME" \
            --project="$$PROJECT_ID" \
            --format="value(state.code)" 2>/dev/null || echo "UNKNOWN")
          
          echo "Membership state: $$MEMBERSHIP_STATE"
          
          if [ "$$MEMBERSHIP_STATE" = "READY" ] || [ "$$MEMBERSHIP_STATE" = "OK" ]; then
            echo "✓ Membership is in ready state"
            exit 0
          else
            echo "Waiting for membership to be ready (current: $$MEMBERSHIP_STATE)..."
          fi
        else
          echo "Waiting for hub membership registration..."
        fi
        sleep 10
      done
      
      echo "Timed out waiting for hub membership to be ready."
      exit 1
    EOT
  }

  triggers = {
    project_id   = local.project.project_id
    cluster_name = var.gke_cluster
    membership_id = google_gke_hub_membership.gke_cluster.membership_id
  }
}

# ============================================
# Verify Mesh Status for Cluster
# ============================================
resource "null_resource" "verify_mesh_status" {
  count = var.enable_cloud_service_mesh ? 1 : 0
  
  depends_on = [
    google_gke_hub_feature_membership.service_mesh_feature_member,
    null_resource.verify_hub_membership,
  ]
  
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      PROJECT_ID="${local.project.project_id}"
      PROJECT_NUMBER="${local.project_number}"
      REGION="${var.region}"
      CLUSTER_NAME="${var.gke_cluster}"
      
      echo "Verifying Service Mesh status for cluster..."
      end_time=$$((SECONDS+600))
      
      while [ $$SECONDS -lt $$end_time ]; do
        # Get the mesh state for this specific membership
        MESH_STATE=$$(gcloud container hub features describe servicemesh \
          --project="$$PROJECT_ID" \
          --format="value(membershipStates.projects/$$PROJECT_NUMBER/locations/$$REGION/memberships/$$CLUSTER_NAME.state.code)" \
          2>/dev/null || echo "NOT_FOUND")
        
        echo "Mesh state for cluster: $$MESH_STATE"
        
        if [ "$$MESH_STATE" = "OK" ] || [ "$$MESH_STATE" = "ACTIVE" ]; then
          echo "✓ Service Mesh is ready for cluster $$CLUSTER_NAME"
          exit 0
        elif [ "$$MESH_STATE" = "" ] || [ "$$MESH_STATE" = "NOT_FOUND" ]; then
          echo "Mesh state not yet available, waiting..."
        else
          echo "Current mesh state: $$MESH_STATE (waiting for OK/ACTIVE)"
        fi
        
        sleep 20
      done
      
      echo "Timed out waiting for Service Mesh to be ready for cluster."
      echo "Final mesh state: $$MESH_STATE"
      exit 1
    EOT
  }

  triggers = {
    project_id     = local.project.project_id
    project_number = local.project_number
    region         = var.region
    cluster_name   = var.gke_cluster
    membership_id  = google_gke_hub_membership.gke_cluster.membership_id
  }
}

# ============================================
# SERVICE MESH READINESS CHECK (MANAGED ASM)
# ============================================

resource "null_resource" "wait_for_service_mesh" {
  count = var.enable_cloud_service_mesh ? 1 : 0
  
  depends_on = [
    null_resource.verify_mesh_status,
    kubernetes_namespace.bank_of_anthos,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      PROJECT_ID="${local.project.project_id}"
      REGION="${var.region}"
      CLUSTER_NAME="${var.gke_cluster}"
      
      # Get cluster credentials
      echo "Getting cluster credentials..."
      gcloud container clusters get-credentials "$$CLUSTER_NAME" \
        --region="$$REGION" \
        --project="$$PROJECT_ID"
      
      echo "Waiting for ASM control plane to be ready..."
      end_time=$$((SECONDS+600))
      
      while [ $$SECONDS -lt $$end_time ]; do
        # Check if istio-system namespace exists
        if ! kubectl get namespace istio-system >/dev/null 2>&1; then
          echo "Waiting for istio-system namespace to be created..."
          sleep 15
          continue
        fi
        
        echo "✓ istio-system namespace exists"
        
        # Check for control plane revision
        if ! kubectl get controlplanerevision -n istio-system >/dev/null 2>&1; then
          echo "Waiting for control plane revision to be created..."
          sleep 15
          continue
        fi
        
        # Get the reconciliation status
        status=$$(kubectl get controlplanerevision -n istio-system \
          -o=jsonpath='{.items[?(@.spec.type=="managed")].status.conditions[?(@.type=="Reconciled")].status}' 2>/dev/null || echo "")
        
        if [ "$$status" = "True" ]; then
          echo "✓ ASM control plane is ready and reconciled"
          
          # Verify istiod deployment is ready
          if kubectl get deployment -n istio-system -l app=istiod >/dev/null 2>&1; then
            echo "✓ Istiod deployment found"
            kubectl wait --for=condition=available --timeout=60s \
              deployment -n istio-system -l app=istiod 2>/dev/null || true
          fi
          
          exit 0
        else
          echo "Control plane reconciliation status: $$status (waiting for True)"
        fi
        
        sleep 15
      done
      
      echo "Timed out waiting for ASM control plane to be ready."
      echo "Current status: $$status"
      
      # Debug information
      echo "=== Debug Information ==="
      kubectl get all -n istio-system 2>/dev/null || echo "Could not get istio-system resources"
      kubectl get controlplanerevision -n istio-system -o yaml 2>/dev/null || echo "Could not get control plane revision"
      
      exit 1
    EOT
  }

  triggers = {
    project_id   = local.project.project_id
    region       = var.region
    cluster_name = var.gke_cluster
    namespace    = kubernetes_namespace.bank_of_anthos[0].metadata[0].name
  }
}
