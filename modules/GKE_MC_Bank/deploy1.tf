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
# Pre-Cleanup Resource
# ============================================
resource "null_resource" "pre_cleanup_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOF
      set -x
      echo "======================================"
      echo "Starting pre-cleanup for cluster ${self.triggers.cluster}"
      echo "======================================"
      
      # Get cluster credentials
      if ! gcloud container clusters get-credentials ${self.triggers.cluster} \
          --region ${self.triggers.region} \
          --project ${self.triggers.project} 2>/dev/null; then
        echo "Warning: Could not get cluster credentials. Cluster may already be deleted."
        exit 0
      fi
      
      # Check if namespace exists
      if ! kubectl get namespace bank-of-anthos 2>/dev/null; then
        echo "Namespace bank-of-anthos does not exist. Skipping cleanup."
        exit 0
      fi
      
      echo "======================================"
      echo "Step 1: Delete LoadBalancer services first"
      echo "======================================"
      kubectl delete svc -n bank-of-anthos --field-selector spec.type=LoadBalancer --timeout=2m 2>/dev/null || true
      
      echo "======================================"
      echo "Step 2: Delete Ingress resources"
      echo "======================================"
      kubectl delete ingress -n bank-of-anthos --all --timeout=2m 2>/dev/null || true
      
      echo "======================================"
      echo "Step 3: Delete MultiClusterIngress"
      echo "======================================"
      kubectl delete multiclusteringress -n bank-of-anthos --all --timeout=2m 2>/dev/null || true
      
      echo "======================================"
      echo "Step 4: Delete all deployments"
      echo "======================================"
      kubectl delete deployment -n bank-of-anthos --all --timeout=2m 2>/dev/null || true
      
      echo "======================================"
      echo "Step 5: Delete all statefulsets"
      echo "======================================"
      kubectl delete statefulset -n bank-of-anthos --all --timeout=2m 2>/dev/null || true
      
      echo "======================================"
      echo "Step 6: Force delete all pods"
      echo "======================================"
      kubectl delete pods -n bank-of-anthos --all --force --grace-period=0 --timeout=1m 2>/dev/null || true
      
      echo "======================================"
      echo "Step 7: Delete PVCs"
      echo "======================================"
      kubectl delete pvc -n bank-of-anthos --all --timeout=2m 2>/dev/null || true
      
      echo "======================================"
      echo "Step 8: Remove finalizers from namespace"
      echo "======================================"
      kubectl patch namespace bank-of-anthos -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
      
      echo "======================================"
      echo "Step 9: Delete the namespace"
      echo "======================================"
      kubectl delete namespace bank-of-anthos --timeout=3m 2>/dev/null || true
      
      echo "======================================"
      echo "Step 10: Force delete namespace if still exists"
      echo "======================================"
      kubectl delete namespace bank-of-anthos --force --grace-period=0 2>/dev/null || true
      
      echo "======================================"
      echo "Pre-cleanup completed successfully"
      echo "======================================"
      
      exit 0
    EOF
  }

  lifecycle {
    create_before_destroy = false
  }
}

# ============================================
# FIXED: Install Application with Proper Namespace Handling
# ============================================
resource "null_resource" "install_application_1" {
  count = var.deploy_application ? 1 : 0

  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<-EOF
      #!/bin/bash
      set -e  # Exit on any error
      
      # Configuration
      CLUSTER_NAME="${var.gke_cluster_1}"
      REGION="${var.region_1}"
      PROJECT_ID="${local.project.project_id}"
      NAMESPACE="bank-of-anthos"
      CONTEXT="gke_$${PROJECT_ID}_$${REGION}_$${CLUSTER_NAME}"
      
      # Colors for output
      GREEN='\033[0;32m'
      YELLOW='\033[1;33m'
      RED='\033[0;31m'
      NC='\033[0m'
      
      log_info() { echo -e "$${GREEN}✓$${NC} $1"; }
      log_warn() { echo -e "$${YELLOW}⚠$${NC} $1"; }
      log_error() { echo -e "$${RED}✗$${NC} $1"; }
      
      # Cleanup and clone
      log_info "Cleaning up previous installations..."
      rm -rf ${path.module}/scripts/app/bank-of-anthos/cluster1
      mkdir -p ${path.module}/scripts/app/bank-of-anthos/cluster1
      sleep 5
      
      log_info "Cloning bank-of-anthos repository..."
      if ! git clone --branch v0.6.6 --single-branch \
        https://github.com/GoogleCloudPlatform/bank-of-anthos.git \
        ${path.module}/scripts/app/bank-of-anthos/cluster1 2>&1 | grep -v "detached HEAD"; then
        log_error "Failed to clone repository"
        exit 1
      fi

      # Get cluster credentials
      log_info "Getting cluster credentials..."
      if ! gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region "$REGION" \
        --project "$PROJECT_ID" 2>&1 | grep -v "kubeconfig"; then
        log_error "Failed to get cluster credentials"
        exit 1
      fi

      # Wait for cluster to be ready
      log_info "Waiting for cluster API to be ready..."
      CLUSTER_READY=false
      for i in {1..60}; do
        if kubectl --context="$CONTEXT" get nodes &> /dev/null; then
          log_info "Cluster API is ready"
          CLUSTER_READY=true
          break
        fi
        log_warn "Waiting for cluster API... (attempt $i/60)"
        sleep 10
      done

      if [ "$CLUSTER_READY" = false ]; then
        log_error "Cluster not ready after 10 minutes"
        exit 1
      fi

      # Delete namespace if exists (clean slate)
      log_info "Ensuring clean namespace state..."
      if kubectl --context="$CONTEXT" get namespace "$NAMESPACE" &> /dev/null; then
        log_warn "Namespace '$NAMESPACE' exists, deleting for clean installation..."
        kubectl --context="$CONTEXT" delete namespace "$NAMESPACE" --wait=true --timeout=120s || true
        
        # Wait for namespace to be fully deleted
        for i in {1..30}; do
          if ! kubectl --context="$CONTEXT" get namespace "$NAMESPACE" &> /dev/null; then
            log_info "Namespace fully deleted"
            break
          fi
          log_warn "Waiting for namespace deletion... (attempt $i/30)"
          sleep 5
        done
      fi

      # Create namespace with retry
      log_info "Creating namespace '$NAMESPACE'..."
      NAMESPACE_CREATED=false
      for i in {1..30}; do
        if kubectl --context="$CONTEXT" create namespace "$NAMESPACE" 2>&1; then
          log_info "Namespace '$NAMESPACE' created successfully"
          NAMESPACE_CREATED=true
          break
        fi
        log_warn "Retrying namespace creation... (attempt $i/30)"
        sleep 5
      done

      if [ "$NAMESPACE_CREATED" = false ]; then
        log_error "Failed to create namespace after 30 attempts"
        exit 1
      fi

      # Wait for namespace to be fully ready
      log_info "Waiting for namespace to be fully ready..."
      for i in {1..30}; do
        NS_STATUS=$(kubectl --context="$CONTEXT" get namespace "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        if [ "$NS_STATUS" = "Active" ]; then
          log_info "Namespace is Active and ready"
          break
        fi
        if [ $i -eq 30 ]; then
          log_error "Namespace not ready after 150 seconds"
          kubectl --context="$CONTEXT" get namespace "$NAMESPACE" -o yaml
          exit 1
        fi
        log_warn "Waiting for namespace to become Active... (attempt $i/30, status: $NS_STATUS)"
        sleep 5
      done

      # Additional safety wait for API sync
      log_info "Waiting for Kubernetes API to sync..."
      sleep 10

      # Label namespace with retry
      log_info "Labeling namespace for Istio sidecar injection..."
      LABEL_SUCCESS=false
      for i in {1..10}; do
        if kubectl --context="$CONTEXT" label namespace "$NAMESPACE" \
          istio.io/rev=asm-managed --overwrite 2>&1; then
          log_info "Namespace labeled successfully"
          LABEL_SUCCESS=true
          break
        fi
        log_warn "Retrying namespace labeling... (attempt $i/10)"
        sleep 5
      done

      if [ "$LABEL_SUCCESS" = false ]; then
        log_error "Failed to label namespace"
        kubectl --context="$CONTEXT" get namespace "$NAMESPACE" -o yaml
        exit 1
      fi

      # Verify label
      LABEL_VALUE=$(kubectl --context="$CONTEXT" get namespace "$NAMESPACE" \
        -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null || echo "")
      if [ "$LABEL_VALUE" != "asm-managed" ]; then
        log_error "Label verification failed. Expected 'asm-managed', got '$LABEL_VALUE'"
        exit 1
      fi
      log_info "Label verified: istio.io/rev=$LABEL_VALUE"

      # Wait for istio-system
      log_info "Checking for istio-system namespace..."
      ISTIO_READY=false
      for i in {1..30}; do
        if kubectl --context="$CONTEXT" get namespace istio-system &> /dev/null; then
          log_info "istio-system namespace found"
          ISTIO_READY=true
          break
        fi
        log_warn "Waiting for istio-system... (attempt $i/30)"
        sleep 10
      done

      if [ "$ISTIO_READY" = false ]; then
        log_error "istio-system namespace not found after 5 minutes"
        exit 1
      fi

      # Final verification
      log_info "Running final verification..."
      echo "======================================"
      echo "Cluster nodes:"
      kubectl --context="$CONTEXT" get nodes
      echo ""
      echo "Namespaces:"
      kubectl --context="$CONTEXT" get namespaces
      echo ""
      echo "Bank-of-Anthos namespace details:"
      kubectl --context="$CONTEXT" get namespace "$NAMESPACE" -o yaml
      echo "======================================"

      log_info "Installation preparation completed successfully"
      exit 0
    EOF
  }

  depends_on = [
    google_container_cluster.gke_autopilot_cluster_1,
    google_container_cluster.gke_standard_cluster_1,
    time_sleep.allow_10_minutes_for_fleet_synchronization_1,
  ]
}

# ============================================
# Individual Resource Deployments
# ============================================
resource "null_resource" "config_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    gcloud container clusters get-credentials ${var.gke_cluster_1} --region ${var.region_1} --project ${local.project.project_id}
    CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster1/kubernetes-manifests/config.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.install_application_1,
  ]
}

resource "null_resource" "jwt_secret_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster1/extras/jwt/jwt-secret.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.config_1,
  ]
}

resource "null_resource" "accounts_db_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster1/kubernetes-manifests/accounts-db.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.jwt_secret_1
  ]
}

resource "null_resource" "balance_reader_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster1/kubernetes-manifests/balance-reader.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.accounts_db_1
  ]
}

resource "null_resource" "contacts_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster1/kubernetes-manifests/contacts.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.balance_reader_1
  ]
}

resource "null_resource" "frontend_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster1/kubernetes-manifests/frontend.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.contacts_1
  ]
}

resource "null_resource" "ledger_db_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster1/kubernetes-manifests/ledger-db.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.frontend_1
  ]
}

resource "null_resource" "ledger_writer_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster1/kubernetes-manifests/ledger-writer.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.ledger_db_1
  ]
}

resource "null_resource" "loadgenerator_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster1/kubernetes-manifests/loadgenerator.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.ledger_writer_1
  ]
}

resource "null_resource" "transaction_history_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster1/kubernetes-manifests/transaction-history.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.loadgenerator_1
  ]
}

resource "null_resource" "userservice_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster1/kubernetes-manifests/userservice.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.transaction_history_1
  ]
}

resource "null_resource" "get_external_ip_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      attempt=0
      max_attempts=30
      gcloud container clusters get-credentials ${var.gke_cluster_1} --region ${var.region_1} --project ${local.project.project_id}
      CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"

      while [ $attempt -lt $max_attempts ]; do
        EXISTS=$(kubectl --context="$CONTEXT" get svc frontend --namespace=bank-of-anthos --ignore-not-found)
        if [ -z "$EXISTS" ]; then
          echo "Service 'frontend' does not exist yet in namespace 'bank-of-anthos'. Waiting..."
          sleep 10
          attempt=$((attempt + 1))
          continue
        fi

        IP=$(kubectl --context="$CONTEXT" get svc frontend --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}" --namespace=bank-of-anthos)
        if [ "$IP" ]; then
          echo "Service external IP is $IP"
          break
        else
          echo "Waiting for external IP..."
        fi

        sleep 10
        attempt=$((attempt + 1))
      done

      if [ $attempt -eq $max_attempts ]; then
        echo "Failed to get the external IP after $max_attempts attempts"
        exit 1
      fi
    EOT
  }

  depends_on = [
    null_resource.config_1,
    null_resource.frontend_1,
  ]
}

resource "null_resource" "app_configmap_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"
    kubectl --context="$CONTEXT" apply -n istio-system -f ${path.module}/manifests/configmap.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.userservice_1,
    local_file.backend_config_yaml_output,
    local_file.configmap_yaml_output,
    local_file.frontend_config_yaml_output,
    local_file.ingress_yaml_output,
    local_file.managed_certificate_yaml_output,
    local_file.nodeport_service_yaml_output,
    local_file.multicluster_service_yaml_output,
    local_file.multicluster_ingress_yaml_output,
  ]
}

resource "null_resource" "app_frontend_config_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/manifests/frontend_config.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.app_configmap_1,
  ]
}

resource "null_resource" "app_managed_certificate_config_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/manifests/managed_certificate.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.app_frontend_config_1
  ]
}

resource "null_resource" "app_backend_config_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/manifests/backend_config.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.app_managed_certificate_config_1
  ]
}

resource "null_resource" "app_nodeport_service_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/manifests/nodeport_service.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.app_backend_config_1,
  ]
}

resource "null_resource" "app_multicluster_service_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/manifests/multicluster_service.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.app_nodeport_service_1,
  ]
}

resource "null_resource" "app_multicluster_ingress_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_1
    region  = var.region_1
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/manifests/multicluster_ingress.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.app_multicluster_service_1,
  ]
}

# ============================================
# Final Cleanup
# ============================================
resource "null_resource" "final_cleanup_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cleanup_path = "${path.module}/scripts/app/bank-of-anthos/cluster1"
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOF
      echo "======================================"
      echo "Final cleanup - removing local files"
      echo "======================================"
      
      rm -rf ${self.triggers.cleanup_path}
      
      echo "Final cleanup completed"
    EOF
  }

  depends_on = [
    null_resource.app_multicluster_ingress_1,
    null_resource.pre_cleanup_1,
  ]
}
