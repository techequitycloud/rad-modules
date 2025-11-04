/**
 * Copyright 2020 Google LLC
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

locals {
  istio_version  = regex("^(.*?)-asm\\.\\d+$", var.cloud_service_mesh_version)[0]
  script_version = regex("^(\\d+\\.\\d+).*", var.cloud_service_mesh_version)[0]
  repo_dir       = "${path.module}/scripts/app/bank-of-anthos"
}

# ============================================
# NAMESPACES
# ============================================

resource "kubernetes_namespace" "istio_system" {
  count    = var.deploy_application ? 1 : 0
  provider = kubernetes.primary
  
  metadata {
    name = "istio-system"
  }
  
  timeouts {
    delete = "15m"
  }
  
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels,
    ]
  }
}

resource "kubernetes_namespace" "bank_of_anthos" {
  count    = var.deploy_application ? 1 : 0
  provider = kubernetes.primary
  
  metadata {
    name = "bank-of-anthos"
    labels = {
      "istio.io/rev" = "asm-managed"
    }
  }
  
  timeouts {
    delete = "15m"
  }
  
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels,
    ]
  }
  
  depends_on = [
    kubernetes_namespace.istio_system,
  ]
}

# ============================================
# CLEANUP RESOURCES (DESTROY-TIME)
# ============================================

# Pre-cleanup: Remove all app resources BEFORE namespace deletion
resource "null_resource" "pre_cleanup_app_resources" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    namespace_name = "bank-of-anthos"
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      echo "============================================"
      echo "Pre-cleanup: Removing application resources"
      echo "============================================"
      
      NAMESPACE="${self.triggers.namespace_name}"
      
      if ! kubectl get namespace "$NAMESPACE" 2>/dev/null; then
        echo "Namespace does not exist, skipping..."
        exit 0
      fi
      
      # Remove Istio labels to prevent webhook interference
      echo "Removing Istio labels from namespace..."
      kubectl label namespace "$NAMESPACE" istio.io/rev- istio-injection- 2>/dev/null || true
      
      # Delete all deployments first (this triggers graceful pod shutdown)
      echo "Deleting deployments..."
      kubectl delete deployments --all -n "$NAMESPACE" --timeout=60s 2>/dev/null || true
      
      # Delete all services
      echo "Deleting services..."
      kubectl delete services --all -n "$NAMESPACE" --timeout=30s 2>/dev/null || true
      
      # Delete ingress resources
      echo "Deleting ingress resources..."
      kubectl delete ingress --all -n "$NAMESPACE" --timeout=30s 2>/dev/null || true
      
      # Delete configmaps and secrets
      echo "Deleting configmaps and secrets..."
      kubectl delete configmaps --all -n "$NAMESPACE" --timeout=30s 2>/dev/null || true
      kubectl delete secrets --all -n "$NAMESPACE" --timeout=30s 2>/dev/null || true
      
      echo "✓ Application resources removed"
    EOT
    
    interpreter = ["/bin/bash", "-c"]
    on_failure  = continue
  }

  depends_on = [
    kubernetes_namespace.bank_of_anthos,
  ]
}

# Cleanup bank-of-anthos namespace with NEG finalizer fix
resource "null_resource" "cleanup_bank_of_anthos_namespace" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    namespace_name = "bank-of-anthos"
    pre_cleanup_id = null_resource.pre_cleanup_app_resources[0].id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      echo "============================================"
      echo "Cleaning up bank-of-anthos namespace"
      echo "============================================"
      
      NAMESPACE="${self.triggers.namespace_name}"
      
      if ! kubectl get namespace "$NAMESPACE" 2>/dev/null; then
        echo "Namespace does not exist, skipping..."
        exit 0
      fi
      
      # ===== CRITICAL FIX: Remove ServiceNetworkEndpointGroups (NEG) finalizers =====
      echo ""
      echo "Step 1: Removing finalizers from ServiceNetworkEndpointGroups..."
      
      if kubectl get crd servicenetworkendpointgroups.networking.gke.io 2>/dev/null; then
        kubectl get servicenetworkendpointgroups.networking.gke.io -n "$NAMESPACE" -o json 2>/dev/null | \
          jq -r '.items[] | .metadata.name' 2>/dev/null | \
          while read neg_name; do
            if [ -n "$neg_name" ]; then
              echo "  Removing finalizer from NEG: $neg_name"
              kubectl patch servicenetworkendpointgroups.networking.gke.io "$neg_name" -n "$NAMESPACE" \
                --type json \
                -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
            fi
          done
        
        # Force delete NEGs
        echo "  Force deleting ServiceNetworkEndpointGroups..."
        kubectl delete servicenetworkendpointgroups.networking.gke.io --all -n "$NAMESPACE" \
          --force --grace-period=0 --timeout=30s 2>/dev/null || true
        
        echo "✓ ServiceNetworkEndpointGroups cleaned up"
      else
        echo "  No ServiceNetworkEndpointGroups CRD found, skipping..."
      fi
      
      # ===== Remove finalizers from all other resources =====
      echo ""
      echo "Step 2: Removing finalizers from all remaining resources..."
      
      for resource in $(kubectl api-resources --verbs=list --namespaced -o name 2>/dev/null); do
        # Skip ServiceNetworkEndpointGroups as we already handled them
        if [ "$resource" = "servicenetworkendpointgroups.networking.gke.io" ]; then
          continue
        fi
        
        kubectl get "$resource" -n "$NAMESPACE" -o json 2>/dev/null | \
          jq -r '.items[] | select(.metadata.finalizers != null) | "\(.kind)/\(.metadata.name)"' 2>/dev/null | \
          while read item; do
            if [ -n "$item" ]; then
              resource_type=$(echo "$item" | cut -d'/' -f1)
              resource_name=$(echo "$item" | cut -d'/' -f2)
              echo "  Patching: $item"
              kubectl patch "$resource" "$resource_name" -n "$NAMESPACE" \
                --type json \
                -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
            fi
          done
      done
      
      echo "✓ Resource finalizers removed"
      
      # ===== Force delete remaining pods =====
      echo ""
      echo "Step 3: Force deleting remaining pods..."
      kubectl delete pods --all -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
      echo "✓ Pods deleted"
      
      # ===== Remove namespace finalizers =====
      echo ""
      echo "Step 4: Removing namespace finalizers..."
      
      # Method 1: Using finalize subresource
      kubectl get namespace "$NAMESPACE" -o json 2>/dev/null | \
        jq '.spec.finalizers = []' | \
        kubectl replace --raw "/api/v1/namespaces/$NAMESPACE/finalize" -f - 2>/dev/null || true
      
      # Method 2: Patch metadata finalizers
      kubectl patch namespace "$NAMESPACE" \
        --type json \
        -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
      
      # Method 3: Patch spec finalizers
      kubectl patch namespace "$NAMESPACE" \
        --type json \
        -p='[{"op": "remove", "path": "/spec/finalizers"}]' 2>/dev/null || true
      
      echo "✓ Namespace finalizers removed"
      
      # ===== Delete namespace =====
      echo ""
      echo "Step 5: Deleting namespace..."
      kubectl delete namespace "$NAMESPACE" --force --grace-period=0 --timeout=60s 2>/dev/null || true
      
      # ===== Wait for deletion with extended timeout =====
      echo ""
      echo "Step 6: Waiting for namespace deletion..."
      for i in {1..60}; do
        if ! kubectl get namespace "$NAMESPACE" 2>/dev/null; then
          echo ""
          echo "============================================"
          echo "✓ Namespace deleted successfully"
          echo "============================================"
          exit 0
        fi
        
        # Show status every 10 iterations
        if [ $((i % 10)) -eq 0 ]; then
          echo "  Still waiting... ($i/60)"
          kubectl get namespace "$NAMESPACE" -o jsonpath='{.status.conditions}' 2>/dev/null | jq -r '.[] | "\(.type): \(.status) - \(.message)"' 2>/dev/null || true
        fi
        
        sleep 2
      done
      
      # ===== Final check and warning =====
      if kubectl get namespace "$NAMESPACE" 2>/dev/null; then
        echo ""
        echo "============================================"
        echo "⚠️  WARNING: Namespace deletion timeout"
        echo "============================================"
        echo ""
        echo "Namespace status:"
        kubectl describe namespace "$NAMESPACE" 2>/dev/null || true
        echo ""
        echo "This is usually safe to ignore - GKE will eventually clean up the namespace."
        echo "Continuing with Terraform destroy..."
      fi
    EOT
    
    interpreter = ["/bin/bash", "-c"]
    on_failure  = continue
  }

  depends_on = [
    null_resource.pre_cleanup_app_resources,
    kubernetes_namespace.bank_of_anthos,
  ]
}

# Cleanup istio-system namespace (AFTER bank-of-anthos)
resource "null_resource" "cleanup_istio_system_namespace" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    namespace_name     = "istio-system"
    boa_cleanup_id     = null_resource.cleanup_bank_of_anthos_namespace[0].id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      echo "============================================"
      echo "Cleaning up istio-system namespace"
      echo "============================================"
      
      NAMESPACE="${self.triggers.namespace_name}"
      
      if ! kubectl get namespace "$NAMESPACE" 2>/dev/null; then
        echo "Namespace does not exist, skipping..."
        exit 0
      fi
      
      # Delete control plane revisions first
      echo "Deleting control plane revisions..."
      kubectl delete controlplanerevisions.mesh.cloud.google.com --all -n "$NAMESPACE" --timeout=60s 2>/dev/null || true
      
      # Delete mutating webhooks
      echo "Deleting Istio webhooks..."
      kubectl get mutatingwebhookconfigurations -o name 2>/dev/null | \
        grep -E "istio|istiod" | \
        xargs -r kubectl delete --timeout=30s 2>/dev/null || true
      
      # Delete validating webhooks
      kubectl get validatingwebhookconfigurations -o name 2>/dev/null | \
        grep -E "istio|istiod" | \
        xargs -r kubectl delete --timeout=30s 2>/dev/null || true
      
      # Remove finalizers from all resources
      echo "Removing finalizers from resources..."
      for resource in $(kubectl api-resources --verbs=list --namespaced -o name 2>/dev/null); do
        kubectl get "$resource" -n "$NAMESPACE" -o json 2>/dev/null | \
          jq -r '.items[] | select(.metadata.finalizers != null) | "\(.kind)/\(.metadata.name)"' 2>/dev/null | \
          while read item; do
            if [ -n "$item" ]; then
              resource_type=$(echo "$item" | cut -d'/' -f1)
              resource_name=$(echo "$item" | cut -d'/' -f2)
              echo "  Patching: $item"
              kubectl patch "$resource" "$resource_name" -n "$NAMESPACE" \
                --type json \
                -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
            fi
          done
      done
      
      # Force delete pods
      echo "Force deleting pods..."
      kubectl delete pods --all -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
      
      # Remove namespace finalizers
      echo "Removing namespace finalizers..."
      kubectl get namespace "$NAMESPACE" -o json 2>/dev/null | \
        jq '.spec.finalizers = []' | \
        kubectl replace --raw "/api/v1/namespaces/$NAMESPACE/finalize" -f - 2>/dev/null || true
      
      kubectl patch namespace "$NAMESPACE" \
        --type json \
        -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
      
      # Delete namespace
      echo "Deleting namespace..."
      kubectl delete namespace "$NAMESPACE" --timeout=60s 2>/dev/null || true
      
      # Wait for deletion
      echo "Waiting for namespace deletion..."
      for i in {1..30}; do
        if ! kubectl get namespace "$NAMESPACE" 2>/dev/null; then
          echo "✓ Namespace deleted successfully"
          exit 0
        fi
        sleep 2
      done
      
      echo "WARNING: Namespace deletion timeout, but continuing..."
    EOT
    
    interpreter = ["/bin/bash", "-c"]
    on_failure  = continue
  }

  depends_on = [
    null_resource.cleanup_bank_of_anthos_namespace,
    kubernetes_namespace.istio_system,
  ]
}

# ============================================
# SERVICE MESH READINESS CHECK
# ============================================

resource "null_resource" "wait_for_service_mesh" {
  count = var.deploy_application ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "============================================"
      echo "Waiting for Cloud Service Mesh to be ready"
      echo "============================================"
      
      # Step 1: Wait for the control plane revision to be reconciled
      echo ""
      echo "Step 1/5: Checking control plane revision status..."
      max_attempts=60
      attempt=0
      
      while [ $attempt -lt $max_attempts ]; do
        echo "Checking service mesh control plane status (attempt $((attempt+1))/$max_attempts)..."
        
        reconciled=$(kubectl get controlplanerevisions -n istio-system asm-managed -o jsonpath='{.status.conditions[?(@.type=="Reconciled")].status}' 2>/dev/null || echo "")
        stalled=$(kubectl get controlplanerevisions -n istio-system asm-managed -o jsonpath='{.status.conditions[?(@.type=="Stalled")].status}' 2>/dev/null || echo "")
        
        if [ "$reconciled" = "True" ] && [ "$stalled" = "False" ]; then
          echo "✓ Service mesh control plane is reconciled and ready!"
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
        echo "ERROR: Service mesh control plane did not become ready in time"
        kubectl get controlplanerevisions -n istio-system || true
        exit 1
      fi
      
      # Step 2: Wait for istiod deployment
      echo ""
      echo "Step 2/5: Checking istiod deployment status..."
      kubectl wait --for=condition=available --timeout=300s deployment -l app=istiod -n istio-system
      echo "✓ istiod deployment is ready"
      
      # Step 3: Wait for istiod pods
      echo ""
      echo "Step 3/5: Checking istiod pods..."
      kubectl wait --for=condition=ready --timeout=300s pods -l app=istiod -n istio-system
      echo "✓ istiod pods are ready"
      
      # Step 4: Wait for webhooks
      echo ""
      echo "Step 4/5: Checking Istio webhooks..."
      max_attempts=60
      attempt=0
      
      while [ $attempt -lt $max_attempts ]; do
        webhook_count=$(kubectl get mutatingwebhookconfigurations -o json 2>/dev/null | \
          jq '[.items[] | select(.metadata.name | test("istio|istiod"))] | length' 2>/dev/null || echo "0")
        
        if [ "$webhook_count" -gt 0 ] 2>/dev/null; then
          webhook_ready=$(kubectl get mutatingwebhookconfigurations -o json 2>/dev/null | \
            jq '[.items[] | select(.metadata.name | test("istio|istiod")) | .webhooks[] | select(.clientConfig.caBundle != null)] | length' 2>/dev/null || echo "0")
          
          if [ "$webhook_ready" -gt 0 ] 2>/dev/null; then
            echo "✓ Webhook(s) are ready with valid CA bundles"
            break
          fi
        fi
        
        echo "Waiting for webhooks (attempt $((attempt+1))/$max_attempts)..."
        attempt=$((attempt+1))
        sleep 5
      done
      
      # Step 5: Configure namespace
      echo ""
      echo "Step 5/5: Configuring namespace..."
      kubectl label namespace bank-of-anthos istio.io/rev=asm-managed --overwrite
      echo "✓ Namespace labeled"
      
      # Stabilization wait
      echo ""
      echo "Waiting 30 seconds for stabilization..."
      sleep 30
      
      echo ""
      echo "✓ Service mesh is fully ready"
    EOT
    
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    google_gke_hub_feature_membership.service_mesh_feature_member,
    kubernetes_namespace.istio_system,
    kubernetes_namespace.bank_of_anthos,
  ]
}

# ============================================
# APPLICATION DEPLOYMENT
# ============================================

# Clone repository
resource "null_resource" "git_clone" {
  count = var.deploy_application ? 1 : 0

  triggers = {
    service_mesh_ready = null_resource.wait_for_service_mesh[0].id
    repo_dir           = local.repo_dir
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Cloning Bank of Anthos repository..."
      
      REPO_DIR="${local.repo_dir}"
      
      if [ -d "$REPO_DIR" ]; then
        rm -rf "$REPO_DIR"
      fi
      
      mkdir -p "${path.module}/scripts/app"
      git clone --branch v0.6.6 --depth 1 https://github.com/GoogleCloudPlatform/bank-of-anthos.git "$REPO_DIR"
      
      echo "✓ Repository cloned"
    EOT
    
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    null_resource.wait_for_service_mesh,
  ]
}

# Verify mesh before deploy
resource "null_resource" "verify_mesh_before_deploy" {
  count = var.deploy_application ? 1 : 0

  triggers = {
    git_clone_id = null_resource.git_clone[0].id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Verifying service mesh before deployment..."
      
      kubectl get controlplanerevisions -n istio-system asm-managed
      kubectl get deployment -n istio-system -l app=istiod
      kubectl get pods -n istio-system -l app=istiod
      
      ns_label=$(kubectl get namespace bank-of-anthos -o jsonpath='{.metadata.labels.istio\.io/rev}')
      if [ "$ns_label" != "asm-managed" ]; then
        echo "ERROR: Namespace label incorrect"
        exit 1
      fi
      
      echo "✓ Service mesh verified"
    EOT
    
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    null_resource.git_clone,
  ]
}

# Application manifests
locals {
  boa_manifest_files  = var.deploy_application ? fileset("${path.module}/scripts/app/bank-of-anthos", "kubernetes-manifests/*.yaml") : []
  boa_jwt_secret_file = var.deploy_application ? fileset("${path.module}/scripts/app/bank-of-anthos", "extras/jwt/jwt-secret.yaml") : []
}

resource "null_resource" "boa_jwt_secret" {
  for_each = toset(local.boa_jwt_secret_file)
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Applying JWT secret: ${each.value}"
      kubectl apply -n bank-of-anthos -f "${path.module}/scripts/app/bank-of-anthos/${each.value}"
      echo "✓ JWT secret applied"
    EOT
  }

  depends_on = [
    null_resource.configure_kubectl,
    kubernetes_namespace.bank_of_anthos,
    null_resource.verify_mesh_before_deploy,
  ]
}

resource "null_resource" "boa_app" {
  for_each = toset(local.boa_manifest_files)

  provisioner "local-exec" {
    command = <<-EOT
      echo "Applying manifest: ${each.value}"
      kubectl apply -n bank-of-anthos -f "${path.module}/scripts/app/bank-of-anthos/${each.value}"
      echo "✓ Manifest applied"
    EOT
  }

  depends_on = [
    null_resource.configure_kubectl,
    null_resource.boa_jwt_secret,
    null_resource.verify_mesh_before_deploy,
  ]
}

# Additional resources (configmap, frontend_config, etc.)
resource "null_resource" "configmap" {
  count = var.deploy_application ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<'EOF'
      ${templatefile("${path.module}/templates/configmap.yaml.tpl", {})}
      EOF
    EOT
  }

  depends_on = [
    null_resource.configure_kubectl,
    kubernetes_namespace.istio_system,
    null_resource.verify_mesh_before_deploy,
  ]
}

resource "null_resource" "frontend_config" {
  count = var.deploy_application ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<'EOF'
      ${templatefile("${path.module}/templates/frontend_config.yaml.tpl", {
        APPLICATION_NAME      = "bank-of-anthos"
        APPLICATION_NAMESPACE = "bank-of-anthos"
      })}
      EOF
    EOT
  }

  depends_on = [
    null_resource.configure_kubectl,
    null_resource.boa_app,
  ]
}

resource "null_resource" "managed_certificate" {
  count = var.deploy_application ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<'EOF'
      ${templatefile("${path.module}/templates/managed_certificate.yaml.tpl", {
        APPLICATION_NAME      = "bank-of-anthos"
        APPLICATION_NAMESPACE = "bank-of-anthos"
        APPLICATION_DOMAIN    = "boa.${google_compute_global_address.glb.address}.sslip.io"
      })}
      EOF
    EOT
  }

  depends_on = [
    null_resource.configure_kubectl,
    null_resource.boa_app,
  ]
}

resource "null_resource" "backend_config" {
  count = var.deploy_application ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<'EOF'
      ${templatefile("${path.module}/templates/backend_config.yaml.tpl", {
        GCP_PROJECT           = local.project.project_id
        APPLICATION_NAME      = "bank-of-anthos"
        APPLICATION_NAMESPACE = "bank-of-anthos"
      })}
      EOF
    EOT
  }

  depends_on = [
    null_resource.configure_kubectl,
    null_resource.boa_app,
  ]
}

resource "null_resource" "nodeport_service" {
  count = var.deploy_application ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<'EOF'
      ${templatefile("${path.module}/templates/nodeport_service.yaml.tpl", {
        APPLICATION_NAME      = "bank-of-anthos"
        APPLICATION_NAMESPACE = "bank-of-anthos"
      })}
      EOF
    EOT
  }

  depends_on = [
    null_resource.configure_kubectl,
    null_resource.boa_app,
  ]
}

resource "null_resource" "ingress" {
  count = var.deploy_application ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<'EOF'
      ${templatefile("${path.module}/templates/ingress.yaml.tpl", {
        GCP_PROJECT           = local.project.project_id
        APPLICATION_NAME      = "bank-of-anthos"
        APPLICATION_REGION    = var.region
        APPLICATION_NAMESPACE = "bank-of-anthos"
        APPLICATION_DOMAIN    = "boa.${google_compute_global_address.glb.address}.sslip.io"
      })}
      EOF
    EOT
  }

  depends_on = [
    null_resource.configure_kubectl,
    null_resource.nodeport_service,
    null_resource.backend_config,
    null_resource.managed_certificate,
    null_resource.frontend_config,
  ]
}

# Verify sidecar injection
resource "null_resource" "verify_sidecar_injection" {
  count = var.deploy_application ? 1 : 0

  triggers = {
    ingress_id = null_resource.ingress[0].id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "Verifying sidecar injection..."
      
      kubectl wait --for=condition=available --timeout=600s deployment --all -n bank-of-anthos
      
      pods_without_sidecar=$(kubectl get pods -n bank-of-anthos -o json | jq -r '.items[] | select(.spec.containers | length < 2) | .metadata.name' || echo "")
      
      if [ -n "$pods_without_sidecar" ]; then
        echo "ERROR: Pods without sidecars: $pods_without_sidecar"
        exit 1
      fi
      
      echo "✓ All pods have sidecars injected"
    EOT
    
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    null_resource.ingress,
    null_resource.boa_app,
  ]
}

# Cleanup cloned repository
resource "null_resource" "cleanup_repo" {
  count = var.deploy_application ? 1 : 0

  triggers = {
    repo_dir            = local.repo_dir
    verify_injection_id = null_resource.verify_sidecar_injection[0].id
  }

  provisioner "local-exec" {
    command = <<-EOT
      REPO_DIR="${local.repo_dir}"
      
      if [ -d "$REPO_DIR" ]; then
        rm -rf "$REPO_DIR"
        echo "✓ Repository cleaned up"
      fi
    EOT
    
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    null_resource.verify_sidecar_injection,
  ]
}
