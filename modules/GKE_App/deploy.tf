# Copyright 2024 (c) Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Resource to obtain GKE credentials using a null resource which allows running arbitrary commands
resource "null_resource" "get_gke_credentials" {
  triggers = {
    always_run = "${timestamp()}"                
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = local.k8s_credentials_cmd          
  }

  depends_on = [
    local_file.dev_deployment_yaml_output,
    local_file.qa_deployment_yaml_output,
    local_file.prod_deployment_yaml_output,
    google_secret_manager_secret.dev_db_password,
    google_secret_manager_secret.qa_db_password,
    google_secret_manager_secret.prod_db_password,
    null_resource.build_and_push_backup_image,
    null_resource.import_dev_db,
    null_resource.import_qa_db,
    null_resource.import_prod_db,
   ]
}

#########################################################################
# Configure Namespaces and Secrets
#########################################################################
module "app_dev_namespace" {
  # Simplified condition - only check what's actually needed for namespace
  count                       = local.gke_cluster_exists ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl create namespace ${var.application_name}${var.tenant_deployment_id}dev || true
' || true
EOF
  kubectl_destroy_command     = <<EOL
timeout 300 bash -c '
kubectl delete namespace ${var.application_name}${var.tenant_deployment_id}dev --force || true
' || true
EOL

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    null_resource.import_dev_db,
  ]
}

module "app_qa_namespace" {
  # Simplified condition - only check what's actually needed for namespace
  count                       = local.gke_cluster_exists ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl create namespace ${var.application_name}${var.tenant_deployment_id}qa || true
' || true
EOF
  kubectl_destroy_command     = <<EOL
timeout 300 bash -c '
kubectl delete namespace ${var.application_name}${var.tenant_deployment_id}qa --force || true
' || true
EOL

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    null_resource.import_qa_db,
  ]
}

module "app_prod_namespace" {
  # Simplified condition - only check what's actually needed for namespace
  count                       = local.gke_cluster_exists ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl create namespace ${var.application_name}${var.tenant_deployment_id}prod || true
' || true
EOF
  kubectl_destroy_command     = <<EOL
timeout 300 bash -c '
kubectl delete namespace ${var.application_name}${var.tenant_deployment_id}prod --force || true
' || true
EOL

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    null_resource.import_prod_db,
  ]
}

module "app_dev_secret" {
  count                       = local.gke_cluster_exists && (var.configure_development_environment || var.configure_continuous_deployment) ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl create secret generic app${var.application_database_name}${local.random_id}dev-password --namespace=${var.application_name}${var.tenant_deployment_id}dev --from-literal=password=${data.google_secret_manager_secret_version.dev_db_password[0].secret_data} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete secret app${var.application_database_name}${local.random_id}dev-password --namespace=${var.application_name}${var.tenant_deployment_id}dev --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.app_dev_namespace,
  ]
}

module "app_qa_secret" {
  count                       = local.gke_cluster_exists && (var.configure_nonproduction_environment || var.configure_continuous_deployment) ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl create secret generic app${var.application_database_name}${local.random_id}qa-password --namespace=${var.application_name}${var.tenant_deployment_id}qa --from-literal=password=${data.google_secret_manager_secret_version.qa_db_password[0].secret_data} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete secret app${var.application_database_name}${local.random_id}qa-password --namespace=${var.application_name}${var.tenant_deployment_id}qa --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.app_qa_namespace,
  ]
}

module "app_prod_secret" {
  count                       = local.gke_cluster_exists && (var.configure_production_environment || var.configure_continuous_deployment) ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl create secret generic app${var.application_database_name}${local.random_id}prod-password --namespace=${var.application_name}${var.tenant_deployment_id}prod --from-literal=password=${data.google_secret_manager_secret_version.prod_db_password[0].secret_data} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete secret app${var.application_database_name}${local.random_id}prod-password --namespace=${var.application_name}${var.tenant_deployment_id}prod --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.app_prod_namespace,
  ]
}

#########################################################################
# Deploy to Dev environment
#########################################################################

module "deploy_dev_frontend_config" {
  count                       = local.gke_cluster_exists && var.configure_development_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.dev_frontend_config_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.dev_frontend_config_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.app_dev_namespace,
  ]
}

module "deploy_dev_backend_config" {
  count                       = local.gke_cluster_exists && var.configure_development_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.dev_backend_config_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.dev_backend_config_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.app_dev_namespace,
  ]
}

module "deploy_dev_horizontal_pod_autoscaler" {
  count                       = local.gke_cluster_exists && var.configure_development_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.dev_horizontal_pod_autoscaler_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.dev_horizontal_pod_autoscaler_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.deploy_dev_deployment,
  ]
}

module "deploy_dev_ingress" {
  count                       = local.gke_cluster_exists && var.configure_development_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.dev_ingress_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.dev_ingress_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.deploy_dev_frontend_config,
    module.deploy_dev_service_nodeport,
    module.deploy_dev_managed_certificate,
    module.deploy_dev_service_nodeport,
    # google_compute_global_address.dev,
  ]
}

module "deploy_dev_managed_certificate" {
  count                       = local.gke_cluster_exists && var.configure_development_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.dev_managed_certificate_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.dev_managed_certificate_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.app_dev_namespace,
  ]
}

module "deploy_dev_service_account" {
  count                       = local.gke_cluster_exists ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.dev_service_account_yaml_output.filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.dev_service_account_yaml_output.filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.app_dev_namespace,
  ]
}

module "deploy_dev_service_nodeport" {
  count                       = local.gke_cluster_exists && var.configure_development_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.dev_service_nodeport_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.dev_service_nodeport_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.deploy_dev_backend_config,
  ]
}

module "deploy_dev_deployment" {
  count                       = local.gke_cluster_exists && var.configure_development_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.dev_deployment_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.dev_deployment_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.deploy_dev_service_account,
    module.app_dev_secret,
  ]
}

#########################################################################
# Deploy to QA environment
#########################################################################

module "deploy_qa_frontend_config" {
  count                       = local.gke_cluster_exists && var.configure_nonproduction_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.qa_frontend_config_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.qa_frontend_config_yaml_output[0].filename} --force || true
' || true
EOF
  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.app_qa_namespace,
  ]
}

module "deploy_qa_backend_config" {
  count                       = local.gke_cluster_exists && var.configure_nonproduction_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.qa_backend_config_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.qa_backend_config_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.app_qa_namespace,
  ]
}

module "deploy_qa_horizontal_pod_autoscaler" {
  count                       = local.gke_cluster_exists && var.configure_nonproduction_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.qa_horizontal_pod_autoscaler_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.qa_horizontal_pod_autoscaler_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.deploy_qa_deployment,
  ]
}

module "deploy_qa_ingress" {
  count                       = local.gke_cluster_exists && var.configure_nonproduction_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.qa_ingress_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.qa_ingress_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.deploy_qa_frontend_config,
    module.deploy_qa_service_nodeport,
    module.deploy_qa_managed_certificate,
    module.deploy_qa_service_nodeport,
    # google_compute_global_address.qa,
  ]
}

module "deploy_qa_managed_certificate" {
  count                       = local.gke_cluster_exists && var.configure_nonproduction_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.qa_managed_certificate_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.qa_managed_certificate_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.app_qa_namespace,
  ]
}

module "deploy_qa_service_account" {
  count                       = local.gke_cluster_exists ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.qa_service_account_yaml_output.filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.qa_service_account_yaml_output.filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.app_qa_namespace,
  ]
}

module "deploy_qa_service_nodeport" {
  count                       = local.gke_cluster_exists && var.configure_nonproduction_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.qa_service_nodeport_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.qa_service_nodeport_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.deploy_qa_backend_config,
  ]
}

module "deploy_qa_deployment" {
  count                       = local.gke_cluster_exists && var.configure_nonproduction_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.qa_deployment_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.qa_deployment_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.deploy_qa_service_account,
    module.app_qa_secret,
  ]
}

#########################################################################
# Deploy to Prod environment
#########################################################################

module "deploy_prod_frontend_config" {
  count                       = local.gke_cluster_exists && var.configure_production_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.prod_frontend_config_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.prod_frontend_config_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.app_prod_namespace,
  ]
}

module "deploy_prod_backend_config" {
  count                       = local.gke_cluster_exists && var.configure_production_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.prod_backend_config_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.prod_backend_config_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.app_prod_namespace,
  ]
}

module "deploy_prod_horizontal_pod_autoscaler" {
  count                       = local.gke_cluster_exists && var.configure_production_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.prod_horizontal_pod_autoscaler_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.prod_horizontal_pod_autoscaler_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.deploy_prod_deployment,
  ]
}

module "deploy_prod_ingress" {
  count                       = local.gke_cluster_exists && var.configure_production_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.prod_ingress_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.prod_ingress_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.deploy_prod_frontend_config,
    module.deploy_prod_service_nodeport,
    module.deploy_prod_managed_certificate,
    module.deploy_prod_service_nodeport,
    # google_compute_global_address.prod,
  ]
}

module "deploy_prod_managed_certificate" {
  count                       = local.gke_cluster_exists && var.configure_production_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.prod_managed_certificate_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.prod_managed_certificate_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.app_prod_namespace,
  ]
}

module "deploy_prod_service_account" {
  count                       = local.gke_cluster_exists ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.prod_service_account_yaml_output.filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.prod_service_account_yaml_output.filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.app_prod_namespace,
  ]
}

module "deploy_prod_service_nodeport" {
  count                       = local.gke_cluster_exists && var.configure_production_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.prod_service_nodeport_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.prod_service_nodeport_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.deploy_prod_backend_config,
  ]
}

module "deploy_prod_deployment" {
  count                       = local.gke_cluster_exists && var.configure_production_environment ? 1 : 0
  source                      = "terraform-google-modules/gcloud/google//modules/kubectl-wrapper"
  project_id                  = local.project.project_id
  cluster_name                = local.gke_cluster_name
  cluster_location            = local.region
  kubectl_create_command      = <<EOF
timeout 300 bash -c '
gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}
kubectl apply -f ${local_file.prod_deployment_yaml_output[0].filename} || true
' || true
EOF
  kubectl_destroy_command     = <<EOF
timeout 300 bash -c '
kubectl delete -f ${local_file.prod_deployment_yaml_output[0].filename} --force || true
' || true
EOF

  impersonate_service_account = local.project_sa_email
  skip_download               = true 
  upgrade                     = false 
  use_existing_context        = false 

  module_depends_on = [
    module.deploy_prod_service_account,
    module.app_prod_secret,
  ]
}