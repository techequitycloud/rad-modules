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

resource "null_resource" "download_bank_of_anthos" {
  count = var.deploy_application ? 1 : 0

  triggers = {
    version       = local.bank_of_anthos_version
    download_path = local.download_path
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      echo "=========================================="
      echo "Downloading Bank of Anthos ${local.bank_of_anthos_version}..."
      echo "=========================================="
      
      mkdir -p ${local.download_path}
      
      # ✅ FIXED: Always download fresh copy
      echo "Downloading release archive..."
      curl -L -o ${local.download_path}/release.tar.gz ${local.release_url}
      
      echo "Extracting archive..."
      rm -rf ${local.extracted_path}
      tar -xzf ${local.download_path}/release.tar.gz -C ${local.download_path}
      
      echo ""
      echo "✓ Download and extraction complete!"
      
      # Verify extraction
      echo "Verifying extracted files..."
      if [ ! -d "${local.extracted_path}" ]; then
        echo "❌ Extraction failed - directory not found"
        exit 1
      fi
      
      if [ ! -f "${local.extracted_path}/extras/jwt/jwt-secret.yaml" ]; then
        echo "❌ JWT secret file not found"
        exit 1
      fi
      
      if [ ! -d "${local.extracted_path}/kubernetes-manifests" ]; then
        echo "❌ Manifests directory not found"
        exit 1
      fi
      
      echo "✓ All required files verified"
    EOT
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    when        = destroy
    command     = "rm -rf ${self.triggers.download_path}"
    on_failure  = continue
  }
}

# ============================================
# NAMESPACE
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
    data.google_container_cluster.existing_cluster,
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

resource "null_resource" "deploy_bank_of_anthos" {
  count = var.deploy_application ? 1 : 0

  triggers = {
    cluster_name    = local.cluster.name
    version         = local.bank_of_anthos_version
    namespace       = "bank-of-anthos" # ✅ FIXED: Direct string
    region          = var.gcp_region
    project_id      = local.project.project_id
    manifests_path  = local.manifests_path
    jwt_secret_path = local.jwt_secret_path
    download_id     = null_resource.download_bank_of_anthos[0].id # ✅ FIXED: Added dependency
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
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
      
      # Verify files exist
      echo ""
      echo "Pre-deployment verification..."
      if [ ! -f "$JWT_SECRET_PATH" ]; then
        echo "❌ CRITICAL: JWT secret file not found at: $JWT_SECRET_PATH"
        exit 1
      fi
      
      if [ ! -d "$MANIFESTS_PATH" ]; then
        echo "❌ CRITICAL: Manifests directory not found at: $MANIFESTS_PATH"
        exit 1
      fi
      
      echo "✓ All required files verified"
      
      # ✅ FIXED: Verify gcloud authentication
      echo ""
      echo "Verifying gcloud configuration..."
      CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
      if [ "$CURRENT_PROJECT" != "$PROJECT_ID" ]; then
        echo "Setting gcloud project to $PROJECT_ID"
        gcloud config set project "$PROJECT_ID"
      fi
      
      # ✅ FIXED: Get credentials and set explicit context
      echo ""
      echo "Getting cluster credentials..."
      CONTEXT_NAME="gke_$${PROJECT_ID}_$${REGION}_$${CLUSTER_NAME}"
      gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID"
      
      echo "Using context: $CONTEXT_NAME"
      
      # ✅ FIXED: All kubectl commands use --context
      echo ""
      echo "Verifying namespace '$NAMESPACE'..."
      max_retries=5
      retry_count=0
      
      while [ $retry_count -lt $max_retries ]; do
        NAMESPACE_STATUS=$(kubectl get namespace "$NAMESPACE" \
          --context="$CONTEXT_NAME" \
          -o jsonpath='{.status.phase}' 2>/dev/null || echo "NOT_FOUND")
        
        if [ "$NAMESPACE_STATUS" = "Active" ]; then
          echo "✓ Namespace '$NAMESPACE' is Active"
          break
        fi
        
        echo "⏳ Waiting for namespace... (Attempt $((retry_count + 1))/$max_retries)"
        retry_count=$((retry_count + 1))
        [ $retry_count -lt $max_retries ] && sleep 5
      done
      
      if [ "$NAMESPACE_STATUS" != "Active" ]; then
        echo "❌ Failed to verify namespace"
        exit 1
      fi
      
      # Check ASM injection
      echo ""
      echo "Checking ASM injection..."
      ASM_LABEL=$(kubectl get namespace "$NAMESPACE" \
        --context="$CONTEXT_NAME" \
        -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null || echo "")
      
      if [ -n "$ASM_LABEL" ]; then
        echo "✓ ASM injection label: $ASM_LABEL"
      else
        echo "ℹ No ASM injection label"
      fi
      
      # ✅ FIXED: Apply with proper error handling
      echo ""
      echo "Applying JWT secret..."
      kubectl apply -f "$JWT_SECRET_PATH" \
        -n "$NAMESPACE" \
        --context="$CONTEXT_NAME" \
        --server-side --force-conflicts
      echo "✓ JWT secret applied"
      
      echo ""
      echo "Applying manifests..."
      kubectl apply -f "$MANIFESTS_PATH" \
        -n "$NAMESPACE" \
        --context="$CONTEXT_NAME"
      echo "✓ Manifests applied"
      
      # Wait for deployments
      echo ""
      echo "Waiting for deployments..."
      
      DEPLOYMENTS=$(kubectl get deployments \
        -n "$NAMESPACE" \
        --context="$CONTEXT_NAME" \
        -o name 2>/dev/null || echo "")
      
      if [ -z "$DEPLOYMENTS" ]; then
        echo "⚠ No deployments found"
      else
        echo "Found deployments:"
        kubectl get deployments -n "$NAMESPACE" --context="$CONTEXT_NAME" -o wide
        
        echo ""
        if kubectl wait --for=condition=available --timeout=600s \
          deployment --all \
          -n "$NAMESPACE" \
          --context="$CONTEXT_NAME"; then
          echo "✓ All deployments ready!"
        else
          echo "⚠ Some deployments not ready"
          kubectl get deployments -n "$NAMESPACE" --context="$CONTEXT_NAME"
          kubectl get pods -n "$NAMESPACE" --context="$CONTEXT_NAME"
        fi
      fi
      
      # Display status
      echo ""
      echo "=========================================="
      echo "Deployment Summary"
      echo "=========================================="
      kubectl get all -n "$NAMESPACE" --context="$CONTEXT_NAME"
      echo ""
      echo "✓ Deployment complete!"
    EOT
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    when        = destroy
    command     = <<-EOT
      set -e
      
      NAMESPACE="${self.triggers.namespace}"
      CLUSTER_NAME="${self.triggers.cluster_name}"
      REGION="${self.triggers.region}"
      PROJECT_ID="${self.triggers.project_id}"
      
      echo "=========================================="
      echo "Cleaning up Bank of Anthos Application"
      echo "=========================================="
      
      # ✅ FIXED: Set explicit context
      CONTEXT_NAME="gke_$${PROJECT_ID}_$${REGION}_$${CLUSTER_NAME}"
      
      if gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" 2>/dev/null; then
        
        echo "✓ Connected to cluster"
        
        if kubectl get namespace "$NAMESPACE" \
          --context="$CONTEXT_NAME" \
          --no-headers 2>/dev/null; then
          
          # ✅ FIXED: Clean up special resources first
          echo "Cleaning up MultiCluster resources..."
          kubectl delete multiclusteringress --all -n "$NAMESPACE" \
            --context="$CONTEXT_NAME" \
            --timeout=60s --ignore-not-found=true || true
          
          kubectl delete multiclusterservice --all -n "$NAMESPACE" \
            --context="$CONTEXT_NAME" \
            --timeout=60s --ignore-not-found=true || true
          
          echo "Deleting namespace..."
          if kubectl delete namespace "$NAMESPACE" \
            --context="$CONTEXT_NAME" \
            --timeout=300s 2>/dev/null; then
            echo "✓ Namespace deleted"
          else
            echo "⚠ Forcing namespace deletion..."
            kubectl delete namespace "$NAMESPACE" \
              --context="$CONTEXT_NAME" \
              --grace-period=0 --force 2>/dev/null || true
          fi
        else
          echo "ℹ Namespace not found"
        fi
      else
        echo "⚠ Could not connect to cluster"
      fi
      
      echo "✓ Cleanup complete"
    EOT
    on_failure  = continue
  }

  depends_on = [
    null_resource.download_bank_of_anthos,
    kubernetes_namespace.bank_of_anthos,
    null_resource.wait_for_service_mesh,
  ]
}
