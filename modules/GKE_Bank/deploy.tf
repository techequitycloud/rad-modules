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

// ------------------------------------------------------------------
// Locals
// ------------------------------------------------------------------

locals {
  bank_of_anthos_version = "v0.6.7"
  release_url            = "https://github.com/GoogleCloudPlatform/bank-of-anthos/archive/refs/tags/${local.bank_of_anthos_version}.tar.gz"
  download_path          = "${path.module}/.terraform/bank-of-anthos"
  extracted_path         = "${local.download_path}/bank-of-anthos-${trimprefix(local.bank_of_anthos_version, "v")}"
  manifests_path         = "${local.extracted_path}/kubernetes-manifests"
  jwt_secret_path        = "${local.extracted_path}/extras/jwt/jwt-secret.yaml"
}

// ------------------------------------------------------------------
// Download and Extract Release
// ------------------------------------------------------------------

resource "null_resource" "download_and_extract_release" {
  count = var.deploy_application ? 1 : 0

  triggers = {
    version       = local.bank_of_anthos_version
    download_path = local.download_path
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      echo "Downloading Bank of Anthos ${local.bank_of_anthos_version}..."
      mkdir -p ${local.download_path}
      
      if [ ! -f ${local.download_path}/release.tar.gz ]; then
        curl -L -o ${local.download_path}/release.tar.gz ${local.release_url}
      fi
      
      rm -rf ${local.extracted_path}
      tar -xzf ${local.download_path}/release.tar.gz -C ${local.download_path}
      
      if [ ! -d "${local.extracted_path}" ]; then
        echo "Extraction failed - directory not found"
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

// ------------------------------------------------------------------
// Kubernetes Namespace
// ------------------------------------------------------------------

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

// ------------------------------------------------------------------
// Application Deployment
// ------------------------------------------------------------------

resource "null_resource" "deploy_application" {
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
      
      NAMESPACE="${self.triggers.namespace}"
      CLUSTER_NAME="${self.triggers.cluster_name}"
      REGION="${self.triggers.region}"
      PROJECT_ID="${self.triggers.project_id}"
      JWT_SECRET_PATH="${self.triggers.jwt_secret_path}"
      MANIFESTS_PATH="${self.triggers.manifests_path}"
      
      gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID"
      
      kubectl apply -f "$JWT_SECRET_PATH" -n "$NAMESPACE" --server-side --force-conflicts
      kubectl apply -f "$MANIFESTS_PATH" -n "$NAMESPACE"
      
      kubectl wait --for=condition=available --timeout=600s \
        deployment --all -n "$NAMESPACE"
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

      if gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" 2>/dev/null; then
        
        if kubectl get namespace "$NAMESPACE" --no-headers 2>/dev/null; then
          kubectl delete namespace "$NAMESPACE" --timeout=300s
        fi
      fi
    EOT
    on_failure = continue
  }

  depends_on = [
    null_resource.download_and_extract_release,
    kubernetes_namespace.bank_of_anthos,
    null_resource.wait_for_service_mesh,
  ]
}
