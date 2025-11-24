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
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      PROJECT_ID="${local.project.project_id}"
      
      echo "Verifying Service Mesh API activation..."
      end_time=$((SECONDS+300))
      
      while [ $SECONDS -lt $end_time ]; do
        # Check mesh.googleapis.com
        if gcloud services list --enabled --project="$PROJECT_ID" \
           --filter="name:mesh.googleapis.com" \
           --format="value(name)" | grep -q "mesh.googleapis.com"; then
          echo "✓ Service Mesh API (mesh.googleapis.com) is enabled"
          
          # Also verify meshconfig.googleapis.com
          if gcloud services list --enabled --project="$PROJECT_ID" \
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
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      PROJECT_ID="${local.project.project_id}"
      
      echo "Verifying Service Mesh feature is active..."
      end_time=$((SECONDS+300))
      
      while [ $SECONDS -lt $end_time ]; do
        FEATURE_STATE=$(gcloud container hub features describe servicemesh \
          --project="$PROJECT_ID" \
          --format="value(resourceState.state)" 2>/dev/null || echo "NOT_FOUND")
        
        echo "Current feature state: $FEATURE_STATE"
        
        if [ "$FEATURE_STATE" = "ACTIVE" ]; then
          echo "✓ Service Mesh feature is ACTIVE"
          exit 0
        elif [ "$FEATURE_STATE" = "NOT_FOUND" ] || [ "$FEATURE_STATE" = "" ]; then
          echo "Service Mesh feature not found yet, waiting..."
        else
          echo "Service Mesh feature state: $FEATURE_STATE (waiting for ACTIVE)"
        fi
        
        sleep 15
      done
      
      echo "Timed out waiting for Service Mesh feature to be ACTIVE."
      echo "Final state: $FEATURE_STATE"
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
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      PROJECT_ID="${local.project.project_id}"
      CLUSTER_NAME="${var.gke_cluster}"
      
      echo "Verifying GKE Hub membership registration..."
      end_time=$((SECONDS+180))
      
      while [ $SECONDS -lt $end_time ]; do
        if gcloud container hub memberships list --project="$PROJECT_ID" \
           --format="value(name)" | grep -q "$CLUSTER_NAME"; then
          echo "✓ GKE Hub membership '$CLUSTER_NAME' is registered"
          
          # Also check membership state
          MEMBERSHIP_STATE=$(gcloud container hub memberships describe "$CLUSTER_NAME" \
            --project="$PROJECT_ID" \
            --format="value(state.code)" 2>/dev/null || echo "UNKNOWN")
          
          echo "Membership state: $MEMBERSHIP_STATE"
          
          if [ "$MEMBERSHIP_STATE" = "READY" ] || [ "$MEMBERSHIP_STATE" = "OK" ]; then
            echo "✓ Membership is in ready state"
            exit 0
          else
            echo "Waiting for membership to be ready (current: $MEMBERSHIP_STATE)..."
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
# Verify Mesh Status for Cluster (FIXED v2)
# ============================================
resource "null_resource" "verify_mesh_status" {
  count = var.enable_cloud_service_mesh ? 1 : 0
  
  depends_on = [
    google_gke_hub_feature_membership.service_mesh_feature_member,
    null_resource.verify_hub_membership,
  ]
  
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      PROJECT_ID="${local.project.project_id}"
      PROJECT_NUMBER="${local.project_number}"
      CLUSTER_NAME="${var.gke_cluster}"
      
      # Construct the full membership path
      MEMBERSHIP_PATH="projects/$PROJECT_NUMBER/locations/global/memberships/$CLUSTER_NAME"
      
      echo "Verifying Service Mesh configuration for cluster..."
      echo "Membership Path: $MEMBERSHIP_PATH"
      end_time=$((SECONDS+300))
      
      while [ $SECONDS -lt $end_time ]; do
        # Use direct path access in format string (no flatten/filter needed)
        CONTROL_PLANE_STATE=$(gcloud container hub features describe servicemesh \
          --project="$PROJECT_ID" \
          --format="value(membershipStates['$MEMBERSHIP_PATH'].servicemesh.controlPlaneManagement.state)" \
          2>/dev/null || echo "NOT_FOUND")
        
        echo "Control Plane State: $CONTROL_PLANE_STATE"
        
        # Check overall membership state
        MEMBERSHIP_STATE=$(gcloud container hub features describe servicemesh \
          --project="$PROJECT_ID" \
          --format="value(membershipStates['$MEMBERSHIP_PATH'].state.code)" \
          2>/dev/null || echo "NOT_FOUND")
        
        echo "Membership State: $MEMBERSHIP_STATE"
        
        # Check feature state
        FEATURE_STATE=$(gcloud container hub features describe servicemesh \
          --project="$PROJECT_ID" \
          --format="value(resourceState.state)" \
          2>/dev/null || echo "NOT_FOUND")
        
        echo "Feature State: $FEATURE_STATE"
        
        # Success condition: Control plane ACTIVE and membership OK
        if [ "$CONTROL_PLANE_STATE" = "ACTIVE" ] && \
           [ "$MEMBERSHIP_STATE" = "OK" ] && \
           [ "$FEATURE_STATE" = "ACTIVE" ]; then
          echo "✓ Service Mesh is fully configured and active!"
          echo "  ✓ Control Plane: $CONTROL_PLANE_STATE"
          echo "  ✓ Membership: $MEMBERSHIP_STATE"
          echo "  ✓ Feature: $FEATURE_STATE"
          exit 0
        fi
        
        if [ "$CONTROL_PLANE_STATE" = "NOT_FOUND" ] || \
           [ "$MEMBERSHIP_STATE" = "NOT_FOUND" ]; then
          echo "Mesh configuration not yet available, waiting..."
        else
          echo "Waiting for all components to be ready..."
        fi
        
        sleep 15
      done
      
      echo "❌ Timed out waiting for Service Mesh configuration."
      echo "Final states:"
      echo "  Control Plane: $CONTROL_PLANE_STATE"
      echo "  Membership: $MEMBERSHIP_STATE"
      echo "  Feature: $FEATURE_STATE"
      echo ""
      echo "=== Full Feature Description ==="
      gcloud container hub features describe servicemesh --project="$PROJECT_ID"
      exit 1
    EOT
  }

  triggers = {
    project_id     = local.project.project_id
    project_number = local.project_number
    cluster_name   = var.gke_cluster
    membership_id  = google_gke_hub_membership.gke_cluster.membership_id
  }
}

# ============================================
# SERVICE MESH READINESS CHECK (FIXED v2)
# ============================================
resource "null_resource" "wait_for_service_mesh" {
  count = var.enable_cloud_service_mesh ? 1 : 0
  
  depends_on = [
    null_resource.verify_mesh_status,
    kubernetes_namespace.bank_of_anthos,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      
      PROJECT_ID="${local.project.project_id}"
      PROJECT_NUMBER="${local.project_number}"
      REGION="${var.region}"
      CLUSTER_NAME="${var.gke_cluster}"
      
      # Construct the full membership path
      MEMBERSHIP_PATH="projects/$PROJECT_NUMBER/locations/global/memberships/$CLUSTER_NAME"
      
      echo "Waiting for ASM data plane to be ready..."
      echo "Membership Path: $MEMBERSHIP_PATH"
      end_time=$((SECONDS+900))  # 15 minutes
      
      while [ $SECONDS -lt $end_time ]; do
        # Check control plane state using direct map access
        CONTROL_PLANE_STATE=$(gcloud container hub features describe servicemesh \
          --project="$PROJECT_ID" \
          --format="value(membershipStates['$MEMBERSHIP_PATH'].servicemesh.controlPlaneManagement.state)" \
          2>/dev/null || echo "UNKNOWN")
        
        # Check data plane state
        DATA_PLANE_STATE=$(gcloud container hub features describe servicemesh \
          --project="$PROJECT_ID" \
          --format="value(membershipStates['$MEMBERSHIP_PATH'].servicemesh.dataPlaneManagement.state)" \
          2>/dev/null || echo "UNKNOWN")
        
        # Get control plane revision details
        REVISION_DETAILS=$(gcloud container hub features describe servicemesh \
          --project="$PROJECT_ID" \
          --format="value(membershipStates['$MEMBERSHIP_PATH'].servicemesh.controlPlaneManagement.details[0].details)" \
          2>/dev/null || echo "")
        
        echo "Control Plane: $CONTROL_PLANE_STATE | Data Plane: $DATA_PLANE_STATE"
        if [ -n "$REVISION_DETAILS" ]; then
          echo "Revision: $REVISION_DETAILS"
        fi
        
        # Success: Control plane is active
        if [ "$CONTROL_PLANE_STATE" = "ACTIVE" ]; then
          echo "✓ ASM Control Plane is ACTIVE!"
          echo "  Control Plane: $CONTROL_PLANE_STATE"
          echo "  Data Plane: $DATA_PLANE_STATE"
          
          # Check if data plane is also ready
          if [ "$DATA_PLANE_STATE" = "ACTIVE" ] || [ "$DATA_PLANE_STATE" = "READY" ]; then
            echo "✓ Data Plane is also ready!"
          else
            echo "ℹ Data Plane is $DATA_PLANE_STATE (will activate when workloads are deployed)"
          fi
          
          exit 0
        fi
        
        if [ "$CONTROL_PLANE_STATE" = "PROVISIONING" ]; then
          echo "⏳ Control plane is provisioning..."
        elif [ "$CONTROL_PLANE_STATE" = "UNKNOWN" ] || [ "$CONTROL_PLANE_STATE" = "NOT_FOUND" ]; then
          echo "⏳ Waiting for control plane to be created..."
        fi
        
        sleep 20
      done
      
      echo "❌ Timed out waiting for ASM to be ready."
      echo "Final states:"
      echo "  Control Plane: $CONTROL_PLANE_STATE"
      echo "  Data Plane: $DATA_PLANE_STATE"
      echo ""
      echo "=== Full Feature Description ==="
      gcloud container hub features describe servicemesh --project="$PROJECT_ID"
      exit 1
    EOT
  }

  triggers = {
    project_id     = local.project.project_id
    project_number = local.project_number
    region         = var.region
    cluster_name   = var.gke_cluster
    namespace      = kubernetes_namespace.bank_of_anthos[0].metadata[0].name
  }
}
