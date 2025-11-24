/**
 * Copyright 2023 Google LLC
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

resource "kubernetes_namespace" "bank_of_anthos" {
  count    = var.deploy_application ? 1 : 0

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
}

locals {
  manifest_path = "${path.module}/.terraform/bank-of-anthos"
}

resource "null_resource" "clone_bank_of_anthos" {
  count = var.deploy_application ? 1 : 0

  triggers = {
    version       = var.bank_of_anthos_version
    manifest_path = local.manifest_path
  }

  provisioner "local-exec" {
    command = "git clone --branch ${self.triggers.version} https://github.com/GoogleCloudPlatform/bank-of-anthos.git ${self.triggers.manifest_path}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ${self.triggers.manifest_path}"
  }
}

data "kubectl_path_documents" "manifests" {
  count     = var.deploy_application ? 1 : 0
  pattern   = "${local.manifest_path}/kubernetes-manifests/*.yaml"
  depends_on = [null_resource.clone_bank_of_anthos]
}

data "local_file" "jwt_secret" {
  count      = var.deploy_application ? 1 : 0
  filename   = "${local.manifest_path}/extras/jwt/jwt-secret.yaml"
  depends_on = [null_resource.clone_bank_of_anthos]
}

resource "kubectl_manifest" "bank_of_anthos_app" {
  count      = var.deploy_application ? 1 : 0
  override_namespace = kubernetes_namespace.bank_of_anthos[0].metadata[0].name
  yaml_body  = data.kubectl_path_documents.manifests[0].documents
  depends_on = [kubernetes_namespace.bank_of_anthos, null_resource.clone_bank_of_anthos]
}

resource "kubectl_manifest" "jwt_secret" {
  count      = var.deploy_application ? 1 : 0
  override_namespace = kubernetes_namespace.bank_of_anthos[0].metadata[0].name
  yaml_body  = data.local_file.jwt_secret[0].content
  depends_on = [kubernetes_namespace.bank_of_anthos, null_resource.clone_bank_of_anthos]
}
