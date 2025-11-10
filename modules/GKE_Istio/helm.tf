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

resource "null_resource" "gateway_api_crds" {
  provisioner "local-exec" {
    command = <<-EOT
      gcloud container clusters get-credentials ${google_container_cluster.gke_standard_cluster.name} \
        --region=${var.region} \
        --project=${local.project.project_id}
      
      kubectl apply -f ${path.module}/manifests/standard-install.yaml
    EOT
  }

  depends_on = [
    google_container_cluster.gke_standard_cluster
  ]
}

resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  namespace  = "istio-system"
  create_namespace = true

  depends_on = [
    google_container_cluster.gke_standard_cluster,
    null_resource.gateway_api_crds
  ]
}

resource "null_resource" "wait_for_istio_uninstall" {
  triggers = {
    install_ambient_mesh = var.install_ambient_mesh
  }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud container clusters get-credentials ${google_container_cluster.gke_standard_cluster.name} \
        --region=${var.region} \
        --project=${local.project.project_id}

      echo "Waiting for Istio uninstall to complete..."
      ATTEMPTS=0
      MAX_ATTEMPTS=60
      until ! kubectl get ns istio-system 2>/dev/null; do
        if [ $ATTEMPTS -ge $MAX_ATTEMPTS ]; then
          echo "Timed out waiting for Istio uninstall."
          exit 1
        fi
        echo "Istio namespace still exists, sleeping..."
        sleep 5
        ATTEMPTS=$((ATTEMPTS + 1))
      done
      echo "Istio uninstall complete."
    EOT
  }
}

resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  namespace  = "istio-system"

  # FIX: Remove profile setting for non-ambient, or use proper configuration
  dynamic "set" {
    for_each = var.install_ambient_mesh ? [1] : []
    content {
      name  = "profile"
      value = "ambient"
    }
  }

  # Optional: Add specific configurations instead of profile
  values = var.install_ambient_mesh ? [] : [
    <<-EOT
    pilot:
      resources:
        requests:
          cpu: 500m
          memory: 2048Mi
    global:
      proxy:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 2000m
            memory: 1024Mi
    EOT
  ]

  depends_on = [
    helm_release.istio_base
  ]
}

# GKE requires ResourceQuota for system-node-critical pods in non-kube-system namespaces
resource "kubernetes_resource_quota" "istio_system_critical_pods" {
  count = var.install_ambient_mesh ? 1 : 0
  
  metadata {
    name      = "gcp-critical-pods"
    namespace = "istio-system"
  }

  spec {
    hard = {
      pods = "1000"
    }
    
    scope_selector {
      match_expression {
        operator   = "In"
        scope_name = "PriorityClass"
        values     = ["system-node-critical"]
      }
    }
  }

  depends_on = [
    helm_release.istio_base
  ]
}

resource "helm_release" "istio_cni" {
  count      = var.install_ambient_mesh ? 1 : 0
  name       = "istio-cni"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "cni"
  namespace  = "istio-system"

  set {
    name  = "profile"
    value = "ambient"
  }

  depends_on = [
    helm_release.istiod,
    kubernetes_resource_quota.istio_system_critical_pods
  ]
}

resource "helm_release" "ztunnel" {
  count      = var.install_ambient_mesh ? 1 : 0
  name       = "ztunnel"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "ztunnel"
  namespace  = "istio-system"

  depends_on = [
    helm_release.istio_cni,
    kubernetes_resource_quota.istio_system_critical_pods
  ]
}

resource "helm_release" "istio_ingress" {
  name       = "istio-ingress"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  namespace  = "istio-system"

  depends_on = [
    helm_release.istiod
  ]
}

resource "null_resource" "install_observability_addons" {
  provisioner "local-exec" {
    command = <<-EOT
      gcloud container clusters get-credentials ${google_container_cluster.gke_standard_cluster.name} \
        --region=${var.region} \
        --project=${local.project.project_id}
      
      for addon in prometheus jaeger grafana kiali; do
        kubectl apply -f ${path.module}/manifests/$addon.yaml
      done
    EOT
  }

  depends_on = [
    helm_release.istio_ingress
  ]
}
