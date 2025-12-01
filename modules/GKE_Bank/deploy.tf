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

# ============================================
# LOCALS
# ============================================

locals {
  bank_of_anthos_version = "v0.6.7"
  release_url            = "https://github.com/GoogleCloudPlatform/bank-of-anthos/archive/refs/tags/${local.bank_of_anthos_version}.tar.gz"
  download_path          = "${path.module}/.terraform/bank-of-anthos"
  extracted_path         = "${local.download_path}/bank-of-anthos-${trimprefix(local.bank_of_anthos_version, "v")}"
  manifests_path         = "${local.extracted_path}/kubernetes-manifests"
  jwt_secret_path        = "${local.extracted_path}/extras/jwt/jwt-secret.yaml"
}

# ============================================
# DOWNLOAD AND EXTRACT RELEASE
# ============================================

# Download and extract Bank of Anthos release
resource "null_resource" "download_bank_of_anthos" {
  count = var.deploy_application ? 1 : 0

  triggers = {
    version       = local.bank_of_anthos_version
    download_path = local.download_path
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      echo "=========================================="
      echo "Downloading Bank of Anthos ${local.bank_of_anthos_version}..."
      echo "=========================================="
      mkdir -p ${local.download_path}
      
      # Download only if not already downloaded
      if [ ! -f ${local.download_path}/release.tar.gz ]; then
        echo "Downloading release archive..."
        curl -L -o ${local.download_path}/release.tar.gz ${local.release_url}
      else
        echo "Release archive already exists, skipping download..."
      fi
      
      echo "Extracting archive..."
      # Remove old extraction if exists
      rm -rf ${local.extracted_path}
      tar -xzf ${local.download_path}/release.tar.gz -C ${local.download_path}
      
      echo ""
      echo "✓ Download and extraction complete!"
      echo "Files extracted to: ${local.extracted_path}"
      echo ""
      
      # Verify extraction
      echo "Verifying extracted files..."
      if [ ! -d "${local.extracted_path}" ]; then
        echo "❌ Extraction failed - directory not found"
        exit 1
      fi
      
      if [ ! -f "${local.extracted_path}/extras/jwt/jwt-secret.yaml" ]; then
        echo "❌ JWT secret file not found after extraction"
        ls -la ${local.extracted_path}/extras/jwt/ || echo "JWT directory not found"
        exit 1
      fi
      
      if [ ! -d "${local.extracted_path}/kubernetes-manifests" ]; then
        echo "❌ Manifests directory not found after extraction"
        exit 1
      fi
      
      echo "✓ All required files verified:"
      echo "  - JWT secret: ${local.extracted_path}/extras/jwt/jwt-secret.yaml"
      echo "  - Manifests: ${local.extracted_path}/kubernetes-manifests"
      ls -la ${local.extracted_path}/extras/jwt/
      echo ""
      echo "Manifest files:"
      ls -la ${local.extracted_path}/kubernetes-manifests/ | head -10
    EOT
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    when       = destroy
    command    = "rm -rf ${self.triggers.download_path}"
    on_failure = continue
  }
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
    google_container_cluster.gke_cluster,
  ]

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels,
    ]
  }
}

# ============================================
# APPLICATION DEPLOYMENT
# ============================================

# ============================================
# Deploy Bank of Anthos Application
# ============================================
resource "null_resource" "deploy_bank_of_anthos" {
  count = var.deploy_application ? 1 : 0

  triggers = {
    cluster_name     = google_container_cluster.gke_cluster.name
    cluster_endpoint = google_container_cluster.gke_cluster.endpoint
    version          = local.bank_of_anthos_version
    namespace        = kubernetes_namespace.bank_of_anthos[0].metadata[0].name
    region           = var.gcp_region
    project_id       = local.project.project_id
    manifests_path   = local.manifests_path
    jwt_secret_path  = local.jwt_secret_path
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      
      NAMESPACE="${self.triggers.namespace}"
      CLUSTER_NAME="${self.triggers.cluster_name}"
      REGION="${self.triggers.region}"
      PROJECT_ID="${self.triggers.project_id}"
      JWT_SECRET_PATH="${self.triggers.jwt_secret_path}"
      MANIFESTS_PATH="${self.triggers.manifests_path}"
      
      echo "=========================================="
      echo "Deploying Bank of Anthos Application"
      echo "=========================================="
      
      # Verify files exist BEFORE starting deployment
      echo ""
      echo "Pre-deployment verification..."
      if [ ! -f "$JWT_SECRET_PATH" ]; then
        echo "❌ CRITICAL: JWT secret file not found at: $JWT_SECRET_PATH"
        echo "Current directory: $(pwd)"
        echo "Listing .terraform directory:"
        ls -la .terraform/ || echo "No .terraform directory"
        ls -la .terraform/bank-of-anthos/ || echo "No bank-of-anthos directory"
        exit 1
      fi
      
      if [ ! -d "$MANIFESTS_PATH" ]; then
        echo "❌ CRITICAL: Manifests directory not found at: $MANIFESTS_PATH"
        exit 1
      fi
      
      echo "✓ All required files verified"
      echo "  - JWT secret: $JWT_SECRET_PATH"
      echo "  - Manifests: $MANIFESTS_PATH"
      
      # Get cluster credentials
      echo ""
      echo "Getting cluster credentials..."
      gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID"
      
      # Verify namespace exists and is Active
      echo ""
      echo "Verifying namespace '$NAMESPACE'..."
      max_retries=5
      retry_count=0
      
      while [ $retry_count -lt $max_retries ]; do
        NAMESPACE_STATUS=$(kubectl get namespace "$NAMESPACE" \
          -o jsonpath='{.status.phase}' 2>/dev/null || echo "NOT_FOUND")
        
        if [ "$NAMESPACE_STATUS" = "Active" ]; then
          echo "✓ Namespace '$NAMESPACE' is Active"
          break
        elif [ "$NAMESPACE_STATUS" = "NOT_FOUND" ]; then
          echo "⏳ Waiting for namespace to be created... (Attempt $((retry_count + 1))/$max_retries)"
        else
          echo "⏳ Namespace status: $NAMESPACE_STATUS (Attempt $((retry_count + 1))/$max_retries)"
        fi
        
        retry_count=$((retry_count + 1))
        
        if [ $retry_count -lt $max_retries ]; then
          sleep 5
        fi
      done
      
      if [ "$NAMESPACE_STATUS" != "Active" ]; then
        echo "❌ Failed to verify namespace after $max_retries attempts"
        exit 1
      fi
      
      # Verify ASM injection label (if Service Mesh is enabled)
      echo ""
      echo "Checking ASM injection configuration..."
      ASM_LABEL=$(kubectl get namespace "$NAMESPACE" \
        -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null || echo "")
      
      if [ -n "$ASM_LABEL" ]; then
        echo "✓ ASM injection label found: $ASM_LABEL"
      else
        echo "ℹ No ASM injection label (Service Mesh may not be enabled)"
      fi
      
      # Apply JWT secret (idempotent - works whether secret exists or not)
      echo ""
      echo "Applying JWT secret..."
      kubectl apply -f "$JWT_SECRET_PATH" -n "$NAMESPACE" --server-side --force-conflicts 2>&1 | \
        grep -v "Warning: resource secrets/jwt-key is missing" || true
      echo "✓ JWT secret applied/verified"
      
      # Apply all manifests
      echo ""
      echo "Applying Bank of Anthos manifests..."
      kubectl apply -f "$MANIFESTS_PATH" -n "$NAMESPACE"
      echo "✓ Manifests applied"
      
      # Wait for deployments to be ready
      echo ""
      echo "Waiting for deployments to be ready (this may take several minutes)..."
      
      # Get list of deployments
      DEPLOYMENTS=$(kubectl get deployments -n "$NAMESPACE" -o name 2>/dev/null || echo "")
      
      if [ -z "$DEPLOYMENTS" ]; then
        echo "⚠ No deployments found in namespace $NAMESPACE"
      else
        echo "Found deployments:"
        kubectl get deployments -n "$NAMESPACE" -o wide
        
        echo ""
        echo "Waiting for all deployments to become available..."
        if kubectl wait --for=condition=available --timeout=600s \
          deployment --all -n "$NAMESPACE"; then
          echo "✓ All deployments are ready!"
        else
          echo "⚠ Some deployments may not be ready yet"
          echo "Current deployment status:"
          kubectl get deployments -n "$NAMESPACE"
          echo ""
          echo "Pod status:"
          kubectl get pods -n "$NAMESPACE"
        fi
      fi
      
      # Display final status
      echo ""
      echo "=========================================="
      echo "Bank of Anthos Deployment Summary"
      echo "=========================================="
      echo "Namespace: $NAMESPACE"
      echo ""
      echo "Deployments:"
      kubectl get deployments -n "$NAMESPACE" -o wide || true
      echo ""
      echo "Pods:"
      kubectl get pods -n "$NAMESPACE" -o wide || true
      echo ""
      echo "Services:"
      kubectl get services -n "$NAMESPACE" -o wide || true
      echo ""
      echo "✓ Bank of Anthos deployment complete!"
    EOT
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    when    = destroy
    command = <<-EOT
      set -e
      
      NAMESPACE="${self.triggers.namespace}"
      CLUSTER_NAME="${self.triggers.cluster_name}"
      REGION="${self.triggers.region}"
      PROJECT_ID="${self.triggers.project_id}"
      
      echo "=========================================="
      echo "Cleaning up Bank of Anthos Application"
      echo "=========================================="
      
      # Get cluster credentials (may fail if cluster is already deleted)
      echo "Getting cluster credentials..."
      if gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" 2>/dev/null; then
        
        echo "✓ Connected to cluster"
        
        # Check if namespace exists
        if kubectl get namespace "$NAMESPACE" --no-headers 2>/dev/null; then
          echo "Deleting namespace '$NAMESPACE' and all its resources..."
          
          # Delete the namespace (this will delete all resources in it)
          if kubectl delete namespace "$NAMESPACE" --timeout=300s 2>/dev/null; then
            echo "✓ Namespace deleted successfully"
          else
            echo "⚠ Namespace deletion timed out or failed, forcing deletion..."
            kubectl delete namespace "$NAMESPACE" --grace-period=0 --force 2>/dev/null || true
          fi
        else
          echo "ℹ Namespace '$NAMESPACE' not found (may already be deleted)"
        fi
      else
        echo "⚠ Could not connect to cluster (may already be deleted)"
      fi
      
      echo "✓ Cleanup complete"
    EOT
    on_failure = continue
  }

  depends_on = [
    null_resource.download_bank_of_anthos,
    kubernetes_namespace.bank_of_anthos,
    null_resource.wait_for_service_mesh,
  ]
}

# Output to verify deployment
resource "null_resource" "verify_deployment" {
  count = var.deploy_application ? 1 : 0

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      echo "Verifying Bank of Anthos deployment..."
      gcloud container clusters get-credentials "${google_container_cluster.gke_cluster.name}" \
        --region="${var.gcp_region}" \
        --project="${local.project.project_id}"
      kubectl get pods -n bank-of-anthos
      kubectl get services -n bank-of-anthos
    EOT
  }

  depends_on = [
    null_resource.deploy_bank_of_anthos,
  ]
}
