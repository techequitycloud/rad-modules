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
    command     = <<-EOT
      set -e

      # Check if files already exist to skip redundant downloads
      if [ -f "${local.extracted_path}/extras/jwt/jwt-secret.yaml" ] && [ -d "${local.extracted_path}/kubernetes-manifests" ]; then
        echo "=========================================="
        echo "Bank of Anthos ${local.bank_of_anthos_version} already downloaded."
        echo "Skipping redundant download."
        echo "=========================================="
        exit 0
      fi

      echo "=========================================="
      echo "Downloading Bank of Anthos ${local.bank_of_anthos_version}..."
      echo "=========================================="
      
      # Create download directory
      mkdir -p ${local.download_path}
      
      echo "Downloading release archive..."
      curl -L -o ${local.download_path}/release.tar.gz ${local.release_url}
      
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
    when        = destroy
    command     = "rm -rf ${self.triggers.download_path}"
    on_failure  = continue
  }
}

# ============================================
# NAMESPACES
# ============================================

resource "kubernetes_namespace" "bank_of_anthos_cluster1" {
  count    = var.deploy_application && var.cluster_size >= 1 ? 1 : 0
  provider = kubernetes.cluster1

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

resource "kubernetes_namespace" "bank_of_anthos_cluster2" {
  count    = var.deploy_application && var.cluster_size >= 2 ? 1 : 0
  provider = kubernetes.cluster2

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
  for_each = var.deploy_application ? local.cluster_configs : {}

  triggers = {
    cluster_name    = each.value.gke_cluster_name
    version         = local.bank_of_anthos_version
    namespace       = "bank-of-anthos"
    region          = each.value.region
    project_id      = google_container_cluster.gke_cluster[each.key].project
    manifests_path  = local.manifests_path
    jwt_secret_path = local.jwt_secret_path
    download_id     = null_resource.download_bank_of_anthos[0].id
    is_primary      = each.key == "cluster1" ? "true" : "false"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      export KUBECONFIG="$(mktemp)"

      NAMESPACE="${self.triggers.namespace}"
      CLUSTER_NAME="${self.triggers.cluster_name}"
      REGION="${self.triggers.region}"
      PROJECT_ID="${self.triggers.project_id}"
      JWT_SECRET_PATH="${self.triggers.jwt_secret_path}"
      MANIFESTS_PATH="${self.triggers.manifests_path}"
      IS_PRIMARY="${self.triggers.is_primary}"

      echo "=========================================="
      echo "Deploying Bank of Anthos Application to $CLUSTER_NAME"
      echo "=========================================="
      
      # Verify files exist BEFORE starting deployment
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
      echo "  - JWT secret: $JWT_SECRET_PATH"
      echo "  - Manifests: $MANIFESTS_PATH"

      # Get cluster credentials and set explicit context
      echo ""
      echo "Getting cluster credentials..."
      CONTEXT_NAME="gke_$${PROJECT_ID}_$${REGION}_$${CLUSTER_NAME}"
      gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID"

      # Verify we're using the correct context
      echo ""
      echo "Current kubectl context: $(kubectl config current-context)"
      echo "Target context: $CONTEXT_NAME"
      
      echo ""
      echo "Cluster nodes (first 5):"
      kubectl get nodes --context="$CONTEXT_NAME" -o wide | head -6

      # Verify namespace exists and is Active
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

      # Verify ASM injection label
      echo ""
      echo "Checking ASM injection configuration..."
      ASM_LABEL=$(kubectl get namespace "$NAMESPACE" \
        --context="$CONTEXT_NAME" \
        -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null || echo "")

      if [ -n "$ASM_LABEL" ]; then
        echo "✓ ASM injection label found: $ASM_LABEL"
      else
        echo "ℹ No ASM injection label (Service Mesh may not be enabled)"
      fi

      # Apply JWT secret with server-side apply (idempotent)
      echo ""
      echo "Applying JWT secret..."
      kubectl apply -f "$JWT_SECRET_PATH" \
        -n "$NAMESPACE" \
        --context="$CONTEXT_NAME" \
        --server-side --force-conflicts
      echo "✓ JWT secret applied/verified"

      # Apply Bank of Anthos manifests.
      # The accounts-db and ledger-db StatefulSets are deployed to the primary
      # cluster only (cluster1); non-primary clusters connect to the databases
      # on the primary cluster via Multi-Cluster Services.
      echo ""
      if [ "$IS_PRIMARY" = "true" ]; then
        echo "Applying Bank of Anthos manifests (primary cluster: includes accounts-db, ledger-db)..."
        kubectl apply -f "$MANIFESTS_PATH" \
          -n "$NAMESPACE" \
          --context="$CONTEXT_NAME" \
          --server-side --force-conflicts
      else
        echo "Applying Bank of Anthos manifests (non-primary cluster: skipping accounts-db, ledger-db)..."
        FILTERED_MANIFESTS_DIR="$(mktemp -d)"
        trap 'rm -rf "$FILTERED_MANIFESTS_DIR"' EXIT

        # Copy all manifest files, then remove the DB StatefulSet manifests so
        # they are applied on the primary cluster only.
        cp "$MANIFESTS_PATH"/*.yaml "$FILTERED_MANIFESTS_DIR/"
        rm -f "$FILTERED_MANIFESTS_DIR/accounts-db.yaml" \
              "$FILTERED_MANIFESTS_DIR/ledger-db.yaml"

        echo "Manifests to apply on non-primary cluster:"
        ls -1 "$FILTERED_MANIFESTS_DIR"

        kubectl apply -f "$FILTERED_MANIFESTS_DIR" \
          -n "$NAMESPACE" \
          --context="$CONTEXT_NAME" \
          --server-side --force-conflicts

        # Remove any pre-existing DB StatefulSets from non-primary clusters
        # (e.g. from deployments that predate the primary-only DB change).
        echo ""
        echo "Removing any pre-existing accounts-db / ledger-db resources from non-primary cluster..."
        kubectl delete statefulset accounts-db ledger-db \
          -n "$NAMESPACE" \
          --context="$CONTEXT_NAME" \
          --ignore-not-found=true --timeout=5m || true
        kubectl delete service accounts-db ledger-db \
          -n "$NAMESPACE" \
          --context="$CONTEXT_NAME" \
          --ignore-not-found=true --timeout=2m || true
        kubectl delete configmap accounts-db-config ledger-db-config \
          -n "$NAMESPACE" \
          --context="$CONTEXT_NAME" \
          --ignore-not-found=true --timeout=2m || true
      fi
      echo "✓ Manifests applied"

      # Wait for deployments to be ready
      echo ""
      echo "Waiting for deployments to be ready (this may take several minutes)..."

      # Get list of deployments
      DEPLOYMENTS=$(kubectl get deployments \
        -n "$NAMESPACE" \
        --context="$CONTEXT_NAME" \
        -o name 2>/dev/null || echo "")

      if [ -z "$DEPLOYMENTS" ]; then
        echo "⚠ No deployments found in namespace $NAMESPACE"
      else
        echo "Found deployments:"
        kubectl get deployments \
          -n "$NAMESPACE" \
          --context="$CONTEXT_NAME" \
          -o wide

        echo ""
        echo "Waiting for all deployments to become available..."
        if kubectl wait --for=condition=available --timeout=600s \
          deployment --all \
          -n "$NAMESPACE" \
          --context="$CONTEXT_NAME"; then
          echo "✓ All deployments are ready!"
        else
          echo "⚠ Some deployments may not be ready yet"
          echo "Current deployment status:"
          kubectl get deployments -n "$NAMESPACE" --context="$CONTEXT_NAME"
          echo ""
          echo "Pod status:"
          kubectl get pods -n "$NAMESPACE" --context="$CONTEXT_NAME"
        fi
      fi

      # Display final status
      echo ""
      echo "=========================================="
      echo "Bank of Anthos Deployment Summary for $CLUSTER_NAME"
      echo "=========================================="
      echo "Namespace: $NAMESPACE"
      echo "Context: $CONTEXT_NAME"
      echo ""
      echo "Deployments:"
      kubectl get deployments -n "$NAMESPACE" --context="$CONTEXT_NAME" -o wide || true
      echo ""
      echo "Pods:"
      kubectl get pods -n "$NAMESPACE" --context="$CONTEXT_NAME" -o wide || true
      echo ""
      echo "Services:"
      kubectl get services -n "$NAMESPACE" --context="$CONTEXT_NAME" -o wide || true
      echo ""
      echo "✓ Bank of Anthos deployment complete!"
    EOT
  }

  depends_on = [
    null_resource.download_bank_of_anthos,
    kubernetes_namespace.bank_of_anthos_cluster1,
    kubernetes_namespace.bank_of_anthos_cluster2,
    null_resource.wait_for_service_mesh,
  ]
}

resource "google_gke_hub_feature" "multiclusteringress_feature" {
  count    = var.deploy_application ? 1 : 0
  provider = google-beta

  project  = local.project.project_id
  name     = "multiclusteringress"
  location = "global"

  spec {
    multiclusteringress {
      config_membership = "projects/${local.project.project_id}/locations/global/memberships/${local.cluster_configs["cluster1"].gke_cluster_name}"
    }
  }

  depends_on = [
    google_project_service.enabled_services,
    google_gke_hub_membership.hub_membership,
  ]
}

resource "null_resource" "app_multicluster_ingress" {
  count = var.deploy_application ? 1 : 0

  triggers = {
    cluster_name = local.cluster_configs["cluster1"].gke_cluster_name
    region       = local.cluster_configs["cluster1"].region
    project_id   = google_container_cluster.gke_cluster["cluster1"].project
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      export KUBECONFIG="$(mktemp)"
      
      CLUSTER_NAME="${local.cluster_configs["cluster1"].gke_cluster_name}"
      REGION="${local.cluster_configs["cluster1"].region}"
      PROJECT_ID="${google_container_cluster.gke_cluster["cluster1"].project}"
      
      echo "=========================================="
      echo "Applying Multi-Cluster Ingress Configuration"
      echo "=========================================="
      
      # Get credentials and set context
      CONTEXT_NAME="gke_$${PROJECT_ID}_$${REGION}_$${CLUSTER_NAME}"
      gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region "$REGION" \
        --project "$PROJECT_ID"
      
      echo "Using context: $CONTEXT_NAME"
      echo ""
      
      # Apply all manifests with explicit context
      echo "Applying multicluster_ingress.yaml..."
      kubectl apply -n bank-of-anthos \
        -f ${path.module}/manifests/multicluster_ingress.yaml \
        --context="$CONTEXT_NAME" \
        --server-side --force-conflicts --timeout=5m
      
      echo "Applying multicluster_service.yaml..."
      kubectl apply -n bank-of-anthos \
        -f ${path.module}/manifests/multicluster_service.yaml \
        --context="$CONTEXT_NAME" \
        --server-side --force-conflicts --timeout=5m
      
      echo "Applying nodeport_service.yaml..."
      kubectl apply -n bank-of-anthos \
        -f ${path.module}/manifests/nodeport_service.yaml \
        --context="$CONTEXT_NAME" \
        --server-side --force-conflicts --timeout=5m
      
      echo "Applying backend_config.yaml..."
      kubectl apply -n bank-of-anthos \
        -f ${path.module}/manifests/backend_config.yaml \
        --context="$CONTEXT_NAME" \
        --server-side --force-conflicts --timeout=5m
      
      echo "Applying managed_certificate.yaml..."
      kubectl apply -n bank-of-anthos \
        -f ${path.module}/manifests/managed_certificate.yaml \
        --context="$CONTEXT_NAME" \
        --server-side --force-conflicts --timeout=5m
      
      echo "Applying frontend_config.yaml..."
      kubectl apply -n bank-of-anthos \
        -f ${path.module}/manifests/frontend_config.yaml \
        --context="$CONTEXT_NAME" \
        --server-side --force-conflicts --timeout=5m
      
      echo "Applying configmap.yaml to istio-system..."
      kubectl apply -n istio-system \
        -f ${path.module}/manifests/configmap.yaml \
        --context="$CONTEXT_NAME" \
        --server-side --force-conflicts --timeout=5m
      
      echo ""
      echo "✓ Multi-cluster ingress configuration applied"
    EOT
  }

  depends_on = [
    null_resource.deploy_bank_of_anthos,
    google_gke_hub_feature.multiclusteringress_feature,
  ]
}

# ============================================
# PRE-DESTROY CLEANUP FOR MULTICLUSTER INGRESS
# ============================================

resource "null_resource" "cleanup_multicluster_ingress" {
  count = var.deploy_application ? 1 : 0

  triggers = {
    cluster_name = local.cluster_configs["cluster1"].gke_cluster_name
    region       = local.cluster_configs["cluster1"].region
    project_id   = google_container_cluster.gke_cluster["cluster1"].project
    namespace    = "bank-of-anthos"
  }

  # This runs ONLY during destroy
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    on_failure  = continue # Don't fail destroy if cleanup fails
    command     = <<-EOT
      set -e
      export KUBECONFIG="$(mktemp)"
      
      CLUSTER_NAME="${self.triggers.cluster_name}"
      REGION="${self.triggers.region}"
      PROJECT_ID="${self.triggers.project_id}"
      NAMESPACE="${self.triggers.namespace}"
      
      echo "=========================================="
      echo "Cleaning up MultiCluster Ingress resources"
      echo "=========================================="
      
      # Get cluster credentials
      CONTEXT_NAME="gke_$${PROJECT_ID}_$${REGION}_$${CLUSTER_NAME}"
      gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" || {
        echo "⚠ Could not get cluster credentials (cluster may already be deleted)"
        exit 0
      }
      
      echo "Using context: $CONTEXT_NAME"
      
      # Check if namespace exists
      if ! kubectl get namespace "$NAMESPACE" --context="$CONTEXT_NAME" &>/dev/null; then
        echo "ℹ Namespace $NAMESPACE not found, skipping cleanup"
        exit 0
      fi
      
      echo ""
      echo "Deleting MultiCluster Ingress resources..."
      
      # Delete in reverse order of creation with explicit context
      kubectl delete -n istio-system configmap istio-ingress-config \
        --context="$CONTEXT_NAME" \
        --ignore-not-found=true --timeout=2m || true
      
      kubectl delete -n "$NAMESPACE" frontendconfig frontend-ingress-config \
        --context="$CONTEXT_NAME" \
        --ignore-not-found=true --timeout=2m || true
      
      kubectl delete -n "$NAMESPACE" managedcertificate frontend-managed-cert \
        --context="$CONTEXT_NAME" \
        --ignore-not-found=true --timeout=2m || true
      
      kubectl delete -n "$NAMESPACE" backendconfig backend-health-check \
        --context="$CONTEXT_NAME" \
        --ignore-not-found=true --timeout=2m || true
      
      kubectl delete -n "$NAMESPACE" service frontend-nodeport \
        --context="$CONTEXT_NAME" \
        --ignore-not-found=true --timeout=2m || true
      
      kubectl delete -n "$NAMESPACE" multiclusterservice frontend-mcs \
        --context="$CONTEXT_NAME" \
        --ignore-not-found=true --timeout=2m || true
      
      kubectl delete -n "$NAMESPACE" multiclusteringress frontend-ingress \
        --context="$CONTEXT_NAME" \
        --ignore-not-found=true --timeout=2m || true
      
      kubectl delete -n gke-mcs deployment gke-mcs-importer \
        --context="$CONTEXT_NAME" \
        --ignore-not-found=true --timeout=2m || true
      
      echo ""
      echo "Waiting for MultiClusterIngress to be fully deleted..."
      # Wait up to 3 minutes for MCI to be deleted
      timeout 180 bash -c '
        while kubectl get multiclusteringress -n '"$NAMESPACE"' --context="'"$CONTEXT_NAME"'" 2>/dev/null | grep -q frontend-ingress; do
          echo "⏳ Waiting for MultiClusterIngress deletion..."
          sleep 5
        done
      ' || echo "⚠ Timeout waiting for MultiClusterIngress deletion"
      
      echo ""
      echo "✓ MultiCluster Ingress cleanup complete"
    EOT
  }

  depends_on = [
    null_resource.app_multicluster_ingress,
  ]
}
