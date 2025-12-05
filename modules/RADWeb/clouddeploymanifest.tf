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
# Customize files files to repo
#########################################################################

# Resource for creating a local Skaffold configuration file from a template.
# Skaffold is a tool that facilitates continuous development for Kubernetes applications.
resource "local_file" "clouddeploy_app_skaffold" {
  count = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/skaffold.yaml"
    content                   = templatefile("${path.module}/scripts/cd/skaffold.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    APP_NAME                  = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_REGION                = local.region
  })
}

# Resource to create a local file for development deployment, with variables substituted
resource "local_file" "clouddeploy_app_deploy_dev" {
  count = var.configure_continuous_deployment ? 1 : 0
  filename = "${path.module}/scripts/cd/app/deploy-dev.yaml"
  content  = templatefile("${path.module}/scripts/cd/app/deploy-dev.yaml.tpl", {
    # Variables are passed to the template file for dynamic content generation
    PROJECT_ID        = local.project.project_id
    PROJECT_NUMBER    = local.project_number
    APP_REGION        = local.region
    APP_NAME          = var.application_name
    APP_SERVICE       = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
    APP_DATA_DIR      = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev" # 
  })
}

resource "local_file" "clouddeploy_app_deploy_qa" {
  count = var.configure_continuous_deployment ? 1 : 0
  filename = "${path.module}/scripts/cd/app/deploy-qa.yaml"
  content  = templatefile("${path.module}/scripts/cd/app/deploy-qa.yaml.tpl", {
    # Variables are passed to the template file for dynamic content generation
    PROJECT_ID        = local.project.project_id
    PROJECT_NUMBER    = local.project_number
    APP_REGION        = local.region
    APP_NAME          = var.application_name
    APP_SERVICE       = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
    APP_DATA_DIR      = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa" # 
  })
}

resource "local_file" "clouddeploy_app_deploy_prod" {
  count = var.configure_continuous_deployment ? 1 : 0
  filename = "${path.module}/scripts/cd/app/deploy-prod.yaml"
  content  = templatefile("${path.module}/scripts/cd/app/deploy-prod.yaml.tpl", {
    # Variables are passed to the template file for dynamic content generation
    PROJECT_ID        = local.project.project_id
    PROJECT_NUMBER    = local.project_number
    APP_REGION        = local.region
    APP_NAME          = var.application_name
    APP_SERVICE       = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
    APP_DATA_DIR      = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod" # 
  })
}

# Resource to create a local cloudbuild file from a template, with variables substituted
resource "local_file" "clouddeploy_app_cloudbuild" {
  count = var.configure_continuous_deployment ? 1 : 0
  filename = "${path.module}/scripts/cd/app/cloudbuild.yaml"
  content  = templatefile("${path.module}/scripts/cd/app/cloudbuild.yaml.tpl", {
    PROJECT_ID    = local.project.project_id
    APP_NAME      = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_REGION    = local.region
    IMAGE_NAME    = var.application_name
    IMAGE_VERSION = "${var.application_version}"
    REPO_NAME     = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    PIPELINE_NAME = "app${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })
}

# Resource to create a local clouddeploy file from a template, with variables substituted
resource "local_file" "app_clouddeploy" {
  count = var.configure_continuous_deployment ? 1 : 0
  filename = "${path.module}/scripts/cd/app/clouddeploy.yaml"
  content  = templatefile("${path.module}/scripts/cd/clouddeploy.yaml.tpl", {
    PROJECT_ID    = local.project.project_id
    APP_NAME      = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_REGION    = local.region
    CREATOR_SA    = "clouddeploy-sa@${local.project.project_id}.iam.gserviceaccount.com"
    PIPELINE_NAME = "app${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    TARGET_NAME   = "app${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })
}

# Resource for creating a Dockerfile from a template, which will be used to build the application's container image.
resource "local_file" "clouddeploy_dockerfile" {
  count = var.configure_continuous_deployment ? 1 : 0
  filename        = "${path.module}/scripts/app/Dockerfile"
  content         = templatefile("${path.module}/scripts/app/Dockerfile.tpl", {
    APP_VERSION  = "${var.application_version}"
  })
}

# Resource to create a local cloudbuild file from a template, with variables substituted
resource "local_file" "cicd_cloudbuild" {
  count = var.configure_continuous_deployment ? 1 : 0
  filename = "${path.module}/scripts/app/cloudbuild.yaml"
  content  = templatefile("${path.module}/scripts/app/cloudbuild.yaml.tpl", {
    PROJECT_ID    = local.project.project_id
    APP_NAME      = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    IMAGE_REGION  = local.region
    IMAGE_NAME    = var.application_name
    IMAGE_VERSION = "${var.application_version}"
    REPO_NAME     = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })
}