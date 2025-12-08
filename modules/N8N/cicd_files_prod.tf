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
# Customize files to add to prod branch on repo
#########################################################################

resource "local_file" "primary_prod_base_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/base/primary/kustomization.yaml"
  content  = file("${path.module}/scripts/ci/base/kustomization.yaml.tpl")
  depends_on = [github_repository.project_private_repo]
}

resource "local_file" "secondary_prod_base_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment && length(local.regions) >= 2 ? 1 : 0
  filename = "${path.module}/scripts/ci/base/secondary/kustomization.yaml"
  content  = file("${path.module}/scripts/ci/base/kustomization.yaml.tpl")
  depends_on = [github_repository.project_private_repo]
}

resource "local_file" "primary_prod_overlay_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/overlay/primary/kustomization.yaml"
  content  = templatefile("${path.module}/scripts/ci/overlay/kustomization.yaml.tpl", {
    PROJECT_ID  = local.project.project_id
    APP_NAME    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    REPO_REGION = local.region
    HA_REGION   = "primary"
    APP_ENV     = "prod"
    IMAGE_NAME  = var.application_name
    REPO_NAME   = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })
  depends_on = [github_repository.project_private_repo]
}

resource "local_file" "secondary_prod_overlay_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment && length(local.regions) >= 2 ? 1 : 0
  filename = "${path.module}/scripts/ci/overlay/secondary/kustomization.yaml"
  content  = templatefile("${path.module}/scripts/ci/overlay/kustomization.yaml.tpl", {
    PROJECT_ID  = local.project.project_id
    APP_NAME    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    REPO_REGION = local.region
    HA_REGION   = "secondary"
    APP_ENV     = "prod"
    IMAGE_NAME  = var.application_name
    REPO_NAME   = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })
  depends_on = [github_repository.project_private_repo]
}

resource "local_file" "primary_prod_base_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/base/primary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/base/deploy.yaml.tpl", {
    PROJECT_ID        = local.project.project_id
    APP_REGION        = local.region
    HA_REGION         = "${local.regions[0]}"
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    DATABASE_INSTANCE = local.db_instance_name
    NETWORK_NAME      = "${var.network_name}"
    HOST_PROJECT_ID   = "${local.project.project_id}"
  })
  depends_on = [github_repository.project_private_repo]
}

resource "local_file" "secondary_prod_base_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment && length(local.regions) >= 2 ? 1 : 0
  filename = "${path.module}/scripts/ci/base/secondary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/base/deploy.yaml.tpl", {
    PROJECT_ID        = local.project.project_id
    APP_REGION        = local.region
    HA_REGION         = "${local.regions[1]}"
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    DATABASE_INSTANCE = local.db_instance_name
    NETWORK_NAME      = "${var.network_name}"
    HOST_PROJECT_ID   = "${local.project.project_id}"
  })
  depends_on = [github_repository.project_private_repo]
}

resource "local_file" "primary_prod_overlay_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/overlay/primary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/overlay/deploy.yaml.tpl", {
    PROJECT_ID        = local.project.project_id
    PROJECT_NUMBER    = local.project_number
    APP_REGION        = local.region
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_ENV           = "prod"
    APP_NFS_IP        = local.nfs_internal_ip
    APP_URL           = "https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod-${local.project_number}.${local.region}.run.app"
    DATABASE_USER     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
    DATABASE_NAME     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
    DATABASE_PASSWORD = "${local.db_instance_name}-${var.application_database_name}prod-password-${var.tenant_deployment_id}-${local.random_id}"
    DATABASE_HOST     = local.db_internal_ip
    DATABASE_INSTANCE = local.db_instance_name
    IMAGE_NAME        = var.application_name
    IMAGE_VERSION     = "latest-prod"
    REPO_NAME         = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    REPO_REGION       = local.region
    BACKUP_BUCKET     = "${local.project.project_id}-backups"
    DATA_BUCKET       = "${local.project.project_id}-data"
    NETWORK_NAME      = "${var.network_name}"
    HOST_PROJECT_ID   = "${local.project.project_id}"
    SHARED_DIRECTORY  = "/share/app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
  })
  depends_on = [github_repository.project_private_repo]
}

resource "local_file" "secondary_prod_overlay_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment && length(local.regions) >= 2 ? 1 : 0
  filename = "${path.module}/scripts/ci/overlay/secondary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/overlay/deploy.yaml.tpl", {
    PROJECT_ID        = local.project.project_id
    PROJECT_NUMBER    = local.project_number
    APP_REGION        = local.region
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_ENV           = "prod"
    APP_NFS_IP        = local.nfs_internal_ip
    APP_URL           = "https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod-${local.project_number}.${local.region}.run.app"
    DATABASE_USER     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
    DATABASE_NAME     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
    DATABASE_PASSWORD = "${local.db_instance_name}-${var.application_database_name}prod-password-${var.tenant_deployment_id}-${local.random_id}"
    DATABASE_HOST     = local.db_internal_ip
    DATABASE_INSTANCE = local.db_instance_name
    IMAGE_NAME        = var.application_name
    IMAGE_VERSION     = "latest-prod"
    REPO_NAME         = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    REPO_REGION       = local.region
    BACKUP_BUCKET     = "${local.project.project_id}-backups"
    DATA_BUCKET       = "${local.project.project_id}-data"
    NETWORK_NAME      = "${var.network_name}"
    HOST_PROJECT_ID   = "${local.project.project_id}"
    SHARED_DIRECTORY  = "/share/app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
  })
  depends_on = [github_repository.project_private_repo]
}

resource "local_file" "prod_foreground" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/foreground.sh"
  content  = file("${path.module}/scripts/ci/foreground.sh.tpl")
  depends_on = [github_repository.project_private_repo]
}

resource "local_file" "prod_cloudrun_entrypoint" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/cloudrun-entrypoint.sh"
  content  = file("${path.module}/scripts/ci/cloudrun-entrypoint.sh.tpl")
  depends_on = [github_repository.project_private_repo]
}

resource "local_file" "prod_dockerfile" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  filename        = "${path.module}/scripts/ci/Dockerfile"
  content         = templatefile("${path.module}/scripts/ci/dockerfile.tpl", {
    APP_VERSION  = "${var.application_version}"
  })
  depends_on = [github_repository.project_private_repo]
}

resource "local_file" "prod_cloudbuild" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/cloudbuild.yaml"
  content  = templatefile(
    length(local.regions) >= 2 ? "${path.module}/scripts/ci/cloudbuild_ha.yaml.tpl" : "${path.module}/scripts/ci/cloudbuild.yaml.tpl",
    {
      PROJECT_ID          = local.project.project_id
      APP_REGION          = local.region
      APP_NAME            = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
      APP_ENV             = "prod"
      PRIMARY_HA_REGION   = local.regions[0]
      SECONDARY_HA_REGION = length(local.regions) >= 2 ? local.regions[1] : ""
      IMAGE_NAME          = var.application_name
      REPO_NAME           = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    }
  )
  depends_on = [github_repository.project_private_repo]
}

resource "local_file" "prod_skaffold" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/skaffold.yaml"
    content                   = templatefile("${path.module}/scripts/ci/skaffold.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    APP_NAME                  = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_ENV                   = "prod"
    APP_REGION                = local.region
    IMAGE_NAME                = var.application_name
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })
  depends_on = [github_repository.project_private_repo]
}

resource "github_repository_file" "primary_prod_base_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add base kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "base/primary/kustomization.yaml"
  content             = local_file.primary_prod_base_kustomization[count.index].content
  depends_on = [local_file.primary_prod_base_kustomization, github_branch.branches]
}

resource "github_repository_file" "secondary_prod_base_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment && length(local.regions) >= 2 ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add base kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "base/secondary/kustomization.yaml"
  content             = local_file.secondary_prod_base_kustomization[count.index].content
  depends_on = [local_file.secondary_prod_base_kustomization, github_branch.branches]
}

resource "github_repository_file" "primary_prod_overlay_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add overlay kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/primary/kustomization.yaml"
  content             = local_file.primary_prod_overlay_kustomization[count.index].content
  depends_on = [local_file.primary_prod_overlay_kustomization, github_branch.branches]
}

resource "github_repository_file" "secondary_prod_overlay_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment && length(local.regions) >= 2 ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add overlay kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/secondary/kustomization.yaml"
  content             = local_file.secondary_prod_overlay_kustomization[count.index].content
  depends_on = [local_file.secondary_prod_overlay_kustomization, github_branch.branches]
}

resource "github_repository_file" "primary_prod_base_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add base deploy.yaml to repo"
  overwrite_on_create = true
  file                = "base/primary/deploy.yaml"
  content             = local_file.primary_prod_base_deploy[count.index].content
  depends_on = [local_file.primary_prod_base_deploy, github_branch.branches]
}

resource "github_repository_file" "secondary_prod_base_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment && length(local.regions) >= 2 ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add base deploy.yaml to repo"
  overwrite_on_create = true
  file                = "base/secondary/deploy.yaml"
  content             = local_file.secondary_prod_base_deploy[count.index].content
  depends_on = [local_file.secondary_prod_base_deploy, github_branch.branches]
}

resource "github_repository_file" "primary_prod_overlay_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add overlay deploy.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/primary/deploy.yaml"
  content             = local_file.primary_prod_overlay_deploy[count.index].content
  depends_on = [local_file.primary_prod_overlay_deploy, github_branch.branches]
}

resource "github_repository_file" "secondary_prod_overlay_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment && length(local.regions) >= 2 ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add overlay deploy.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/secondary/deploy.yaml"
  content             = local_file.secondary_prod_overlay_deploy[count.index].content
  depends_on = [local_file.secondary_prod_overlay_deploy, github_branch.branches]
}

resource "github_repository_file" "prod_foreground" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "foreground.sh"
  content             = local_file.prod_foreground[count.index].content
  depends_on = [local_file.prod_foreground, github_branch.branches]
}

resource "github_repository_file" "prod_cloudrun_entrypoint" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add cloudrun-entrypoint.sh to repo"
  overwrite_on_create = true
  file                = "cloudrun-entrypoint.sh"
  content             = local_file.prod_cloudrun_entrypoint[count.index].content
  depends_on = [local_file.prod_cloudrun_entrypoint, github_branch.branches]
}

resource "github_repository_file" "prod_dockerfile" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "Dockerfile"
  content             = local_file.prod_dockerfile[count.index].content
  depends_on = [local_file.prod_dockerfile, github_branch.branches]
}

resource "github_repository_file" "prod_cloudbuild" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "cloudbuild.yaml"
  content             = local_file.prod_cloudbuild[count.index].content
  depends_on      = [local_file.prod_cloudbuild, github_branch.branches]
}

resource "github_repository_file" "prod_skaffold" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "skaffold.yaml"
  content             = local_file.prod_skaffold[count.index].content
  depends_on = [local_file.prod_skaffold, github_branch.branches]
}
