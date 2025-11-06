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
    command = <<-EOT
      set -e
      echo "Downloading Bank of Anthos ${local.bank_of_anthos_version}..."
      mkdir -p ${local.download_path}
      
      # Download only if not already downloaded
      if [ ! -f ${local.download_path}/release.tar.gz ]; then
        curl -L -o ${local.download_path}/release.tar.gz ${local.release_url}
      fi
      
      echo "Extracting archive..."
      # Remove old extraction if exists
      rm -rf ${local.extracted_path}
      tar -xzf ${local.download_path}/release.tar.gz -C ${local.download_path}
      
      echo "Download and extraction complete!"
      echo "Files extracted to: ${local.extracted_path}"
      
      # Verify extraction
      if [ -d "${local.extracted_path}" ]; then
        echo "✓ Extracted directory exists"
        ls -la ${local.extracted_path}/extras/jwt/ || echo "JWT directory not found"
        ls -la ${local.extracted_path}/kubernetes-manifests/ || echo "Manifests directory not found"
      else
        echo "✗ Extraction failed - directory not found"
        exit 1
      fi
    EOT
  }

  provisioner "local-exec" {
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

# Deploy Bank of Anthos application using kubectl
resource "null_resource" "deploy_bank_of_anthos" {
  count = var.deploy_application ? 1 : 0

  triggers = {
    cluster_name     = google_container_cluster.gke_cluster.name
    cluster_endpoint = google_container_cluster.gke_cluster.endpoint
    version          = local.bank_of_anthos_version
    namespace        = "bank-of-anthos"
    region           = var.region
    project_id       = var.existing_project_id
    manifests_path   = local.manifests_path
    jwt_secret_path  = local.jwt_secret_path
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      # Get cluster credentials
      gcloud container clusters get-credentials ${self.triggers.cluster_name} \
        --region=${self.triggers.region} \
        --project=${self.triggers.project_id}
      
      # Wait for namespace to be ready
      echo "Waiting for namespace to be ready..."
      kubectl wait --for=condition=Ready namespace/${self.triggers.namespace} --timeout=60s || true
      
      # Apply JWT secret
      echo "Applying JWT secret from: ${self.triggers.jwt_secret_path}"
      kubectl apply -f ${self.triggers.jwt_secret_path} -n ${self.triggers.namespace}
      
      # Apply all manifests
      echo "Applying Bank of Anthos manifests from: ${self.triggers.manifests_path}"
      kubectl apply -f ${self.triggers.manifests_path} -n ${self.triggers.namespace}
      
      # Wait for deployments to be ready
      echo "Waiting for deployments to be ready..."
      kubectl wait --for=condition=available --timeout=300s \
        deployment --all -n ${self.triggers.namespace} || true
      
      echo "Bank of Anthos deployment complete!"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      
      # Get cluster credentials
      gcloud container clusters get-credentials ${self.triggers.cluster_name} \
        --region=${self.triggers.region} \
        --project=${self.triggers.project_id} || true
      
      # Delete the namespace (this will delete all resources in it)
      kubectl delete namespace ${self.triggers.namespace} --ignore-not-found=true --timeout=300s || true
    EOT
    on_failure = continue
  }

  depends_on = [
    null_resource.download_bank_of_anthos,
    kubernetes_namespace.bank_of_anthos,
    null_resource.wait_for_mesh_feature,
  ]
}

# Output to verify deployment
resource "null_resource" "verify_deployment" {
  count = var.deploy_application ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Verifying Bank of Anthos deployment..."
      kubectl get pods -n bank-of-anthos
      kubectl get services -n bank-of-anthos
    EOT
  }

  depends_on = [
    null_resource.deploy_bank_of_anthos,
  ]
}
