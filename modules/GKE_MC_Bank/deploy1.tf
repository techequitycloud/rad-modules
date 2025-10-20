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
      
      # Cleanup and clone
      rm -rf ${path.module}/scripts/app/bank-of-anthos/cluster1
      mkdir -p ${path.module}/scripts/app/bank-of-anthos/cluster1
      sleep 5
      
      if ! git clone --branch v0.6.6 --single-branch https://github.com/GoogleCloudPlatform/bank-of-anthos.git ${path.module}/scripts/app/bank-of-anthos/cluster1; then
        echo "ERROR: Failed to clone repository"
        exit 1
      fi

      # Get cluster credentials
      if ! gcloud container clusters get-credentials ${var.gke_cluster_1} --region ${var.region_1} --project ${local.project.project_id}; then
        echo "ERROR: Failed to get cluster credentials"
        exit 1
      fi
      
      CONTEXT="gke_${local.project.project_id}_${var.region_1}_${var.gke_cluster_1}"

      # Wait for cluster to be ready
      echo "Waiting for cluster to be ready..."
      CLUSTER_READY=false
      for i in {1..60}; do
        if kubectl --context="$CONTEXT" get nodes &> /dev/null; then
          echo "✓ Cluster is ready"
          CLUSTER_READY=true
          break
        fi
        echo "  Waiting... (attempt $i/60)"
        sleep 10
      done

      if [ "$CLUSTER_READY" = false ]; then
        echo "ERROR: Cluster not ready after 10 minutes"
        exit 1
      fi

      # Create or verify namespace
      echo "Setting up bank-of-anthos namespace..."
      NAMESPACE_READY=false
      for i in {1..30}; do
        if kubectl --context="$CONTEXT" get namespace bank-of-anthos &> /dev/null; then
          echo "✓ Namespace 'bank-of-anthos' already exists"
          NAMESPACE_READY=true
          break
        elif kubectl --context="$CONTEXT" create namespace bank-of-anthos 2>/dev/null; then
          echo "✓ Namespace 'bank-of-anthos' created"
          NAMESPACE_READY=true
          break
        fi
        echo "  Retrying namespace creation... (attempt $i/30)"
        sleep 10
      done

      if [ "$NAMESPACE_READY" = false ]; then
        echo "ERROR: Failed to create namespace after 30 attempts"
        exit 1
      fi

      # Label namespace
      if ! kubectl --context="$CONTEXT" label namespace bank-of-anthos istio.io/rev=asm-managed --overwrite; then
        echo "ERROR: Failed to label namespace"
        exit 1
      fi
      echo "✓ Namespace labeled for sidecar injection"

      # Wait for istio-system
      echo "Checking for istio-system namespace..."
      ISTIO_READY=false
      for i in {1..30}; do
        if kubectl --context="$CONTEXT" get namespace istio-system &> /dev/null; then
          echo "✓ Namespace istio-system found"
          ISTIO_READY=true
          break
        fi
        echo "  Waiting for istio-system... (attempt $i/30)"
        sleep 10
      done

      if [ "$ISTIO_READY" = false ]; then
        echo "ERROR: istio-system namespace not found after 5 minutes"
        exit 1
      fi

      echo "======================================"
      echo "✓ Installation preparation completed"
      echo "======================================"
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
    kubectl --context="$CONTEXT" create namespace bank-of-anthos 2>/dev/null || true
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
    kubectl --context="$CONTEXT" create namespace bank-of-anthos 2>/dev/null || true
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
    kubectl --context="$CONTEXT" create namespace bank-of-anthos 2>/dev/null || true
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
    kubectl --context="$CONTEXT" create namespace bank-of-anthos 2>/dev/null || true
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
    kubectl --context="$CONTEXT" create namespace bank-of-anthos 2>/dev/null || true
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
    kubectl --context="$CONTEXT" create namespace bank-of-anthos 2>/dev/null || true
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
    kubectl --context="$CONTEXT" create namespace bank-of-anthos 2>/dev/null || true
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
    kubectl --context="$CONTEXT" create namespace bank-of-anthos 2>/dev/null || true
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
    kubectl --context="$CONTEXT" create namespace bank-of-anthos 2>/dev/null || true
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
    kubectl --context="$CONTEXT" create namespace bank-of-anthos 2>/dev/null || true
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
    kubectl --context="$CONTEXT" create namespace bank-of-anthos 2>/dev/null || true
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
    kubectl --context="$CONTEXT" create namespace bank-of-anthos 2>/dev/null || true
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
    kubectl --context="$CONTEXT" create namespace bank-of-anthos 2>/dev/null || true
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
    kubectl --context="$CONTEXT" create namespace bank-of-anthos 2>/dev/null || true
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
    kubectl --context="$CONTEXT" create namespace bank-of-anthos 2>/dev/null || true
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
    kubectl --context="$CONTEXT" create namespace bank-of-anthos 2>/dev/null || true
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
    kubectl --context="$CONTEXT" create namespace bank-of-anthos 2>/dev/null || true
    kubectl --context="$CONTEXT" apply -n bank-of-anthos -f ${path.module}/manifests/multicluster_ingress.yaml --timeout=5m
    EOF
  }

  depends_on = [
    null_resource.app_multicluster_service_1,
  ]
}

# ============================================
# Final Cleanup - Runs LAST on destroy
# ============================================
resource "null_resource" "final_cleanup_1" {
  count = var.deploy_application ? 1 : 0
  
  triggers = {
    # Store the path for cleanup
    cleanup_path = "${path.module}/scripts/app/bank-of-anthos/cluster1"
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOF
      echo "======================================"
      echo "Final cleanup - removing local files"
      echo "======================================"
      
      # Cleanup local files
      rm -rf ${self.triggers.cleanup_path}
      
      echo "Final cleanup completed"
    EOF
  }

  depends_on = [
    null_resource.app_multicluster_ingress_1,
    null_resource.pre_cleanup_1,
  ]
}
