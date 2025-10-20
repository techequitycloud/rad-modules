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
# Pre-cleanup for Cluster 2
# ============================================
resource "null_resource" "pre_cleanup_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster   = var.gke_cluster_2
    region    = var.region_2
    project   = local.project.project_id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOF
      set -x  # Enable debug output
      echo "======================================"
      echo "Starting pre-cleanup for cluster ${self.triggers.cluster}"
      echo "======================================"
      
      # Get cluster credentials and set context
      if ! gcloud container clusters get-credentials ${self.triggers.cluster} \
          --region ${self.triggers.region} \
          --project ${self.triggers.project} 2>/dev/null; then
        echo "Warning: Could not get cluster credentials. Cluster may already be deleted."
        exit 0
      fi
      
      # Get the context name
      CONTEXT="gke_${self.triggers.project}_${self.triggers.region}_${self.triggers.cluster}"
      
      # Check if namespace exists
      if ! kubectl --context="$CONTEXT" get namespace bank-of-anthos 2>/dev/null; then
        echo "Namespace bank-of-anthos does not exist. Skipping cleanup."
        exit 0
      fi
      
      echo "======================================"
      echo "Step 0: Delete MultiClusterIngress and MultiClusterService"
      echo "======================================"
      kubectl --context="$CONTEXT" delete multiclusteringress --all -n bank-of-anthos --timeout=5m 2>/dev/null || true
      kubectl --context="$CONTEXT" delete multiclusterservice --all -n bank-of-anthos --timeout=5m 2>/dev/null || true
      
      # Remove finalizers if stuck
      for mci in $(kubectl --context="$CONTEXT" get multiclusteringress -n bank-of-anthos -o name 2>/dev/null); do
        kubectl --context="$CONTEXT" patch $mci -n bank-of-anthos -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
      done
      
      for mcs in $(kubectl --context="$CONTEXT" get multiclusterservice -n bank-of-anthos -o name 2>/dev/null); do
        kubectl --context="$CONTEXT" patch $mcs -n bank-of-anthos -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
      done
      
      sleep 15
      
      echo "======================================"
      echo "Step 1: Delete Ingress resources"
      echo "======================================"
      kubectl --context="$CONTEXT" delete ingress --all -n bank-of-anthos --timeout=5m 2>/dev/null || true
      sleep 10
      
      echo "======================================"
      echo "Step 2: Delete Services (excluding kubernetes service)"
      echo "======================================"
      kubectl --context="$CONTEXT" get svc -n bank-of-anthos -o name 2>/dev/null | grep -v "service/kubernetes" | xargs -r kubectl --context="$CONTEXT" delete -n bank-of-anthos --timeout=5m 2>/dev/null || true
      sleep 10
      
      echo "======================================"
      echo "Step 3: Delete Deployments"
      echo "======================================"
      kubectl --context="$CONTEXT" delete deployment --all -n bank-of-anthos --timeout=5m 2>/dev/null || true
      sleep 10
      
      echo "======================================"
      echo "Step 4: Delete StatefulSets"
      echo "======================================"
      kubectl --context="$CONTEXT" delete statefulset --all -n bank-of-anthos --timeout=5m 2>/dev/null || true
      sleep 10
      
      echo "======================================"
      echo "Step 5: Delete ConfigMaps and Secrets"
      echo "======================================"
      kubectl --context="$CONTEXT" delete configmap --all -n bank-of-anthos --timeout=3m 2>/dev/null || true
      kubectl --context="$CONTEXT" delete secret --all -n bank-of-anthos --timeout=3m 2>/dev/null || true
      sleep 5
      
      echo "======================================"
      echo "Step 6: Delete ServiceAccounts (excluding default)"
      echo "======================================"
      kubectl --context="$CONTEXT" get sa -n bank-of-anthos -o name 2>/dev/null | grep -v "serviceaccount/default" | xargs -r kubectl --context="$CONTEXT" delete -n bank-of-anthos --timeout=3m 2>/dev/null || true
      sleep 5
      
      echo "======================================"
      echo "Step 7: Delete PVCs"
      echo "======================================"
      kubectl --context="$CONTEXT" delete pvc --all -n bank-of-anthos --timeout=5m 2>/dev/null || true
      sleep 10
      
      echo "======================================"
      echo "Step 8: Force delete any remaining pods"
      echo "======================================"
      kubectl --context="$CONTEXT" delete pods --all -n bank-of-anthos --grace-period=0 --force --timeout=3m 2>/dev/null || true
      sleep 5
      
      echo "======================================"
      echo "Step 9: Remove finalizers from stuck resources"
      echo "======================================"
      for ns in $(kubectl --context="$CONTEXT" get namespace bank-of-anthos -o name 2>/dev/null); do
        kubectl --context="$CONTEXT" patch $ns -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
      done
      
      for pod in $(kubectl --context="$CONTEXT" get pods -n bank-of-anthos -o name 2>/dev/null); do
        kubectl --context="$CONTEXT" patch $pod -n bank-of-anthos -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
      done
      
      for pvc in $(kubectl --context="$CONTEXT" get pvc -n bank-of-anthos -o name 2>/dev/null); do
        kubectl --context="$CONTEXT" patch $pvc -n bank-of-anthos -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
      done
      
      sleep 5
      
      echo "======================================"
      echo "Step 10: Delete namespace"
      echo "======================================"
      kubectl --context="$CONTEXT" delete namespace bank-of-anthos --timeout=5m 2>/dev/null || true
      
      # Force delete namespace if stuck
      kubectl --context="$CONTEXT" get namespace bank-of-anthos -o json 2>/dev/null | \
        jq '.spec.finalizers = []' | \
        kubectl --context="$CONTEXT" replace --raw /api/v1/namespaces/bank-of-anthos/finalize -f - 2>/dev/null || true
      
      echo "======================================"
      echo "Pre-cleanup completed for cluster ${self.triggers.cluster}"
      echo "======================================"
      
      exit 0
    EOF
  }

  lifecycle {
    create_before_destroy = false
  }

  depends_on = [
    null_resource.pre_cleanup_1
  ]
}

# ============================================
# FIXED: Application Installation for Cluster 2
# ============================================
resource "null_resource" "install_application_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_2
    region  = var.region_2
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<-EOF
      #!/bin/bash
      set -e  # Exit on any error
      
      # Configuration
      CLUSTER_NAME="${var.gke_cluster_2}"
      REGION="${var.region_2}"
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
      rm -rf ${path.module}/scripts/app/bank-of-anthos/cluster2
      mkdir -p ${path.module}/scripts/app/bank-of-anthos/cluster2
      sleep 5
      
      log_info "Cloning bank-of-anthos repository..."
      if ! git clone --branch v0.6.6 --single-branch \
        https://github.com/GoogleCloudPlatform/bank-of-anthos.git \
        ${path.module}/scripts/app/bank-of-anthos/cluster2 2>&1 | grep -v "detached HEAD"; then
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

      # FIX: Wait for cluster to be ready
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

      # FIX: Delete namespace if exists (clean slate)
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

      # FIX: Create namespace with retry
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

      # FIX: Wait for namespace to be fully ready
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

      # FIX: Additional safety wait for API sync
      log_info "Waiting for Kubernetes API to sync..."
      sleep 10

      # FIX: Label namespace with retry
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

      # FIX: Verify label
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
    null_resource.install_application_2,
    null_resource.app_multicluster_ingress_1,
    google_container_cluster.gke_autopilot_cluster_2,
    google_container_cluster.gke_standard_cluster_2,
    time_sleep.allow_10_minutes_for_fleet_synchronization_2,
  ]
}

# ============================================
# Individual Resource Deployments for Cluster 2
# ============================================
resource "null_resource" "config_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_2
    region  = var.region_2
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    gcloud container clusters get-credentials ${var.gke_cluster_2} --region ${var.region_2} --project ${local.project.project_id}
    CONTEXT="gke_${local.project.project_id}_${var.region_2}_${var.gke_cluster_2}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster2/kubernetes-manifests/config.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.install_application_2,
  ]
}

resource "null_resource" "jwt_secret_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_2
    region  = var.region_2
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    gcloud container clusters get-credentials ${var.gke_cluster_2} --region ${var.region_2} --project ${local.project.project_id}
    CONTEXT="gke_${local.project.project_id}_${var.region_2}_${var.gke_cluster_2}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster2/extras/jwt/jwt-secret.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.config_2,
  ]
}

resource "null_resource" "accounts_db_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_2
    region  = var.region_2
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    gcloud container clusters get-credentials ${var.gke_cluster_2} --region ${var.region_2} --project ${local.project.project_id}
    CONTEXT="gke_${local.project.project_id}_${var.region_2}_${var.gke_cluster_2}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster2/kubernetes-manifests/accounts-db.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.jwt_secret_2
  ]
}

resource "null_resource" "balance_reader_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_2
    region  = var.region_2
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    gcloud container clusters get-credentials ${var.gke_cluster_2} --region ${var.region_2} --project ${local.project.project_id}
    CONTEXT="gke_${local.project.project_id}_${var.region_2}_${var.gke_cluster_2}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster2/kubernetes-manifests/balance-reader.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.accounts_db_2
  ]
}

resource "null_resource" "contacts_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_2
    region  = var.region_2
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    gcloud container clusters get-credentials ${var.gke_cluster_2} --region ${var.region_2} --project ${local.project.project_id}
    CONTEXT="gke_${local.project.project_id}_${var.region_2}_${var.gke_cluster_2}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster2/kubernetes-manifests/contacts.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.balance_reader_2
  ]
}

resource "null_resource" "frontend_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_2
    region  = var.region_2
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    gcloud container clusters get-credentials ${var.gke_cluster_2} --region ${var.region_2} --project ${local.project.project_id}
    CONTEXT="gke_${local.project.project_id}_${var.region_2}_${var.gke_cluster_2}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster2/kubernetes-manifests/frontend.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.contacts_2
  ]
}

resource "null_resource" "ledger_db_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_2
    region  = var.region_2
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    gcloud container clusters get-credentials ${var.gke_cluster_2} --region ${var.region_2} --project ${local.project.project_id}
    CONTEXT="gke_${local.project.project_id}_${var.region_2}_${var.gke_cluster_2}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster2/kubernetes-manifests/ledger-db.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.frontend_2
  ]
}

resource "null_resource" "ledger_writer_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_2
    region  = var.region_2
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    gcloud container clusters get-credentials ${var.gke_cluster_2} --region ${var.region_2} --project ${local.project.project_id}
    CONTEXT="gke_${local.project.project_id}_${var.region_2}_${var.gke_cluster_2}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster2/kubernetes-manifests/ledger-writer.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.ledger_db_2
  ]
}

resource "null_resource" "loadgenerator_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_2
    region  = var.region_2
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    gcloud container clusters get-credentials ${var.gke_cluster_2} --region ${var.region_2} --project ${local.project.project_id}
    CONTEXT="gke_${local.project.project_id}_${var.region_2}_${var.gke_cluster_2}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster2/kubernetes-manifests/loadgenerator.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.ledger_writer_2
  ]
}

resource "null_resource" "transaction_history_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_2
    region  = var.region_2
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    gcloud container clusters get-credentials ${var.gke_cluster_2} --region ${var.region_2} --project ${local.project.project_id}
    CONTEXT="gke_${local.project.project_id}_${var.region_2}_${var.gke_cluster_2}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster2/kubernetes-manifests/transaction-history.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.loadgenerator_2
  ]
}

resource "null_resource" "userservice_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_2
    region  = var.region_2
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    gcloud container clusters get-credentials ${var.gke_cluster_2} --region ${var.region_2} --project ${local.project.project_id}
    CONTEXT="gke_${local.project.project_id}_${var.region_2}_${var.gke_cluster_2}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/scripts/app/bank-of-anthos/cluster2/kubernetes-manifests/userservice.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.transaction_history_2
  ]
}

resource "null_resource" "get_external_ip_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_2
    region  = var.region_2
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      attempt=0
      max_attempts=30
      gcloud container clusters get-credentials ${var.gke_cluster_2} --region ${var.region_2} --project ${local.project.project_id}
      CONTEXT="gke_${local.project.project_id}_${var.region_2}_${var.gke_cluster_2}"

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
    null_resource.frontend_2,
  ]
}

resource "null_resource" "app_configmap_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_2
    region  = var.region_2
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    gcloud container clusters get-credentials ${var.gke_cluster_2} --region ${var.region_2} --project ${local.project.project_id}
    CONTEXT="gke_${local.project.project_id}_${var.region_2}_${var.gke_cluster_2}"
    kubectl --context="$CONTEXT" apply -n istio-system -f ${path.module}/manifests/configmap.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.userservice_2,
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

resource "null_resource" "app_frontend_config_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_2
    region  = var.region_2
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    gcloud container clusters get-credentials ${var.gke_cluster_2} --region ${var.region_2} --project ${local.project.project_id}
    CONTEXT="gke_${local.project.project_id}_${var.region_2}_${var.gke_cluster_2}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/manifests/frontend_config.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.app_configmap_2,
  ]
}

resource "null_resource" "app_managed_certificate_config_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_2
    region  = var.region_2
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    gcloud container clusters get-credentials ${var.gke_cluster_2} --region ${var.region_2} --project ${local.project.project_id}
    CONTEXT="gke_${local.project.project_id}_${var.region_2}_${var.gke_cluster_2}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/manifests/managed_certificate.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.app_frontend_config_2
  ]
}

resource "null_resource" "app_backend_config_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_2
    region  = var.region_2
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    gcloud container clusters get-credentials ${var.gke_cluster_2} --region ${var.region_2} --project ${local.project.project_id}
    CONTEXT="gke_${local.project.project_id}_${var.region_2}_${var.gke_cluster_2}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/manifests/backend_config.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.app_managed_certificate_config_2
  ]
}

resource "null_resource" "app_nodeport_service_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cluster = var.gke_cluster_2
    region  = var.region_2
    project = local.project.project_id
  }

  provisioner "local-exec" {
    command = <<EOF
    set -e
    gcloud container clusters get-credentials ${var.gke_cluster_2} --region ${var.region_2} --project ${local.project.project_id}
    CONTEXT="gke_${local.project.project_id}_${var.region_2}_${var.gke_cluster_2}"
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/manifests/nodeport_service.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.app_backend_config_2,
  ]
}

# ============================================
# Final Cleanup for Cluster 2
# ============================================
resource "null_resource" "final_cleanup_2" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    cleanup_path = "${path.module}/scripts/app/bank-of-anthos/cluster2"
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOF
      echo "======================================"
      echo "Final cleanup - removing local files for cluster 2"
      echo "======================================"
      
      # Cleanup local files
      rm -rf ${self.triggers.cleanup_path}
      
      echo "Final cleanup completed for cluster 2"
    EOF
  }

  depends_on = [
    null_resource.app_nodeport_service_2,
    null_resource.pre_cleanup_2,
  ]
}

