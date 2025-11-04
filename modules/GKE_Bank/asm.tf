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
# Wait for API Activation
# ============================================
resource "time_sleep" "await_for_gke_hub_api_activation" {
  depends_on = [
    google_project_service.enabled_services,
  ]

  create_duration = "5m"
}

resource "google_gke_hub_feature" "service_mesh" {
  count       = var.enable_cloud_service_mesh ? 1 : 0
  project     = local.project.project_id
  name        = "servicemesh"
  location    = "global"
  fleet_default_member_config {
    mesh {
      management = "MANAGEMENT_AUTOMATIC"
    }
  }

  depends_on = [
    time_sleep.await_for_gke_hub_api_activation,
  ]
}

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
    google_container_cluster.gke_autopilot_cluster,
    google_container_cluster.gke_standard_cluster,
    google_gke_hub_membership.gke_cluster,
    google_gke_hub_feature.service_mesh,
  ]
}

# ============================================
# SERVICE MESH READINESS CHECK (MANAGED ASM)
# ============================================

resource "null_resource" "wait_for_service_mesh" {
  count = var.enable_cloud_service_mesh ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "============================================"
      echo "Waiting for Managed ASM to be ready"
      echo "============================================"
      
      # Step 1: Wait for the control plane revision to be reconciled
      echo ""
      echo "Step 1/3: Checking Managed ASM control plane status..."
      max_attempts=60
      attempt=0
      
      while [ $attempt -lt $max_attempts ]; do
        echo "Checking control plane revision (attempt $((attempt+1))/$max_attempts)..."
        
        reconciled=$(kubectl get controlplanerevisions -n istio-system asm-managed -o jsonpath='{.status.conditions[?(@.type=="Reconciled")].status}' 2>/dev/null || echo "")
        stalled=$(kubectl get controlplanerevisions -n istio-system asm-managed -o jsonpath='{.status.conditions[?(@.type=="Stalled")].status}' 2>/dev/null || echo "")
        
        if [ "$reconciled" = "True" ] && [ "$stalled" = "False" ]; then
          echo "✓ Managed ASM control plane is reconciled and ready!"
          kubectl get controlplanerevisions -n istio-system asm-managed
          break
        fi
        
        if [ -n "$reconciled" ]; then
          echo "Current status - Reconciled: $reconciled, Stalled: $stalled"
        else
          echo "Control plane revision not found yet..."
        fi
        
        attempt=$((attempt+1))
        sleep 10
      done
      
      if [ $attempt -eq $max_attempts ]; then
        echo "ERROR: Managed ASM control plane did not become ready in time"
        kubectl get controlplanerevisions -n istio-system || true
        exit 1
      fi
      
      # Step 2: Wait for the specific asm-managed webhook (IMPROVED)
      echo ""
      echo "Step 2/3: Checking Managed ASM webhook..."
      max_attempts=60
      attempt=0
      
      while [ $attempt -lt $max_attempts ]; do
        echo "Checking webhook (attempt $((attempt+1))/$max_attempts)..."
        
        # Check if the webhook exists
        if kubectl get mutatingwebhookconfigurations istiod-asm-managed &>/dev/null; then
          echo "  ✓ Webhook 'istiod-asm-managed' exists"
            
          # Verify webhook is actually configured
          webhook_count=$(kubectl get mutatingwebhookconfigurations istiod-asm-managed \
            -o jsonpath='{.webhooks[*].name}' 2>/dev/null | wc -w)
            
          echo "  ✓ Webhook configured with $webhook_count hook(s)"
          echo ""
          echo "Webhook details:"
          kubectl get mutatingwebhookconfigurations istiod-asm-managed
          break
        else
          echo "  ⚠ Webhook 'istiod-asm-managed' not found yet..."
        fi
        
        attempt=$((attempt+1))
        sleep 5
      done
      
      if [ $attempt -eq $max_attempts ]; then
        echo ""
        echo "ERROR: Managed ASM webhook did not become ready in time"
        echo ""
        echo "Available webhooks:"
        kubectl get mutatingwebhookconfigurations | grep -E "istio|istiod" || echo "None found"
        exit 1
      fi
      
      # Step 3: Verify namespace configuration
      echo ""
      echo "Step 3/3: Verifying namespace configuration..."
      
      ns_label=$(kubectl get namespace bank-of-anthos -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null || echo "")
      if [ "$ns_label" != "asm-managed" ]; then
        echo "Applying namespace label..."
        kubectl label namespace bank-of-anthos istio.io/rev=asm-managed --overwrite
      fi
      
      echo "✓ Namespace labeled with istio.io/rev=asm-managed"
      
      # Stabilization wait
      echo ""
      echo "Waiting 30 seconds for stabilization..."
      sleep 30
      
      echo ""
      echo "============================================"
      echo "✓ Managed ASM is fully ready"
      echo "============================================"
      echo ""
      echo "Summary:"
      echo "  - Control Plane: Managed (external to cluster)"
      echo "  - Revision: asm-managed"
      echo "  - Webhook: istiod-asm-managed (ready)"
      echo "  - Namespace: bank-of-anthos (labeled)"
      echo ""
      echo "Note: With Managed ASM, there are NO istiod pods in the cluster."
      echo "The control plane runs in Google's infrastructure."
    EOT
    
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    google_gke_hub_feature_membership.service_mesh_feature_member,
    kubernetes_namespace.bank_of_anthos,
  ]
}

# Verify mesh before deploy
resource "null_resource" "verify_mesh_before_deploy" {
  count = var.enable_cloud_service_mesh ? 1 : 0

  triggers = {
    git_clone_id = null_resource.git_clone[0].id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "============================================"
      echo "Verifying Managed ASM before deployment..."
      echo "============================================"
      
      # Verify repository exists
      REPO_DIR="${local.repo_dir}"
      if [ ! -d "$REPO_DIR" ]; then
        echo "ERROR: Repository not found at $REPO_DIR"
        exit 1
      fi
      echo "✓ Repository verified at: $REPO_DIR"
      
      # Check control plane revision
      kubectl get controlplanerevisions -n istio-system asm-managed
      
      # Verify webhooks exist
      webhook_count=$(kubectl get mutatingwebhookconfigurations 2>/dev/null | grep -c "istiod-asm-managed" || echo "0")
      if [ "$webhook_count" -eq 0 ]; then
        echo "ERROR: Managed ASM webhooks not found"
        exit 1
      fi
      echo "✓ Webhooks present: $webhook_count"
      
      # Verify namespace label
      ns_label=$(kubectl get namespace bank-of-anthos -o jsonpath='{.metadata.labels.istio\.io/rev}')
      if [ "$ns_label" != "asm-managed" ]; then
        echo "ERROR: Namespace label incorrect: $ns_label"
        exit 1
      fi
      echo "✓ Namespace label correct: $ns_label"
      
      echo ""
      echo "✓ Managed ASM verified and ready for deployment"
    EOT
    
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    null_resource.git_clone,
  ]
}

