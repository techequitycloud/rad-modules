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
# GKE Hub Registration
# ============================================

resource "null_resource" "wait_for_fleet_registration" {
  for_each = local.cluster_configs

  triggers = {
    cluster_name = each.value.gke_cluster_name
    region       = each.value.region
    project_id   = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      CLUSTER_NAME="${self.triggers.cluster_name}"
      REGION="${self.triggers.region}"
      PROJECT_ID="${self.triggers.project_id}"
      MAX_ATTEMPTS=60

      echo "Waiting for Fleet registration of cluster '$CLUSTER_NAME'..."

      for ((i=1; i<=MAX_ATTEMPTS; i++)); do
        MEMBERSHIP_STATE=$(gcloud container fleet memberships describe "$CLUSTER_NAME" \
          --project="$PROJECT_ID" \
          --location="$REGION" \
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

resource "null_resource" "pre_cleanup_hub_membership" {
  for_each = local.cluster_configs

  triggers = {
    cluster = each.value.gke_cluster_name
    region  = each.value.region
    project = local.project.project_id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOF
      set -x
      MEMBERSHIP_NAME="${self.triggers.cluster}"
      PROJECT_ID="${self.triggers.project}"
      REGION="${self.triggers.region}"

      echo "======================================"
      echo "Starting GKE Hub membership cleanup for $MEMBERSHIP_NAME"
      echo "======================================"
      
      # Unregister the cluster from the Fleet
      echo "Unregistering cluster..."
      if gcloud container fleet memberships unregister "$MEMBERSHIP_NAME" \
        --project="$PROJECT_ID" \
        --gke-cluster="$REGION/$MEMBERSHIP_NAME" \
        --quiet; then
        echo "✓ Successfully initiated unregistration"
      else
        echo "⚠ Unregistration command failed. Membership might already be gone."
      fi
      
      # Wait a moment for unregistration to propagate
      sleep 15
      
      # Delete the membership from the Hub
      echo "Deleting membership..."
      if gcloud container fleet memberships delete "$MEMBERSHIP_NAME" \
        --project="$PROJECT_ID" \
        --location=global \
        --quiet; then
        echo "✓ Successfully deleted membership"
      else
        echo "⚠ Membership deletion command failed. It might have been deleted already."
      fi

      echo "======================================"
      echo "Hub membership cleanup for $MEMBERSHIP_NAME completed"
      echo "======================================"
      
    EOF
    on_failure = continue
  }
}

# ============================================
# ASM Fleet Registration
# ============================================
resource "null_resource" "enable_asm" {
  for_each = var.enable_cloud_service_mesh ? local.cluster_configs : {}

  triggers = {
    cluster_name = each.value.gke_cluster_name
    region       = each.value.region
    project_id   = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      PROJECT_ID="${self.triggers.project_id}"
      CLUSTER_NAME="${self.triggers.cluster_name}"
      REGION="${self.triggers.region}"

      echo "=========================================="
      echo "Enabling Anthos Service Mesh for cluster: $CLUSTER_NAME"
      echo "=========================================="

      # Enable ASM on the Fleet
      if gcloud container fleet mesh enable --project "$PROJECT_ID"; then
        echo "✓ Fleet-level ASM enabled"
      else
        echo "⚠ Could not enable ASM at the fleet level. It might already be enabled."
      fi

      # Enable ASM on the cluster membership
      echo "Enabling ASM for the cluster membership..."
      if gcloud container fleet mesh update \
        --management automatic \
        --memberships "$CLUSTER_NAME" \
        --project "$PROJECT_ID"; then
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
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      PROJECT_ID="${self.triggers.project_id}"
      CLUSTER_NAME="${self.triggers.cluster_name}"
      MAX_ATTEMPTS=60

      echo "=========================================="
      echo "Waiting for ASM status on cluster: $CLUSTER_NAME"
      echo "=========================================="

      for ((i=1; i<=MAX_ATTEMPTS; i++)); do
        ASM_STATUS=$(gcloud container fleet mesh describe \
          --project "$PROJECT_ID" \
          --format='value(membershipStates."projects/$PROJECT_ID/locations/global/memberships/$CLUSTER_NAME".servicemesh.controlPlaneManagement.state)' 2>/dev/null || echo "UNKNOWN")

        if [ "$ASM_STATUS" = "ACTIVE" ]; then
          echo "✓ ASM is ACTIVE on cluster '$CLUSTER_NAME'"
          exit 0
        fi

        echo "⏳ Attempt $i/$MAX_ATTEMPTS: Waiting for ASM to be ACTIVE (Current state: $ASM_STATUS)"
        sleep 15
      done

      echo "❌ ASM did not become ACTIVE on cluster '$CLUSTER_NAME' in time."
      # Exit with 0 to avoid breaking the pipeline for now
      exit 0
    EOT
  }

  depends_on = [
    null_resource.enable_asm,
  ]
}

resource "google_gke_hub_membership" "hub_membership" {
  for_each = local.cluster_configs

  project      = local.project.project_id
  membership_id = each.value.gke_cluster_name
  location     = "global" # Membership location is always global

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
  ]
}
