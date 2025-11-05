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

locals {
  istio_version = regex("^(.*?)-asm\\.\\d+$", var.cloud_service_mesh_version)[0]
  script_version = regex("^(\\d+\\.\\d+).*", var.cloud_service_mesh_version)[0]
}

resource "local_file" "configmap_yaml_output" {
  count    = var.deploy_application ? 1 : 0 
  filename = "${path.module}/manifests/configmap.yaml"
  
  # Content is generated from a template file with variables substituted in.
  content = templatefile("${path.module}/templates/configmap.yaml.tpl", {
  })
}

resource "local_file" "frontend_config_yaml_output" {
  count    = var.deploy_application ? 1 : 0 
  filename = "${path.module}/manifests/frontend_config.yaml"
  
  # Content is generated from a template file with variables substituted in.
  content = templatefile("${path.module}/templates/frontend_config.yaml.tpl", {
    APPLICATION_NAME          = "bank-of-anthos"
    APPLICATION_NAMESPACE     = "bank-of-anthos"
  })
}

resource "local_file" "managed_certificate_yaml_output" {
  count    = var.deploy_application ? 1 : 0 
  filename = "${path.module}/manifests/managed_certificate.yaml"
  
  # Content is generated from a template file with variables substituted in.
  content = templatefile("${path.module}/templates/managed_certificate.yaml.tpl", {
    APPLICATION_NAME          = "bank-of-anthos"
    APPLICATION_NAMESPACE     = "bank-of-anthos"
    APPLICATION_DOMAIN        = "boa.${google_compute_global_address.glb.address}.sslip.io"
  })
}

resource "local_file" "backend_config_yaml_output" {
  count    = var.deploy_application ? 1 : 0 
  filename = "${path.module}/manifests/backend_config.yaml"
  
  # Content is generated from a template file with variables substituted in.
  content = templatefile("${path.module}/templates/backend_config.yaml.tpl", {
    GCP_PROJECT               = local.project.project_id
    APPLICATION_NAME          = "bank-of-anthos"
    APPLICATION_NAMESPACE     = "bank-of-anthos"
  })

  # Dependencies for the local file resource.
  depends_on = [
    google_compute_global_address.glb,
  ]
}

resource "local_file" "nodeport_service_yaml_output" {
  count    = var.deploy_application ? 1 : 0 
  filename = "${path.module}/manifests/nodeport_service.yaml"
  
  # Content is generated from a template file with variables substituted in.
  content = templatefile("${path.module}/templates/nodeport_service.yaml.tpl", {
    APPLICATION_NAME          = "bank-of-anthos"
    APPLICATION_NAMESPACE     = "bank-of-anthos"
  })
}

resource "local_file" "ingress_yaml_output" {
  count    = var.deploy_application ? 1 : 0 
  filename = "${path.module}/manifests/ingress.yaml"
  
  # Content is generated from a template file with variables substituted in.
  content = templatefile("${path.module}/templates/ingress.yaml.tpl", {
    GCP_PROJECT               = local.project.project_id
    APPLICATION_NAME          = "bank-of-anthos"
    APPLICATION_REGION        = var.cluster_configs["cluster1"].region
    APPLICATION_NAMESPACE     = "bank-of-anthos"
    APPLICATION_DOMAIN        = "boa.${google_compute_global_address.glb.address}.sslip.io"
  })

  # Dependencies for the local file resource.
  depends_on = [
    google_compute_global_address.glb,
  ]
}

resource "local_file" "multicluster_service_yaml_output" {
  count    = var.deploy_application ? 1 : 0
  filename = "${path.module}/manifests/multicluster_service.yaml"

  content = <<-EOT
apiVersion: networking.gke.io/v1
kind: MultiClusterService
metadata:
  name: frontend
  namespace: bank-of-anthos
spec:
  template:
    spec:
      selector:
        app: frontend
      ports:
      - name: http
        protocol: TCP
        port: 80
        targetPort: 8080
  clusters:
%{for key, cluster in var.cluster_configs ~}
  - link: "projects/${local.project.project_id}/locations/${cluster.region}/clusters/${cluster.gke_cluster_name}"
%{endfor ~}
EOT

  depends_on = [
    google_compute_global_address.glb,
  ]
}

resource "local_file" "multicluster_ingress_yaml_output" {
  count    = var.deploy_application ? 1 : 0 
  filename = "${path.module}/manifests/multicluster_ingress.yaml"
  
  # Content is generated from a template file with variables substituted in.
  content = templatefile("${path.module}/templates/multicluster_ingress.yaml.tpl", {
    GCP_PROJECT               = local.project.project_id
    APPLICATION_NAME          = "bank-of-anthos"
    APPLICATION_REGION        = var.cluster_configs["cluster1"].region
    APPLICATION_NAMESPACE     = "bank-of-anthos"
  })

  # Dependencies for the local file resource.
  depends_on = [
    google_compute_global_address.glb,
  ]
}
