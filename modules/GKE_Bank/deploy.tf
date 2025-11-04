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
  # ✅ No fileset() here - files discovered at runtime in bash scripts
}

# ============================================
# NAMESPACES
# ============================================

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

  depends_on = [
    google_container_cluster.gke_autopilot_cluster,
    google_container_cluster.gke_standard_cluster,
  ]

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels,
    ]
  }
}

# ============================================
# CLEANUP RESOURCES (DESTROY-TIME)
# ============================================

# Cleanup cloned repository during destroy
resource "null_resource" "cleanup_repo_on_destroy" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    repo_dir = local.repo_dir
    # This ensures the resource is recreated on every apply
    always_run = timestamp()
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      echo "============================================"
      echo "Cleaning up cloned repository (destroy)"
      echo "============================================"
      
      REPO_DIR="${self.triggers.repo_dir}"
      
      if [ -d "$REPO_DIR" ]; then
        echo "Removing directory: $REPO_DIR"
        rm -rf "$REPO_DIR"
        echo "✓ Repository cleaned up successfully"
      else
        echo "⚠ Repository directory not found (may have been cleaned up already)"
      fi
    EOT
    
    interpreter = ["/bin/bash", "-c"]
    on_failure  = continue
  }
}

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
      echo ""
      echo "Wait for 30 seconds"
      sleep 30
      
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

# ============================================
# APPLICATION DEPLOYMENT
# ============================================

# Clone repository - runs every time with fresh clone
resource "null_resource" "git_clone" {
  count = var.deploy_application ? 1 : 0

  triggers = {
    service_mesh_ready = null_resource.wait_for_service_mesh[0].id
    repo_dir           = local.repo_dir
    # Force re-clone on every apply
    always_run         = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "============================================"
      echo "Cloning Bank of Anthos repository..."
      echo "============================================"
      
      REPO_DIR="${local.repo_dir}"
      
      # Remove existing directory if present
      if [ -d "$REPO_DIR" ]; then
        echo "Removing existing repository..."
        rm -rf "$REPO_DIR"
      fi
      
      # Create parent directory
      mkdir -p "${path.module}/scripts/app"
      
      # Clone repository
      echo "Cloning from GitHub..."
      git clone --branch v0.6.6 --depth 1 \
        https://github.com/GoogleCloudPlatform/bank-of-anthos.git \
        "$REPO_DIR"
      
      # Verify clone was successful
      if [ ! -d "$REPO_DIR/kubernetes-manifests" ]; then
        echo "ERROR: kubernetes-manifests directory not found after clone"
        exit 1
      fi
      
      if [ ! -f "$REPO_DIR/extras/jwt/jwt-secret.yaml" ]; then
        echo "ERROR: JWT secret file not found after clone"
        exit 1
      fi
      
      echo ""
      echo "✓ Repository cloned successfully"
      echo "  Location: $REPO_DIR"
      echo "  Manifests: $(ls -1 $REPO_DIR/kubernetes-manifests/*.yaml 2>/dev/null | wc -l) files"
    EOT
    
    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      echo "============================================"
      echo "Cleaning up cloned repository (from git_clone)"
      echo "============================================"
      
      REPO_DIR="${self.triggers.repo_dir}"
      
      if [ -d "$REPO_DIR" ]; then
        echo "Removing directory: $REPO_DIR"
        rm -rf "$REPO_DIR"
        echo "✓ Repository cleaned up successfully"
      else
        echo "⚠ Repository directory not found"
      fi
    EOT
    
    interpreter = ["/bin/bash", "-c"]
    on_failure  = continue
  }

  depends_on = [
    null_resource.wait_for_service_mesh,
    null_resource.cleanup_repo_on_destroy,
  ]
}

# Deploy JWT Secret
resource "null_resource" "boa_jwt_secret" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    verify_mesh_id = null_resource.verify_mesh_before_deploy[0].id
    git_clone_id   = null_resource.git_clone[0].id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "============================================"
      echo "Deploying JWT Secret"
      echo "============================================"
      
      JWT_FILE="${local.repo_dir}/extras/jwt/jwt-secret.yaml"
      
      if [ ! -f "$JWT_FILE" ]; then
        echo "ERROR: JWT secret file not found at $JWT_FILE"
        echo "Repository contents:"
        ls -la "${local.repo_dir}/extras/jwt/" || echo "Directory not found"
        exit 1
      fi
      
      echo "Applying JWT secret from: $JWT_FILE"
      kubectl apply -n bank-of-anthos -f "$JWT_FILE"
      
      echo "✓ JWT secret deployed"
    EOT
    
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    null_resource.configure_kubectl,
    kubernetes_namespace.bank_of_anthos,
    null_resource.verify_mesh_before_deploy,
    null_resource.git_clone,
  ]
}

# Deploy Bank of Anthos Application
resource "null_resource" "boa_app" {
  count = var.deploy_application ? 1 : 0

  triggers = {
    jwt_secret_id = null_resource.boa_jwt_secret[0].id
    git_clone_id  = null_resource.git_clone[0].id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "============================================"
      echo "Deploying Bank of Anthos Application"
      echo "============================================"
      
      MANIFESTS_DIR="${local.repo_dir}/kubernetes-manifests"
      
      # Verify manifests directory exists
      if [ ! -d "$MANIFESTS_DIR" ]; then
        echo "ERROR: Manifests directory not found at $MANIFESTS_DIR"
        echo "Repository structure:"
        ls -la "${local.repo_dir}/" || echo "Repository not found"
        exit 1
      fi
      
      echo "Found manifests directory: $MANIFESTS_DIR"
      echo ""
      
      # Count and list manifest files
      manifest_count=$(ls -1 "$MANIFESTS_DIR"/*.yaml 2>/dev/null | wc -l)
      if [ "$manifest_count" -eq 0 ]; then
        echo "ERROR: No YAML files found in $MANIFESTS_DIR"
        exit 1
      fi
      
      echo "Found $manifest_count manifest files:"
      ls -1 "$MANIFESTS_DIR"/*.yaml | xargs -n1 basename
      echo ""
      
      # Apply all YAML files
      echo "Applying manifests..."
      for manifest in "$MANIFESTS_DIR"/*.yaml; do
        if [ -f "$manifest" ]; then
          manifest_name=$(basename "$manifest")
          echo "  → Applying: $manifest_name"
          kubectl apply -n bank-of-anthos -f "$manifest"
        fi
      done
      
      echo ""
      echo "✓ All application manifests deployed"
      echo ""
      echo "Deployed resources:"
      kubectl get deployments,services,configmaps -n bank-of-anthos
    EOT
    
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    null_resource.configure_kubectl,
    null_resource.boa_jwt_secret,
    null_resource.git_clone,
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

resource "null_resource" "verify_sidecar_injection" {
  count = var.enable_cloud_service_mesh ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "============================================"
      echo "Verifying sidecar injection setup..."
      echo "============================================"
      
      # Check if namespace is properly labeled
      echo ""
      echo "Step 1: Checking namespace label..."
      ns_label=$(kubectl get namespace bank-of-anthos -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null || echo "")
      
      if [ "$ns_label" = "asm-managed" ]; then
        echo "✓ Namespace has correct label: istio.io/rev=asm-managed"
      else
        echo "ERROR: Namespace label is '$ns_label', expected 'asm-managed'"
        exit 1
      fi
      
      # Check if deployments exist before waiting
      echo ""
      echo "Step 2: Checking for deployments..."
      deployment_count=$(kubectl get deployments -n bank-of-anthos --no-headers 2>/dev/null | wc -l)
      
      if [ "$deployment_count" -eq 0 ]; then
        echo "⚠ No deployments found yet in bank-of-anthos namespace"
        echo "  This is expected if application hasn't been deployed yet"
        echo "  Skipping deployment wait..."
      else
        echo "✓ Found $deployment_count deployment(s)"
        echo "  Waiting for deployments to be ready..."
        
        kubectl wait --for=condition=available --timeout=600s \
          deployment --all -n bank-of-anthos || {
          echo "WARNING: Some deployments not ready yet"
          kubectl get deployments -n bank-of-anthos
        }
      fi
      
      # Test sidecar injection with a temporary pod
      echo ""
      echo "Step 3: Testing sidecar injection..."
      
      # Create test pod
      cat <<'TESTPOD' | kubectl apply -f -
      apiVersion: v1
      kind: Pod
      metadata:
        name: sidecar-injection-test
        namespace: bank-of-anthos
        labels:
          test: sidecar-injection
      spec:
        containers:
        - name: test
          image: gcr.io/google-samples/hello-app:1.0
          command: ["sleep", "30"]
      TESTPOD
      
      # Wait for pod to be created
      echo "  Waiting for test pod to be created..."
      kubectl wait --for=condition=Ready --timeout=60s \
        pod/sidecar-injection-test -n bank-of-anthos 2>/dev/null || true
      
      sleep 5
      
      # Check container count
      container_count=$(kubectl get pod sidecar-injection-test -n bank-of-anthos \
        -o jsonpath='{.spec.containers[*].name}' 2>/dev/null | wc -w)
      
      container_names=$(kubectl get pod sidecar-injection-test -n bank-of-anthos \
        -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || echo "")
      
      echo "  Test pod containers: $container_names"
      
      # Cleanup test pod
      kubectl delete pod sidecar-injection-test -n bank-of-anthos --ignore-not-found=true &>/dev/null || true
      
      if [ "$container_count" -ge 2 ]; then
        echo "✓ Sidecar injection is working! (found $container_count containers)"
      else
        echo "ERROR: Sidecar injection failed (found only $container_count container)"
        echo "  Expected: test + istio-proxy"
        echo "  Found: $container_names"
        exit 1
      fi
      
      # Check existing pods if any
      echo ""
      echo "Step 4: Checking existing pods..."
      pod_count=$(kubectl get pods -n bank-of-anthos --no-headers 2>/dev/null | wc -l)
      
      if [ "$pod_count" -gt 0 ]; then
        echo "✓ Found $pod_count pod(s) in namespace"
        
        pods_without_sidecar=$(kubectl get pods -n bank-of-anthos -o json 2>/dev/null | \
          jq -r '.items[] | select(.spec.containers | length < 2) | .metadata.name' || echo "")
        
        if [ -n "$pods_without_sidecar" ]; then
          echo "⚠ WARNING: Some pods don't have sidecars:"
          echo "$pods_without_sidecar"
          echo ""
          echo "  These pods may need to be restarted to get sidecars injected:"
          echo "  kubectl rollout restart deployment --all -n bank-of-anthos"
        else
          echo "✓ All existing pods have sidecars injected"
        fi
      else
        echo "⚠ No pods found yet (this is normal if app not deployed)"
      fi
      
      echo ""
      echo "============================================"
      echo "✓ Sidecar injection verification complete"
      echo "============================================"
    EOT
    
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    null_resource.wait_for_service_mesh,
    null_resource.boa_app,
  ]
}
