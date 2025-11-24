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
      echo "Downloading Bank of Anthos v${local.bank_of_anthos_version}..."
      mkdir -p "${local.download_path}"
      
      if [ ! -f "${local.download_path}/release.tar.gz" ]; then
        curl -L -o "${local.download_path}/release.tar.gz" "${local.release_url}"
      fi
      
      echo "Extracting Bank of Anthos..."
      tar -xzf "${local.download_path}/release.tar.gz" -C "${local.download_path}"
      
      if [ ! -d "${local.extracted_path}" ]; then
        echo "Extraction failed: '${local.extracted_path}' not found" >&2
        exit 1
      fi
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
    region           = var.region
    project_id       = local.project.project_id
    manifests_path   = local.manifests_path
    jwt_secret_path  = local.jwt_secret_path
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      
      # Get cluster credentials
      gcloud container clusters get-credentials "${self.triggers.cluster_name}" \
        --region "${self.triggers.region}" \
        --project "${self.triggers.project_id}"
      
      # Apply JWT secret and manifests
      kubectl apply -f "${self.triggers.jwt_secret_path}" -n "${self.triggers.namespace}"
      kubectl apply -f "${self.triggers.manifests_path}" -n "${self.triggers.namespace}"
      
      # Wait for deployments to be ready
      echo "Waiting for deployments to be ready..."
      if ! kubectl wait --for=condition=available --timeout=600s deployment --all -n "${self.triggers.namespace}"; then
        echo "Deployments did not become ready in time" >&2
        
        # Display debug information
        kubectl get deployments -n "${self.triggers.namespace}"
        kubectl get pods -n "${self.triggers.namespace}"
        exit 1
      fi
      
      echo "Bank of Anthos deployment completed successfully."
    EOT
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    when    = destroy
    command = <<-EOT
      set -e
      
      # Get cluster credentials
      if gcloud container clusters get-credentials "${self.triggers.cluster_name}" \
        --region "${self.triggers.region}" \
        --project "${self.triggers.project_id}"; then
        
        # Delete namespace and all its resources
        kubectl delete namespace "${self.triggers.namespace}" --ignore-not-found=true
      else
        echo "Could not connect to cluster, skipping namespace deletion."
      fi
    EOT
    on_failure = continue
  }

  depends_on = [
    null_resource.download_bank_of_anthos,
    kubernetes_namespace.bank_of_anthos,
    null_resource.wait_for_service_mesh,
  ]
}

