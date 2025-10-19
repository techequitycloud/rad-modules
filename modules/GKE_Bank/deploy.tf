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

resource "null_resource" "install_application" {
  count   = var.deploy_application ? 1 : 0 
    triggers = {
      always_run = "${timestamp()}" # Trigger that changes every plan/apply, forcing this resource to run every time
    }

  provisioner "local-exec" {
    command = <<-EOF
      # set -x

      rm -rf ${path.module}/scripts/app/bank-of-anthos

      git clone --branch v0.6.6 --single-branch https://github.com/GoogleCloudPlatform/bank-of-anthos.git ${path.module}/scripts/app/bank-of-anthos

      # Get cluster credentials
      gcloud container clusters get-credentials ${var.gke_cluster} --region ${var.region} --project ${local.project.project_id} || true
      CONTEXT=$(kubectl config view -o jsonpath="{.users[0].name}")

      # Try up to 30 times to create the namespace
      for i in {1..30}; do
        # Check if the namespace already exists
        if kubectl get namespace istio-system; then
          echo "Namespace 'istio-system' already exists"
          break
        else
          # Attempt to create the namespace
          if kubectl create namespace istio-system; then
            echo "Namespace 'istio-system' created successfully"
            break
          else
            echo "Failed to create namespace 'istio-system' (attempt $i of 30)"
            if [ "$i" -eq 30 ]; then
              echo "Failed to create namespace after 30 attempts"
              exit 1
            fi
            sleep 10
          fi
        fi
      done

      # Try up to 30 times to create the namespace
      for i in {1..30}; do
        # Check if the namespace already exists
        if kubectl get namespace bank-of-anthos; then
          echo "Namespace 'bank-of-anthos' already exists"
          break
        else
          # Attempt to create the namespace
          if kubectl create namespace bank-of-anthos; then
            echo "Namespace 'bank-of-anthos' created successfully"
            break
          else
            echo "Failed to create namespace 'bank-of-anthos' (attempt $i of 30)"
            if [ "$i" -eq 30 ]; then
              echo "Failed to create namespace after 30 attempts"
              exit 1
            fi
            sleep 5
          fi
        fi
      done

      kubectl label namespace bank-of-anthos istio.io/rev=asm-managed --overwrite

      kubectl -n bank-of-anthos apply -f ${path.module}/scripts/app/bank-of-anthos/extras/jwt/jwt-secret.yaml
      kubectl -n bank-of-anthos apply -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/accounts-db.yaml
      kubectl -n bank-of-anthos apply -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/balance-reader.yaml
      kubectl -n bank-of-anthos apply -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/config.yaml
      kubectl -n bank-of-anthos apply -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/contacts.yaml
      kubectl -n bank-of-anthos apply -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/frontend.yaml
      kubectl -n bank-of-anthos apply -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/ledger-db.yaml
      kubectl -n bank-of-anthos apply -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/ledger-writer.yaml
      kubectl -n bank-of-anthos apply -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/loadgenerator.yaml
      kubectl -n bank-of-anthos apply -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/transaction-history.yaml
      kubectl -n bank-of-anthos apply -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/userservice.yaml
      kubectl -n bank-of-anthos apply -f ${path.module}/manifests/backend_config.yaml
      kubectl -n istio-system apply -f ${path.module}/manifests/configmap.yaml
      kubectl -n bank-of-anthos apply -f ${path.module}/manifests/frontend_config.yaml
      kubectl -n bank-of-anthos apply -f ${path.module}/manifests/ingress.yaml
      kubectl -n bank-of-anthos apply -f ${path.module}/manifests/managed_certificate.yaml
      kubectl -n bank-of-anthos apply -f ${path.module}/manifests/nodeport_service.yaml
      
      
      # Function to check if istio-system namespace exists
      check_istio_system() {
        kubectl get namespace istio-system
        return $?
      }

      # Start time
      start_time=$(date +%s)

      # Loop for 30 minutes (1800 seconds)
      while true; do
        if check_istio_system; then
          echo "istio-system namespace is created. Proceeding to next steps..."
          kubectl rollout restart deployment -n bank-of-anthos
          exit 0
        fi

        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))

        if [ $elapsed_time -ge 1800 ]; then
          echo "Timeout: istio-system namespace was not created within 30 minutes. Aborting."
          exit 0
        fi

        echo "istio-system namespace not found. Waiting for 10 seconds before checking again..."
        sleep 10
      done

      exit 0
    EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOF
      # set -x

      echo "Deleting application resources"
      kubectl -n bank-of-anthos delete -f ${path.module}/scripts/app/bank-of-anthos/extras/jwt/jwt-secret.yaml
      kubectl -n bank-of-anthos delete -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/accounts-db.yaml
      kubectl -n bank-of-anthos delete -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/balance-reader.yaml
      kubectl -n bank-of-anthos delete -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/config.yaml
      kubectl -n bank-of-anthos delete -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/contacts.yaml
      kubectl -n bank-of-anthos delete -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/frontend.yaml
      kubectl -n bank-of-anthos delete -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/ledger-db.yaml
      kubectl -n bank-of-anthos delete -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/ledger-writer.yaml
      kubectl -n bank-of-anthos delete -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/loadgenerator.yaml
      kubectl -n bank-of-anthos delete -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/transaction-history.yaml
      kubectl -n bank-of-anthos delete -f ${path.module}/scripts/app/bank-of-anthos/kubernetes-manifests/userservice.yaml
      kubectl -n bank-of-anthos delete -f ${path.module}/manifests/backend_config.yaml
      kubectl -n istio-system delete -f ${path.module}/manifests/configmap.yaml
      kubectl -n bank-of-anthos delete -f ${path.module}/manifests/frontend_config.yaml
      kubectl -n bank-of-anthos delete -f ${path.module}/manifests/ingress.yaml
      kubectl -n bank-of-anthos delete -f ${path.module}/manifests/managed_certificate.yaml
      kubectl -n bank-of-anthos delete -f ${path.module}/manifests/nodeport_service.yaml
      # kubectl delete namespace bank-of-anthos --force --grace-period=0

      echo "Deleting the application files"
      rm -rf ${path.module}/scripts/app/bank-of-anthos

      exit 0
    EOF
  }

  depends_on = [
    time_sleep.allow_10_minutes_for_fleet_synchronization,
  ]
}

resource "null_resource" "get_external_ip" {
  count   = var.deploy_application ? 1 : 0 

  provisioner "local-exec" {
    command = <<-EOT
      attempt=0
      max_attempts=30

      while [ $attempt -lt $max_attempts ]; do
        # Check if the service exists
        EXISTS=$(kubectl get svc frontend --namespace=bank-of-anthos --ignore-not-found)
        if [ -z "$EXISTS" ]; then
          echo "Service 'frontend' does not exist yet in namespace 'bank-of-anthos'. Waiting..."
          sleep 10
          attempt=$((attempt + 1))
          continue
        fi

        # Attempt to get the IP if the service exists
        IP=$(kubectl get svc frontend --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}" --namespace=bank-of-anthos)
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
    null_resource.install_application,
  ]
}

resource "local_file" "configmap_yaml_output" {
  count    = var.deploy_application ? 1 : 0 
  filename = "${path.module}/manifests/configmap.yaml"
  
  # Content is generated from a template file with variables substituted in.
  content = templatefile("${path.module}/templates/configmap.yaml.tpl", {
  })

  # Dependencies for the local file resource.
  depends_on = [
    time_sleep.allow_10_minutes_for_fleet_synchronization,
    null_resource.get_external_ip
  ]
}

resource "local_file" "frontend_config_yaml_output" {
  count    = var.deploy_application ? 1 : 0 
  filename = "${path.module}/manifests/frontend_config.yaml"
  
  # Content is generated from a template file with variables substituted in.
  content = templatefile("${path.module}/templates/frontend_config.yaml.tpl", {
    APPLICATION_NAME          = "bank-of-anthos"
    APPLICATION_NAMESPACE     = "bank-of-anthos"
  })

  # Dependencies for the local file resource.
  depends_on = [
    time_sleep.allow_10_minutes_for_fleet_synchronization,
    null_resource.get_external_ip
  ]
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

  # Dependencies for the local file resource.
  depends_on = [
    time_sleep.allow_10_minutes_for_fleet_synchronization,
    null_resource.get_external_ip
  ]
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
    time_sleep.allow_10_minutes_for_fleet_synchronization,
    google_compute_global_address.glb,
    null_resource.get_external_ip
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

  # Dependencies for the local file resource.
  depends_on = [
    time_sleep.allow_10_minutes_for_fleet_synchronization,
    null_resource.get_external_ip
  ]
}

resource "local_file" "ingress_yaml_output" {
  count    = var.deploy_application ? 1 : 0 
  filename = "${path.module}/manifests/ingress.yaml"
  
  # Content is generated from a template file with variables substituted in.
  content = templatefile("${path.module}/templates/ingress.yaml.tpl", {
    GCP_PROJECT               = local.project.project_id
    APPLICATION_NAME          = "bank-of-anthos"
    APPLICATION_REGION        = var.region
    APPLICATION_NAMESPACE     = "bank-of-anthos"
    APPLICATION_DOMAIN        = "boa.${google_compute_global_address.glb.address}.sslip.io"
  })

  # Dependencies for the local file resource.
  depends_on = [
    time_sleep.allow_10_minutes_for_fleet_synchronization,
    google_compute_global_address.glb,
    null_resource.get_external_ip
  ]
}

module "app_configmap" {
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = var.gke_cluster
  cluster_location            = var.region
  kubectl_create_command      = "kubectl apply -f ${path.module}/manifests/configmap.yaml"
  
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
# set -x
kubectl delete -f ${path.module}/manifests/configmap.yaml 2>/dev/null || true'
EOF

  impersonate_service_account = length(var.resource_creator_identity) != 0 ? var.resource_creator_identity : ""
  skip_download               = true # Avoid downloading if the gcloud is already present
  upgrade                     = false # Disable auto-upgrade of the gcloud
  use_existing_context        = false # Do not use an existing kubectl context

  # Ensure that module creation waits on these dependencies.
  module_depends_on = [
    local_file.backend_config_yaml_output,
    local_file.configmap_yaml_output,
    local_file.frontend_config_yaml_output,
    local_file.ingress_yaml_output,
    local_file.managed_certificate_yaml_output,
    local_file.nodeport_service_yaml_output,
  ]
}

module "app_frontend_config" {
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = var.gke_cluster
  cluster_location            = var.region
  kubectl_create_command      = "kubectl apply -f ${path.module}/manifests/frontend_config.yaml"
  
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
# set -x
kubectl delete -f ${path.module}/manifests/frontend_config.yaml 2>/dev/null || true'
EOF

  impersonate_service_account = length(var.resource_creator_identity) != 0 ? var.resource_creator_identity : ""
  skip_download               = true # Avoid downloading if the gcloud is already present
  upgrade                     = false # Disable auto-upgrade of the gcloud
  use_existing_context        = false # Do not use an existing kubectl context

  # Ensure that module creation waits on these dependencies.
  module_depends_on = [
    module.app_configmap,
  ]
}

module "app_managed_certificate_config" {
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = var.gke_cluster
  cluster_location            = var.region
  kubectl_create_command      = "kubectl apply -f ${path.module}/manifests/managed_certificate.yaml"
  
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
# set -x
kubectl delete -f ${path.module}/manifests/managed_certificate.yaml 2>/dev/null || true'
EOF

  impersonate_service_account = length(var.resource_creator_identity) != 0 ? var.resource_creator_identity : ""
  skip_download               = true # Avoid downloading if the gcloud is already present
  upgrade                     = false # Disable auto-upgrade of the gcloud
  use_existing_context        = false # Do not use an existing kubectl context

  # Ensure that module creation waits on these dependencies.
  module_depends_on = [
    module.app_configmap,
  ]
}

module "app_backend_config" {
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = var.gke_cluster
  cluster_location            = var.region
  kubectl_create_command      = "kubectl apply -f ${path.module}/manifests/backend_config.yaml"
  
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
# set -x
kubectl delete -f ${path.module}/manifests/backend_config.yaml 2>/dev/null || true'
EOF

  impersonate_service_account = length(var.resource_creator_identity) != 0 ? var.resource_creator_identity : ""
  skip_download               = true # Avoid downloading if the gcloud is already present
  upgrade                     = false # Disable auto-upgrade of the gcloud
  use_existing_context        = false # Do not use an existing kubectl context

  # Ensure that module creation waits on these dependencies.
  module_depends_on = [
    module.app_configmap,
  ]
}

module "app_nodeport_service" {
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = var.gke_cluster
  cluster_location            = var.region
  kubectl_create_command      = "kubectl apply -f ${path.module}/manifests/nodeport_service.yaml"
  
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
# set -x
kubectl delete -f ${path.module}/manifests/nodeport_service.yaml 2>/dev/null || true'
EOF

  impersonate_service_account = length(var.resource_creator_identity) != 0 ? var.resource_creator_identity : ""
  skip_download               = true # Avoid downloading if the gcloud is already present
  upgrade                     = false # Disable auto-upgrade of the gcloud
  use_existing_context        = false # Do not use an existing kubectl context

  # Ensure that module creation waits on these dependencies.
  module_depends_on = [
    module.app_configmap,
    module.app_backend_config,
  ]
}

module "app_ingress" {
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = var.gke_cluster
  cluster_location            = var.region
  kubectl_create_command      = "kubectl apply -f ${path.module}/manifests/ingress.yaml && sleep 5 && kubectl patch service bank-of-anthos -p '{\"spec\": {\"type\": \"NodePort\"}}' -n bank-of-anthos && kubectl rollout restart deployment -n bank-of-anthos"
  
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
# set -x
kubectl delete -f ${path.module}/manifests/ingress.yaml 2>/dev/null || true'
EOF

  impersonate_service_account = length(var.resource_creator_identity) != 0 ? var.resource_creator_identity : ""
  skip_download               = true # Avoid downloading if the gcloud is already present
  upgrade                     = false # Disable auto-upgrade of the gcloud
  use_existing_context        = false # Do not use an existing kubectl context

  # Ensure that module creation waits on these dependencies.
  module_depends_on = [
    module.app_configmap,
    module.app_nodeport_service,
  ]
}
