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

#########################################################################
# Customize dev files to repo
#########################################################################

# Resource for creating a local autoscale horizontal configuration file from a template
resource "local_file" "dev_autoscale_horizontal" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/base/dev/autoscale-horizontal.yaml"
    content                   = templatefile("${path.module}/scripts/ci/base/autoscale-horizontal.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local backend configuration file from a template
resource "local_file" "dev_backend_config" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/base/dev/backend-config.yaml"
    content                   = templatefile("${path.module}/scripts/ci/base/backend-config.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local frontend configuration file from a template
resource "local_file" "dev_frontend_config" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/base/dev/frontend-config.yaml"
    content                   = templatefile("${path.module}/scripts/ci/base/frontend-config.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local base kustomization file directly from an existing file
resource "local_file" "dev_base_kustomization" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/base/dev/kustomization.yaml"
    content                   = file("${path.module}/scripts/ci/base/kustomization.yaml.tpl"
  )

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local service cluster configuration file from a template
resource "local_file" "dev_service_cluster" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/base/dev/service-cluster.yaml"
    content                   = templatefile("${path.module}/scripts/ci/base/service-cluster.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_ENV                   = "dev"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local ingress application configuration file from a template
resource "local_file" "dev_ingress_app" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/overlay/dev/ingress-app.yaml"
    content                   = templatefile("${path.module}/scripts/ci/overlay/ingress-app.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_ENV                   = "dev"
    APP_DOMAIN                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev.${google_compute_global_address.dev[count.index].address}.sslip.io"
    APP_IP                    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  })

  depends_on      = [
    google_compute_global_address.dev,
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local overlay kustomization file from a template.
# This will configure kustomization for a specific environment or 'overlay' like staging or production.
resource "local_file" "dev_overlay_kustomization" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/overlay/dev/kustomization.yaml"
    content                   = templatefile("${path.module}/scripts/ci/overlay/kustomization.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_NAMESPACE             = "${var.application_name}${var.tenant_deployment_id}"
    APP_REGION                = local.region
    IMAGE_NAME                = var.application_name
    IMAGE_VERSION             = "latest-dev"
    APP_ENV                   = "dev"
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local managed certificate for the app from a template.
# It sets up the necessary information to create a managed certificate for an application's domain.
resource "local_file" "dev_managedcert_app" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/overlay/dev/managedcert-app.yaml"
    content                   = templatefile("${path.module}/scripts/ci/overlay/managedcert-app.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_DOMAIN                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev.${google_compute_global_address.dev[count.index].address}.sslip.io"
  })

  depends_on      = [
    google_compute_global_address.dev,
    null_resource.init_git_repo,
  ]
}

# Resource for creating a deployment configuration for the stateful app from a template.
# This includes all necessary information for the deployment of the application to Kubernetes.
resource "local_file" "dev_deployment_app" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/overlay/dev/deployment-app.yaml"
    content                   = templatefile("${path.module}/scripts/ci/overlay/deployment-app.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    GCP_SERVICE_ACCOUNT       = "gcp-project-account@gcp-sa-cloudbuild.iam.gserviceaccount.com"
    APP_REGION                = local.region
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_NAMESPACE             = "${var.application_name}${var.tenant_deployment_id}"
    APP_ENV                   = "dev"
    DATABASE_USER             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
    DATABASE_NAME             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
    DATABASE_SECRET           = "app${var.application_database_name}${local.random_id}dev-password"
    DATABASE_HOST             = local.sql_server_exists ? local.db_internal_ip : !local.sql_server_exists ? local.db_internal_ip : null
    IMAGE_NAME                = var.application_name
    IMAGE_VERSION             = "latest-dev"
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  depends_on      = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local cloudbuild file from a template, with variables substituted
resource "local_file" "dev_cloudbuild" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment && length(local.regions) > 0 ? 1 : 0
  filename = "${path.module}/scripts/ci/cloudbuild.yaml"

  content  = templatefile(
    length(local.regions) >= 2 ? "${path.module}/scripts/ci/cloudbuild.yaml.tpl" : "${path.module}/scripts/ci/cloudbuild.yaml.tpl",
    {
      PROJECT_ID          = local.project.project_id
      APP_NAME            = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
      APP_ENV             = "dev"
      APP_REGION          = local.region
      GKE_CLUSTER         = local.gke_cluster_name
      IMAGE_NAME          = var.application_name
      REPO_NAME           = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
      # UNIQUE_ID       = random_id.note_id.hex
      # APP_ATTESTOR    = "attestor-${var.tenant_deployment_id}-${local.random_id}"
    }
  )

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a Dockerfile from a template, which will be used to build the application's container image.
resource "local_file" "dev_dockerfile" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/dev/Dockerfile"
    content                   = templatefile("${path.module}/scripts/ci/Dockerfile.tpl", {
      APP_VERSION             = "${var.application_version}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local Skaffold configuration file from a template.
# Skaffold is a tool that facilitates continuous development for Kubernetes applications.
resource "local_file" "dev_skaffold" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/dev/skaffold.yaml"
    content                   = templatefile("${path.module}/scripts/ci/skaffold.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    APP_NAME                  = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_REGION                = local.region
    APP_ENV                   = "dev"
    GKE_CLUSTER               = local.gke_cluster_name
    IMAGE_NAME                = var.application_name
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

#########################################################################
# Customize qa files to repo
#########################################################################

# Resource for creating a local autoscale horizontal configuration file from a template
resource "local_file" "qa_autoscale_horizontal" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/base/qa/autoscale-horizontal.yaml"
    content                   = templatefile("${path.module}/scripts/ci/base/autoscale-horizontal.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local backend configuration file from a template
resource "local_file" "qa_backend_config" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/base/qa/backend-config.yaml"
    content                   = templatefile("${path.module}/scripts/ci/base/backend-config.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local frontend configuration file from a template
resource "local_file" "qa_frontend_config" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/base/qa/frontend-config.yaml"
    content                   = templatefile("${path.module}/scripts/ci/base/frontend-config.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local base kustomization file directly from an existing file
resource "local_file" "qa_base_kustomization" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/base/qa/kustomization.yaml"
    content                   = file("${path.module}/scripts/ci/base/kustomization.yaml.tpl"
  )

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local service cluster configuration file from a template
resource "local_file" "qa_service_cluster" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/base/qa/service-cluster.yaml"
    content                   = templatefile("${path.module}/scripts/ci/base/service-cluster.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_ENV                   = "qa"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local ingress application configuration file from a template
resource "local_file" "qa_ingress_app" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/overlay/qa/ingress-app.yaml"
    content                   = templatefile("${path.module}/scripts/ci/overlay/ingress-app.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_ENV                   = "qa"
    APP_DOMAIN                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa.${google_compute_global_address.qa[count.index].address}.sslip.io"
    APP_IP                    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  })

  depends_on      = [
    google_compute_global_address.qa,
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local overlay kustomization file from a template.
# This will configure kustomization for a specific environment or 'overlay' like staging or production.
resource "local_file" "qa_overlay_kustomization" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/overlay/qa/kustomization.yaml"
    content                   = templatefile("${path.module}/scripts/ci/overlay/kustomization.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_NAMESPACE             = "${var.application_name}${var.tenant_deployment_id}"
    APP_REGION                = local.region
    IMAGE_NAME                = var.application_name
    IMAGE_VERSION             = "latest-qa"
    APP_ENV                   = "qa"
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local managed certificate for the app from a template.
# It sets up the necessary information to create a managed certificate for an application's domain.
resource "local_file" "qa_managedcert_app" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/overlay/qa/managedcert-app.yaml"
    content                   = templatefile("${path.module}/scripts/ci/overlay/managedcert-app.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_DOMAIN                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa.${google_compute_global_address.qa[count.index].address}.sslip.io"
  })

  depends_on      = [
    google_compute_global_address.qa,
    null_resource.init_git_repo,
  ]
}

# Resource for creating a deployment configuration for the stateful app from a template.
# This includes all necessary information for the deployment of the application to Kubernetes.
resource "local_file" "qa_deployment_app" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/overlay/qa/deployment-app.yaml"
    content                   = templatefile("${path.module}/scripts/ci/overlay/deployment-app.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    GCP_SERVICE_ACCOUNT       = "gcp-project-account@gcp-sa-cloudbuild.iam.gserviceaccount.com"
    APP_REGION                = local.region
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_NAMESPACE             = "${var.application_name}${var.tenant_deployment_id}"
    APP_ENV                   = "qa"
    DATABASE_USER             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
    DATABASE_NAME             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
    DATABASE_SECRET           = "app${var.application_database_name}${local.random_id}qa-password"
    DATABASE_HOST             = local.sql_server_exists ? local.db_internal_ip : !local.sql_server_exists ? local.db_internal_ip : null
    IMAGE_NAME                = var.application_name
    IMAGE_VERSION             = "latest-qa"
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  depends_on      = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local Cloud Build configuration file from a template.
resource "local_file" "qa_cloudbuild" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/qa/cloudbuild.yaml"
    content                   = templatefile("${path.module}/scripts/ci/cloudbuild.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    GKE_CLUSTER               = local.gke_cluster_name
    APP_REGION                = local.region
    APP_ENV                   = "qa"
    IMAGE_NAME                = var.application_name
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a Dockerfile from a template, which will be used to build the application's container image.
resource "local_file" "qa_dockerfile" {
  count    = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/qa/Dockerfile"
  content  = file("${path.module}/scripts/ci/Dockerfile.tpl")

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local Skaffold configuration file from a template.
# Skaffold is a tool that facilitates continuous development for Kubernetes applications.
resource "local_file" "qa_skaffold" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/qa/skaffold.yaml"
    content                   = templatefile("${path.module}/scripts/ci/skaffold.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_REGION                = local.region
    APP_ENV                   = "qa"
    GKE_CLUSTER               = local.gke_cluster_name
    IMAGE_NAME                = var.application_name
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

#########################################################################
# Customize prod files to repo
#########################################################################

# Resource for creating a local autoscale horizontal configuration file from a template
resource "local_file" "prod_autoscale_horizontal" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/base/prod/autoscale-horizontal.yaml"
    content                   = templatefile("${path.module}/scripts/ci/base/autoscale-horizontal.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local backend configuration file from a template
resource "local_file" "prod_backend_config" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/base/prod/backend-config.yaml"
    content                   = templatefile("${path.module}/scripts/ci/base/backend-config.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local frontend configuration file from a template
resource "local_file" "prod_frontend_config" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/base/prod/frontend-config.yaml"
    content                   = templatefile("${path.module}/scripts/ci/base/frontend-config.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local base kustomization file directly from an existing file
resource "local_file" "prod_base_kustomization" {
  count    = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/base/prod/kustomization.yaml"
  content  = file("${path.module}/scripts/ci/base/kustomization.yaml.tpl")

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local service cluster configuration file from a template
resource "local_file" "prod_service_cluster" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/base/prod/service-cluster.yaml"
    content                   = templatefile("${path.module}/scripts/ci/base/service-cluster.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_ENV                   = "prod"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local ingress application configuration file from a template
resource "local_file" "prod_ingress_app" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/overlay/prod/ingress-app.yaml"
    content                   = templatefile("${path.module}/scripts/ci/overlay/ingress-app.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_ENV                   = "prod"
    APP_DOMAIN                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod.${google_compute_global_address.prod[count.index].address}.sslip.io"
    APP_IP                    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  })

  depends_on      = [
    google_compute_global_address.prod,
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local overlay kustomization file from a template.
# This will configure kustomization for a specific environment or 'overlay' like staging or production.
resource "local_file" "prod_overlay_kustomization" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/overlay/prod/kustomization.yaml"
    content                   = templatefile("${path.module}/scripts/ci/overlay/kustomization.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_NAMESPACE             = "${var.application_name}${var.tenant_deployment_id}"
    APP_REGION                = local.region
    IMAGE_NAME                = var.application_name
    IMAGE_VERSION             = "latest-prod"
    APP_ENV                   = "prod"
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local managed certificate for the app from a template.
# It sets up the necessary information to create a managed certificate for an application's domain.
resource "local_file" "prod_managedcert_app" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/overlay/prod/managedcert-app.yaml"
    content                   = templatefile("${path.module}/scripts/ci/overlay/managedcert-app.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_DOMAIN                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod.${google_compute_global_address.prod[count.index].address}.sslip.io"
  })

  depends_on      = [
    google_compute_global_address.prod,
    null_resource.init_git_repo,
  ]
}

# Resource for creating a deployment configuration for the stateful app from a template.
# This includes all necessary information for the deployment of the application to Kubernetes.
resource "local_file" "prod_deployment_app" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/overlay/prod/deployment-app.yaml"
    content                   = templatefile("${path.module}/scripts/ci/overlay/deployment-app.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    GCP_SERVICE_ACCOUNT       = "gcp-project-account@gcp-sa-cloudbuild.iam.gserviceaccount.com"
    APP_REGION                = local.region
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_NAMESPACE             = "${var.application_name}${var.tenant_deployment_id}"
    APP_ENV                   = "prod"
    DATABASE_USER             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
    DATABASE_NAME             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
    DATABASE_SECRET           = "app${var.application_database_name}${local.random_id}prod-password"
    DATABASE_HOST             = local.sql_server_exists ? local.db_internal_ip : !local.sql_server_exists ? local.db_internal_ip : null
    IMAGE_NAME                = var.application_name
    IMAGE_VERSION             = "latest-prod"
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  depends_on      = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local Cloud Build configuration file from a template.
resource "local_file" "prod_cloudbuild" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/prod/cloudbuild.yaml"
    content                   = templatefile("${path.module}/scripts/ci/cloudbuild.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    GKE_CLUSTER               = local.gke_cluster_name
    APP_REGION                = local.region
    APP_ENV                   = "prod"
    IMAGE_NAME                = var.application_name
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a Dockerfile from a template, which will be used to build the application's container image.
resource "local_file" "prod_dockerfile" {
  count    = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/prod/Dockerfile"
  content  = file("${path.module}/scripts/ci/Dockerfile.tpl")

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local Skaffold configuration file from a template.
# Skaffold is a tool that facilitates continuous development for Kubernetes applications.
resource "local_file" "prod_skaffold" {
    count                     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/prod/skaffold.yaml"
    content                   = templatefile("${path.module}/scripts/ci/skaffold.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_REGION                = local.region
    APP_ENV                   = "prod"
    GKE_CLUSTER               = local.gke_cluster_name
    IMAGE_NAME                = var.application_name
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

#########################################################################
# Add dev files to repo
#########################################################################

# Resource to create or update an autoscale horizontal configuration file in a GitHub repository
resource "github_repository_file" "dev_autoscale_horizontal" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"  
  branch              = "dev"                   
  commit_message      = "Add file to repo"       
  overwrite_on_create = true                     
  file                = "base/autoscale-horizontal.yaml"  
  content             = local_file.dev_autoscale_horizontal[count.index].content 

  depends_on = [
    local_file.dev_autoscale_horizontal,
    null_resource.init_git_repo
  ]
}

# Resource for backend configuration file in a GitHub repository
resource "github_repository_file" "dev_backend_config" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"  
  branch              = "dev"                    
  commit_message      = "Add file to repo"       
  overwrite_on_create = true                     
  file                = "base/backend-config.yaml" 
  content             = local_file.dev_backend_config[count.index].content 

  depends_on = [
    local_file.dev_backend_config,
    null_resource.init_git_repo
  ]
}

# Resource for frontend configuration file in a GitHub repository
resource "github_repository_file" "dev_frontend_config" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "base/frontend-config.yaml"
  content             = local_file.dev_frontend_config[count.index].content

  depends_on = [
    local_file.dev_frontend_config,
    null_resource.init_git_repo
  ]
}

# Resource for base kustomization file in a GitHub repository
resource "github_repository_file" "dev_base_kustomization" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "base/kustomization.yaml"
  content             = local_file.dev_base_kustomization[count.index].content

  depends_on = [
    local_file.dev_base_kustomization,
    null_resource.init_git_repo
  ]
}

# Resource for service cluster configuration file in a GitHub repository
resource "github_repository_file" "dev_service_cluster" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "base/service-cluster.yaml"
  content             = local_file.dev_service_cluster[count.index].content

  depends_on = [
    local_file.dev_service_cluster,
    null_resource.init_git_repo
  ]
}

# Resource for ingress configuration file in a GitHub repository
resource "github_repository_file" "dev_ingress_app" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "overlay/ingress-app.yaml"
  content             = local_file.dev_ingress_app[count.index].content

  depends_on      = [
    local_file.dev_ingress_app,
    null_resource.init_git_repo
  ]
}

# Resource for overlay kustomize configuration file in a GitHub repository
resource "github_repository_file" "dev_overlay_kustomization" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "overlay/kustomization.yaml"
  content             = local_file.dev_overlay_kustomization[count.index].content

  depends_on      = [
    local_file.dev_overlay_kustomization,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the managed certificate app configuration
resource "github_repository_file" "dev_managedcert_app" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}" 
  branch              = "dev"                  
  commit_message      = "Add file to repo"      
  overwrite_on_create = true                    
  file                = "overlay/managedcert-app.yaml" 
  content             = local_file.dev_managedcert_app[count.index].content 

  depends_on = [
    local_file.dev_managedcert_app,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the deployment app configuration
resource "github_repository_file" "dev_deployment_app" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "overlay/deployment-app.yaml"
  content             = local_file.dev_deployment_app[count.index].content

  depends_on      = [
    local_file.dev_deployment_app,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the Cloud Build configuration
resource "github_repository_file" "dev_cloudbuild" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "cloudbuild.yaml"
  content             = local_file.dev_cloudbuild[count.index].content

  depends_on      = [
    local_file.dev_cloudbuild,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the Dockerfile
resource "github_repository_file" "dev_dockerfile" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "Dockerfile"
  content             = local_file.dev_dockerfile[count.index].content

  depends_on      = [
    local_file.dev_dockerfile,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the Skaffold configuration
resource "github_repository_file" "dev_skaffold" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "skaffold.yaml"
  content             = local_file.dev_skaffold[count.index].content

  depends_on      = [
    local_file.dev_skaffold,
    null_resource.init_git_repo
  ]
}

#########################################################################
# Add qa files to repo
#########################################################################

# Resource to create or update an autoscale horizontal configuration file in a GitHub repository
resource "github_repository_file" "qa_autoscale_horizontal" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"  
  branch              = "qa"                   
  commit_message      = "Add file to repo"       
  overwrite_on_create = true                     
  file                = "base/autoscale-horizontal.yaml"  
  content             = local_file.qa_autoscale_horizontal[count.index].content 

  depends_on = [
    local_file.qa_autoscale_horizontal,
    null_resource.init_git_repo
  ]
}

# Resource for backend configuration file in a GitHub repository
resource "github_repository_file" "qa_backend_config" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"  
  branch              = "qa"                    
  commit_message      = "Add file to repo"       
  overwrite_on_create = true                     
  file                = "base/backend-config.yaml" 
  content             = local_file.qa_backend_config[count.index].content 

  depends_on = [
    local_file.qa_backend_config,
    null_resource.init_git_repo
  ]
}

# Resource for frontend configuration file in a GitHub repository
resource "github_repository_file" "qa_frontend_config" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "qa"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "base/frontend-config.yaml"
  content             = local_file.qa_frontend_config[count.index].content

  depends_on = [
    local_file.qa_frontend_config,
    null_resource.init_git_repo
  ]
}

# Resource for base kustomization file in a GitHub repository
resource "github_repository_file" "qa_base_kustomization" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "qa"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "base/kustomization.yaml"
  content             = local_file.qa_base_kustomization[count.index].content

  depends_on = [
    local_file.qa_base_kustomization,
    null_resource.init_git_repo
  ]
}

# Resource for service cluster configuration file in a GitHub repository
resource "github_repository_file" "qa_service_cluster" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "qa"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "base/service-cluster.yaml"
  content             = local_file.qa_service_cluster[count.index].content

  depends_on = [
    local_file.qa_service_cluster,
    null_resource.init_git_repo
  ]
}

# Resource for ingress configuration file in a GitHub repository
resource "github_repository_file" "qa_ingress_app" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "qa"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "overlay/ingress-app.yaml"
  content             = local_file.qa_ingress_app[count.index].content

  depends_on      = [
    local_file.qa_ingress_app,
    null_resource.init_git_repo
  ]
}

# Resource for overlay kustomize configuration file in a GitHub repository
resource "github_repository_file" "qa_overlay_kustomization" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "qa"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "overlay/kustomization.yaml"
  content             = local_file.qa_overlay_kustomization[count.index].content

  depends_on      = [
    local_file.qa_overlay_kustomization,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the managed certificate app configuration
resource "github_repository_file" "qa_managedcert_app" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}" 
  branch              = "qa"                  
  commit_message      = "Add file to repo"      
  overwrite_on_create = true                    
  file                = "overlay/managedcert-app.yaml" 
  content             = local_file.qa_managedcert_app[count.index].content 

  depends_on = [
    local_file.qa_managedcert_app,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the deployment app configuration
resource "github_repository_file" "qa_deployment_app" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "qa"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "overlay/deployment-app.yaml"
  content             = local_file.qa_deployment_app[count.index].content

  depends_on      = [
    local_file.qa_deployment_app,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the Cloud Build configuration
resource "github_repository_file" "qa_cloudbuild" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "qa"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "cloudbuild.yaml"
  content             = local_file.qa_cloudbuild[count.index].content

  depends_on      = [
    local_file.qa_cloudbuild,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the Dockerfile
resource "github_repository_file" "qa_dockerfile" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "qa"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "Dockerfile"
  content             = local_file.qa_dockerfile[count.index].content

  depends_on      = [
    local_file.qa_dockerfile,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the Skaffold configuration
resource "github_repository_file" "qa_skaffold" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "qa"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "skaffold.yaml"
  content             = local_file.qa_skaffold[count.index].content

  depends_on      = [
    local_file.qa_skaffold,
    null_resource.init_git_repo
  ]
}

#########################################################################
# Add prod files to repo
#########################################################################

# Resource to create or update an autoscale horizontal configuration file in a GitHub repository
resource "github_repository_file" "prod_autoscale_horizontal" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"  
  branch              = "prod"                   
  commit_message      = "Add file to repo"       
  overwrite_on_create = true                     
  file                = "base/autoscale-horizontal.yaml"  
  content             = local_file.prod_autoscale_horizontal[count.index].content 

  depends_on = [
    local_file.prod_autoscale_horizontal,
    null_resource.init_git_repo
  ]
}

# Resource for backend configuration file in a GitHub repository
resource "github_repository_file" "prod_backend_config" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"  
  branch              = "prod"                    
  commit_message      = "Add file to repo"       
  overwrite_on_create = true                     
  file                = "base/backend-config.yaml" 
  content             = local_file.prod_backend_config[count.index].content 

  depends_on = [
    local_file.prod_backend_config,
    null_resource.init_git_repo
  ]
}

# Resource for frontend configuration file in a GitHub repository
resource "github_repository_file" "prod_frontend_config" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "base/frontend-config.yaml"
  content             = local_file.prod_frontend_config[count.index].content

  depends_on = [
    local_file.prod_frontend_config,
    null_resource.init_git_repo
  ]
}

# Resource for base kustomization file in a GitHub repository
resource "github_repository_file" "prod_base_kustomization" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "base/kustomization.yaml"
  content             = local_file.prod_base_kustomization[count.index].content

  depends_on = [
    local_file.prod_base_kustomization,
    null_resource.init_git_repo
  ]
}

# Resource for service cluster configuration file in a GitHub repository
resource "github_repository_file" "prod_service_cluster" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "base/service-cluster.yaml"
  content             = local_file.prod_service_cluster[count.index].content

  depends_on = [
    local_file.prod_service_cluster,
    null_resource.init_git_repo
  ]
}

# Resource for ingress configuration file in a GitHub repository
resource "github_repository_file" "prod_ingress_app" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "overlay/ingress-app.yaml"
  content             = local_file.prod_ingress_app[count.index].content

  depends_on      = [
    local_file.prod_ingress_app,
    null_resource.init_git_repo
  ]
}

# Resource for overlay kustomize configuration file in a GitHub repository
resource "github_repository_file" "prod_overlay_kustomization" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "overlay/kustomization.yaml"
  content             = local_file.prod_overlay_kustomization[count.index].content

  depends_on      = [
    local_file.prod_overlay_kustomization,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the managed certificate app configuration
resource "github_repository_file" "prod_managedcert_app" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}" 
  branch              = "prod"                  
  commit_message      = "Add file to repo"      
  overwrite_on_create = true                    
  file                = "overlay/managedcert-app.yaml" 
  content             = local_file.prod_managedcert_app[count.index].content 

  depends_on = [
    local_file.prod_managedcert_app,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the deployment app configuration
resource "github_repository_file" "prod_deployment_app" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "overlay/deployment-app.yaml"
  content             = local_file.prod_deployment_app[count.index].content

  depends_on      = [
    local_file.prod_deployment_app,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the Cloud Build configuration
resource "github_repository_file" "prod_cloudbuild" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "cloudbuild.yaml"
  content             = local_file.prod_cloudbuild[count.index].content

  depends_on      = [
    local_file.prod_cloudbuild,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the Dockerfile
resource "github_repository_file" "prod_dockerfile" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "Dockerfile"
  content             = local_file.prod_dockerfile[count.index].content

  depends_on      = [
    local_file.prod_dockerfile,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the Skaffold configuration
resource "github_repository_file" "prod_skaffold" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "skaffold.yaml"
  content             = local_file.prod_skaffold[count.index].content

  depends_on      = [
    local_file.prod_skaffold,
    null_resource.init_git_repo
  ]
}