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

resource "local_file" "backend_config_yaml_output" {
  content = templatefile("${path.module}/templates/backend_config.yaml.tpl", {
    APPLICATION_NAME      = "bank-of-anthos"
    APPLICATION_NAMESPACE = "bank-of-anthos"
  })
  filename = "${path.module}/manifests/backend_config.yaml"
}

resource "local_file" "configmap_yaml_output" {
  content = templatefile("${path.module}/templates/configmap.yaml.tpl", {
    # No variables needed for this template
  })
  filename = "${path.module}/manifests/configmap.yaml"
}

resource "local_file" "frontend_config_yaml_output" {
  content = templatefile("${path.module}/templates/frontend_config.yaml.tpl", {
    APPLICATION_NAME      = "bank-of-anthos"
    APPLICATION_NAMESPACE = "bank-of-anthos"
  })
  filename = "${path.module}/manifests/frontend_config.yaml"
}

resource "local_file" "ingress_yaml_output" {
  content = templatefile("${path.module}/templates/ingress.yaml.tpl", {
    INGRESS_NAME              = "boa-ingress",
    CERTIFICATE_NAME          = "boa-certificate",
    FRONTEND_SERVICE_NAME     = "frontend",
    FRONTEND_SERVICE_PORT     = "80",
    BACKEND_CONFIG_NAME       = "iap-backendconfig",
    APPLICATION_REGION        = local.cluster_configs["cluster1"].region,
    APPLICATION_NAME          = "bank-of-anthos",
    APPLICATION_NAMESPACE     = "bank-of-anthos",
    APPLICATION_DOMAIN        = "boa.${google_compute_global_address.glb.address}.sslip.io"
  })
  filename = "${path.module}/manifests/ingress.yaml"

  depends_on = [
    google_compute_global_address.glb,
  ]
}

resource "local_file" "managed_certificate_yaml_output" {
  content = templatefile("${path.module}/templates/managed_certificate.yaml.tpl", {
    APPLICATION_NAME      = "bank-of-anthos",
    APPLICATION_NAMESPACE = "bank-of-anthos",
    APPLICATION_DOMAIN    = "boa.${google_compute_global_address.glb.address}.sslip.io"
  })
  filename = "${path.module}/manifests/managed_certificate.yaml"

  depends_on = [
    google_compute_global_address.glb,
  ]
}

resource "local_file" "multicluster_service_yaml_output" {
  content = templatefile("${path.module}/templates/multicluster_service.yaml.tpl", {
    clusters               = values(local.cluster_configs),
    APPLICATION_NAME       = "bank-of-anthos",
    APPLICATION_NAMESPACE  = "bank-of-anthos"
  })
  filename = "${path.module}/manifests/multicluster_service.yaml"
}

resource "local_file" "multicluster_ingress_yaml_output" {
  content = templatefile("${path.module}/templates/multicluster_ingress.yaml.tpl", {
    INGRESS_NAME              = "boa-ingress",
    CERTIFICATE_NAME          = "boa-certificate",
    FRONTEND_SERVICE_NAME     = "frontend",
    FRONTEND_SERVICE_PORT     = "80",
    BACKEND_CONFIG_NAME       = "iap-backendconfig",
    APPLICATION_REGION        = local.cluster_configs["cluster1"].region,
    APPLICATION_NAME          = "bank-of-anthos",
    APPLICATION_NAMESPACE     = "bank-of-anthos",
    APPLICATION_DOMAIN        = "boa.${google_compute_global_address.glb.address}.sslip.io"
  })
  filename = "${path.module}/manifests/multicluster_ingress.yaml"

  depends_on = [
    google_compute_global_address.glb,
  ]
}

resource "local_file" "nodeport_service_yaml_output" {
  content = templatefile("${path.module}/templates/nodeport_service.yaml.tpl", {
    APPLICATION_NAME      = "bank-of-anthos",
    APPLICATION_NAMESPACE = "bank-of-anthos"
  })
  filename = "${path.module}/manifests/nodeport_service.yaml"
}
