/**
 * Copyright 2023 Google LLC
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
# Service Identity for GKE Hub
# ============================================
resource "google_project_service_identity" "gke_hub_sa" {
  provider = google-beta
  project  = local.project.project_id
  service  = "gkehub.googleapis.com"
}

# ============================================
# IAM Bindings for GKE Hub Service Account
# ============================================
resource "google_project_iam_member" "hub_service_account_gke_access" {
  project = local.project.project_id
  role    = "roles/gkehub.serviceAgent"
  member  = "serviceAccount:${google_project_service_identity.gke_hub_sa.email}"

  depends_on = [
    google_project_service_identity.gke_hub_sa
  ]
}

resource "google_project_iam_member" "hub_service_account_container_viewer" {
  project = local.project.project_id
  role    = "roles/container.viewer"
  member  = "serviceAccount:${google_project_service_identity.gke_hub_sa.email}"

  depends_on = [
    google_project_service_identity.gke_hub_sa
  ]
}

# ============================================
# GKE Hub Membership
# ============================================
resource "google_gke_hub_membership" "hub_membership" {
  for_each = local.cluster_configs

  project       = local.project.project_id
  membership_id = each.value.gke_cluster_name
  location      = "global"

  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.gke_cluster[each.key].id}"
    }
  }

  authority {
    issuer = "https://container.googleapis.com/v1/${google_container_cluster.gke_cluster[each.key].id}"
  }

  depends_on = [
    google_container_cluster.gke_cluster,
    google_project_iam_member.hub_service_account_gke_access,
    google_project_iam_member.hub_service_account_container_viewer,
  ]

  # ✅ FIXED: Proper cleanup provisioner
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    when        = destroy
    command     = <<-EOF
      set +e  # Don't exit on errors
      
      PROJECT_ID="${self.project}"
      MEMBERSHIP_NAME="${self.membership_id}"
      
      echo "=========================================="
      echo "Cleaning up GKE Hub Membership: $MEMBERSHIP_NAME"
      echo "=========================================="
      
      # Step 1: Check and disable ASM if enabled
      echo "Step 1: Checking for ASM configuration..."
      if gcloud container fleet mesh describe \
         --project="$PROJECT_ID" \
         --format='get(membershipStates)' 2>/dev/null | grep -q "$MEMBERSHIP_NAME"; then
        
        echo "ASM detected. Disabling for membership..."
        gcloud container fleet mesh update \
          --management manual \
          --memberships "$MEMBERSHIP_NAME" \
          --project="$PROJECT_ID" \
          --quiet 2>&1 || echo "⚠ Could not disable ASM"
        
        sleep 15
      else
        echo "✓ No ASM configuration found"
      fi
      
      # Step 2: Check if MCI feature exists and disable it
      echo ""
      echo "Step 2: Checking for Multi-cluster Ingress..."
      if gcloud container fleet features describe multiclusteringress \
         --project="$PROJECT_ID" 2>/dev/null | grep -q "$MEMBERSHIP_NAME"; then
        
        echo "MCI detected. Disabling with force..."
        gcloud alpha container hub ingress disable \
          --project="$PROJECT_ID" \
          --force \
          --quiet 2>&1 || echo "⚠ Could not disable MCI"
        
        sleep 10
      else
        echo "✓ No MCI configuration found"
      fi
      
      # Step 3: Unregister cluster from Fleet
      echo ""
      echo "Step 3: Unregistering cluster from Fleet..."
      if gcloud container fleet memberships describe "$MEMBERSHIP_NAME" \
         --project="$PROJECT_ID" \
         --location=global &>/dev/null; then
        
        gcloud container fleet memberships delete "$MEMBERSHIP_NAME" \
          --project="$PROJECT_ID" \
          --location=global \
          --quiet 2>&1 | grep -v "NOT_FOUND" || echo "✓ Membership already deleted"
      else
        echo "✓ Membership already removed"
      fi
      
      # Step 4: Verify cleanup
      echo ""
      echo "Step 4: Verifying cleanup..."
      sleep 5
      
      if gcloud container fleet memberships describe "$MEMBERSHIP_NAME" \
         --project="$PROJECT_ID" \
         --location=global &>/dev/null; then
        echo "⚠ WARNING: Membership still exists"
      else
        echo "✓ Membership confirmed deleted"
      fi
      
      echo ""
      echo "=========================================="
      echo "Cleanup completed for: $MEMBERSHIP_NAME"
      echo "=========================================="
      
      # Always exit 0 to not block Terraform destroy
      exit 0
    EOF
  }

  lifecycle {
    create_before_destroy = false
  }
}

# ============================================
# Wait for Fleet Registration
# ============================================
resource "null_resource" "wait_for_fleet_registration" {
  for_each = local.cluster_configs

  triggers = {
    cluster_name  = each.value.gke_cluster_name
    region        = each.value.region
    project_id    = local.project.project_id
    membership_id = google_gke_hub_membership.hub_membership[each.key].id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e

      CLUSTER_NAME="${self.triggers.cluster_name}"
      PROJECT_ID="${self.triggers.project_id}"
      MAX_ATTEMPTS=60

      echo "=========================================="
      echo "Waiting for Fleet registration of cluster '$CLUSTER_NAME'..."
      echo "=========================================="

      for ((i=1; i<=MAX_ATTEMPTS; i++)); do
        MEMBERSHIP_STATE=$(gcloud container fleet memberships describe "$CLUSTER_NAME" \
          --project="$PROJECT_ID" \
          --location="global" \
          --format='value(state.code)' 2>/dev/null || echo "NOT_FOUND")

        if [ "$MEMBERSHIP_STATE" = "READY" ]; then
          echo "✓ Fleet membership for '$CLUSTER_NAME' is READY"
          exit 0
        fi

        echo "⏳ Attempt $i/$MAX_ATTEMPTS: Membership not ready (State: $MEMBERSHIP_STATE)"
        sleep 10
      done

      echo "❌ Fleet membership for '$CLUSTER_NAME' did not become READY in time"
      exit 1
    EOT
  }

  depends_on = [
    google_gke_hub_membership.hub_membership,
  ]
}

# ============================================
# Enable Anthos Service Mesh
# ============================================
resource "null_resource" "enable_asm" {
  for_each = var.enable_cloud_service_mesh ? local.cluster_configs : {}

  triggers = {
    cluster_name  = each.value.gke_cluster_name
    region        = each.value.region
    project_id    = local.project.project_id
    membership_id = google_gke_hub_membership.hub_membership[each.key].id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e

      PROJECT_ID="${self.triggers.project_id}"
      CLUSTER_NAME="${self.triggers.cluster_name}"

      echo "=========================================="
      echo "Enabling Anthos Service Mesh for cluster: $CLUSTER_NAME"
      echo "=========================================="

      # Enable ASM on the Fleet (idempotent)
      echo "Enabling Fleet-level ASM..."
      if gcloud container fleet mesh enable --project "$PROJECT_ID" 2>&1 | tee /tmp/asm_enable.log; then
        echo "✓ Fleet-level ASM enabled"
      else
        if grep -q "already enabled" /tmp/asm_enable.log; then
          echo "✓ Fleet-level ASM already enabled"
        else
          echo "⚠ Warning: Could not enable ASM at the fleet level"
        fi
      fi

      # Wait a bit for the feature to be fully enabled
      sleep 10

      # Enable ASM on the cluster membership
      echo "Enabling ASM for the cluster membership..."
      if gcloud container fleet mesh update \
        --management automatic \
        --memberships "$CLUSTER_NAME" \
        --project "$PROJECT_ID" \
        --quiet; then
        echo "✓ ASM successfully enabled for membership '$CLUSTER_NAME'"
      else
        echo "❌ Failed to enable ASM for membership '$CLUSTER_NAME'"
        exit 1
      fi

      echo "=========================================="
      echo "ASM enabled for cluster: $CLUSTER_NAME"
      echo "=========================================="
    EOT
  }

  depends_on = [
    google_gke_hub_membership.hub_membership,
    null_resource.wait_for_fleet_registration,
  ]
}

# ============================================
# Wait for Service Mesh to be Ready
# ============================================
resource "null_resource" "wait_for_service_mesh" {
  for_each = var.enable_cloud_service_mesh ? local.cluster_configs : {}

  triggers = {
    cluster_name = each.value.gke_cluster_name
    project_id   = local.project.project_id
    asm_trigger  = null_resource.enable_asm[each.key].id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e

      PROJECT_ID="${self.triggers.project_id}"
      CLUSTER_NAME="${self.triggers.cluster_name}"
      MAX_ATTEMPTS=60

      echo "=========================================="
      echo "Waiting for ASM to be configured on cluster: $CLUSTER_NAME"
      echo "=========================================="

      for ((i=1; i<=MAX_ATTEMPTS; i++)); do
        # Check if mesh is enabled and membership is configured
        MESH_ENABLED=$(gcloud container fleet mesh describe \
          --project="$PROJECT_ID" \
          --format='get(membershipStates)' 2>/dev/null | grep -c "$CLUSTER_NAME" || echo "0")

        if [ "$MESH_ENABLED" != "0" ]; then
          echo "✓ ASM is configured for cluster '$CLUSTER_NAME'"
          
          # Get the actual state for logging
          gcloud container fleet mesh describe \
            --project="$PROJECT_ID" \
            --format=json 2>/dev/null | \
            jq -r --arg cluster "$CLUSTER_NAME" \
            '.membershipStates | to_entries[] | select(.key | contains($cluster)) | 
            "State: \(.value.servicemesh.controlPlaneManagement.state // "N/A")"' || true
          
          exit 0
        fi

        echo "⏳ Attempt $i/$MAX_ATTEMPTS: Waiting for ASM configuration..."
        sleep 15
      done

      echo "⚠ ASM configuration not detected for cluster '$CLUSTER_NAME' within timeout."
      echo "   This may be normal if ASM takes longer to provision."
      echo "   Continuing anyway - verify ASM status manually if needed."
      exit 0
    EOT
  }

  depends_on = [
    null_resource.enable_asm,
  ]
}

# ============================================
# Cleanup Fleet-level ASM (runs after all memberships)
# ============================================
resource "null_resource" "cleanup_fleet_asm" {
  count = var.enable_cloud_service_mesh ? 1 : 0

  triggers = {
    project_id = local.project.project_id
    # Track all membership IDs to ensure this runs after they're all destroyed
    membership_ids = join(",", [for k, v in local.cluster_configs : k])
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    when        = destroy
    command     = <<-EOF
      set +e  # Don't exit on errors
      
      PROJECT_ID="${self.triggers.project_id}"

      echo "=========================================="
      echo "Checking Fleet-level ASM status"
      echo "=========================================="

      # Wait a bit for membership deletions to propagate
      sleep 10

      # Check if any memberships still have ASM enabled
      REMAINING_MEMBERS=$(gcloud container fleet mesh describe \
        --project="$PROJECT_ID" \
        --format='get(membershipStates)' 2>/dev/null | wc -l || echo "0")

      echo "Remaining memberships with ASM: $REMAINING_MEMBERS"

      if [ "$REMAINING_MEMBERS" = "0" ] || [ -z "$REMAINING_MEMBERS" ]; then
        echo "No memberships with ASM found. Disabling Fleet-level ASM..."
        
        if gcloud container fleet mesh disable \
          --project="$PROJECT_ID" \
          --force \
          --quiet 2>&1; then
          echo "✓ Fleet-level ASM disabled"
        else
          echo "⚠ Could not disable Fleet-level ASM (may already be disabled)"
        fi
      else
        echo "⚠ $REMAINING_MEMBERS memberships still have ASM enabled"
        echo "   Skipping Fleet-level ASM disable"
      fi

      echo "=========================================="
      echo "Fleet-level ASM cleanup completed"
      echo "=========================================="
      
      # Always exit 0
      exit 0
    EOF
  }

  depends_on = [
    google_gke_hub_membership.hub_membership,
    null_resource.enable_asm,
  ]
}
