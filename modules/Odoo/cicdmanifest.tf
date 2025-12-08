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

locals {
  cicd_environments = merge(
    var.configure_development_environment ? {
      dev = {
        branch      = "dev"
        image_tag   = "latest-dev"
        db_user     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
        db_name     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
        db_pass_key = "${local.db_instance_name}-${var.application_database_name}dev-password-${var.tenant_deployment_id}-${local.random_id}"
        shared_dir  = "/share/app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
      }
    } : {},
    var.configure_nonproduction_environment ? {
      qa = {
        branch      = "qa"
        image_tag   = "latest-qa"
        db_user     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
        db_name     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
        db_pass_key = "${local.db_instance_name}-${var.application_database_name}qa-password-${var.tenant_deployment_id}-${local.random_id}"
        shared_dir  = "/share/app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
      }
    } : {},
    var.configure_production_environment ? {
      prod = {
        branch      = "prod"
        image_tag   = "latest-prod"
        db_user     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
        db_name     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
        db_pass_key = "${local.db_instance_name}-${var.application_database_name}prod-password-${var.tenant_deployment_id}-${local.random_id}"
        shared_dir  = "/share/app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
      }
    } : {}
  )

  # Check if secondary region is needed
  use_secondary = length(local.regions) >= 2

  # Check if CI/CD is enabled
  # We use nonsensitive() here because `application_git_token` is sensitive,
  # and sensitive values cannot be used in `for_each` keys or values directly if they determine the set of keys.
  # However, here we are using it in a boolean condition for `for_each`.
  # Terraform requires that the decision to include elements in `for_each` is known at plan time.
  # If the sensitive value is not known until apply (which is rare for input variables), it might be an issue.
  # But the main issue reported is "Sensitive values... cannot be used as for_each arguments".
  # We can workaround this by creating a nonsensitive boolean.
  ci_enabled = nonsensitive(var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "")
}

#########################################################################
# Base Kustomization Files
#########################################################################

resource "local_file" "cicd_primary_base_kustomization" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  filename = "${path.module}/scripts/ci/${each.key}/base/primary/kustomization.yaml"
  content  = file("${path.module}/scripts/ci/base/kustomization.yaml.tpl")

  depends_on = [null_resource.init_git_repo]
}

resource "local_file" "cicd_secondary_base_kustomization" {
  for_each = local.ci_enabled && local.use_secondary ? local.cicd_environments : {}

  filename = "${path.module}/scripts/ci/${each.key}/base/secondary/kustomization.yaml"
  content  = file("${path.module}/scripts/ci/base/kustomization.yaml.tpl")

  depends_on = [null_resource.init_git_repo]
}

resource "github_repository_file" "primary_base_kustomization" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = each.value.branch
  commit_message      = "Add base kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "base/primary/kustomization.yaml"
  content             = local_file.cicd_primary_base_kustomization[each.key].content

  depends_on = [local_file.cicd_primary_base_kustomization, null_resource.init_git_repo]
}

resource "github_repository_file" "secondary_base_kustomization" {
  for_each = local.ci_enabled && local.use_secondary ? local.cicd_environments : {}

  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = each.value.branch
  commit_message      = "Add base kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "base/secondary/kustomization.yaml"
  content             = local_file.cicd_secondary_base_kustomization[each.key].content

  depends_on = [local_file.cicd_secondary_base_kustomization, null_resource.init_git_repo]
}

#########################################################################
# Overlay Kustomization Files
#########################################################################

resource "local_file" "cicd_primary_overlay_kustomization" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  filename = "${path.module}/scripts/ci/${each.key}/overlay/primary/kustomization.yaml"
  content  = templatefile("${path.module}/scripts/ci/overlay/kustomization.yaml.tpl", {
    PROJECT_ID  = local.project.project_id
    APP_NAME    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    REPO_REGION = local.region
    HA_REGION   = "primary"
    APP_ENV     = each.key
    IMAGE_NAME  = var.application_name
    REPO_NAME   = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  depends_on = [null_resource.init_git_repo]
}

resource "local_file" "cicd_secondary_overlay_kustomization" {
  for_each = local.ci_enabled && local.use_secondary ? local.cicd_environments : {}

  filename = "${path.module}/scripts/ci/${each.key}/overlay/secondary/kustomization.yaml"
  content  = templatefile("${path.module}/scripts/ci/overlay/kustomization.yaml.tpl", {
    PROJECT_ID  = local.project.project_id
    APP_NAME    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    REPO_REGION = local.region
    HA_REGION   = "secondary"
    APP_ENV     = each.key
    IMAGE_NAME  = var.application_name
    REPO_NAME   = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  depends_on = [null_resource.init_git_repo]
}

resource "github_repository_file" "primary_overlay_kustomization" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = each.value.branch
  commit_message      = "Add overlay kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/primary/kustomization.yaml"
  content             = local_file.cicd_primary_overlay_kustomization[each.key].content

  depends_on = [local_file.cicd_primary_overlay_kustomization, null_resource.init_git_repo]
}

resource "github_repository_file" "secondary_overlay_kustomization" {
  for_each = local.ci_enabled && local.use_secondary ? local.cicd_environments : {}

  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = each.value.branch
  commit_message      = "Add overlay kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/secondary/kustomization.yaml"
  content             = local_file.cicd_secondary_overlay_kustomization[each.key].content

  depends_on = [local_file.cicd_secondary_overlay_kustomization, null_resource.init_git_repo]
}

#########################################################################
# Base Deploy Files
#########################################################################

resource "local_file" "cicd_primary_base_deploy" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  filename = "${path.module}/scripts/ci/${each.key}/base/primary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/base/deploy.yaml.tpl", {
    PROJECT_ID        = local.project.project_id
    APP_REGION        = local.region
    HA_REGION         = local.regions[0]
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    DATABASE_INSTANCE = local.db_instance_name
    NETWORK_NAME      = var.network_name
    HOST_PROJECT_ID   = local.project.project_id
  })

  depends_on = [null_resource.init_git_repo]
}

resource "local_file" "cicd_secondary_base_deploy" {
  for_each = local.ci_enabled && local.use_secondary ? local.cicd_environments : {}

  filename = "${path.module}/scripts/ci/${each.key}/base/secondary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/base/deploy.yaml.tpl", {
    PROJECT_ID        = local.project.project_id
    APP_REGION        = local.region
    HA_REGION         = local.regions[1]
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    DATABASE_INSTANCE = local.db_instance_name
    NETWORK_NAME      = var.network_name
    HOST_PROJECT_ID   = local.project.project_id
  })

  depends_on = [null_resource.init_git_repo]
}

resource "github_repository_file" "primary_base_deploy" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = each.value.branch
  commit_message      = "Add base deploy.yaml to repo"
  overwrite_on_create = true
  file                = "base/primary/deploy.yaml"
  content             = local_file.cicd_primary_base_deploy[each.key].content

  depends_on = [local_file.cicd_primary_base_deploy, null_resource.init_git_repo]
}

resource "github_repository_file" "secondary_base_deploy" {
  for_each = local.ci_enabled && local.use_secondary ? local.cicd_environments : {}

  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = each.value.branch
  commit_message      = "Add base deploy.yaml to repo"
  overwrite_on_create = true
  file                = "base/secondary/deploy.yaml"
  content             = local_file.cicd_secondary_base_deploy[each.key].content

  depends_on = [local_file.cicd_secondary_base_deploy, null_resource.init_git_repo]
}

#########################################################################
# Overlay Deploy Files
#########################################################################

resource "local_file" "cicd_primary_overlay_deploy" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  filename = "${path.module}/scripts/ci/${each.key}/overlay/primary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/overlay/deploy.yaml.tpl", {
    PROJECT_ID        = local.project.project_id
    PROJECT_NUMBER    = local.project_number
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_ENV           = each.key
    APP_NFS_IP        = local.nfs_internal_ip
    DATABASE_USER     = each.value.db_user
    DATABASE_NAME     = each.value.db_name
    DATABASE_PASSWORD = each.value.db_pass_key
    DATABASE_HOST     = local.db_internal_ip
    DATABASE_INSTANCE = local.db_instance_name
    IMAGE_NAME        = var.application_name
    IMAGE_VERSION     = each.value.image_tag
    REPO_NAME         = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    REPO_REGION       = local.region
    BACKUP_BUCKET     = "${local.project.project_id}-backups"
    DATA_BUCKET       = "${local.project.project_id}-data"
    NETWORK_NAME      = var.network_name
    HOST_PROJECT_ID   = local.project.project_id
    SHARED_DIRECTORY  = each.value.shared_dir
  })

  depends_on = [null_resource.init_git_repo]
}

resource "local_file" "cicd_secondary_overlay_deploy" {
  for_each = local.ci_enabled && local.use_secondary ? local.cicd_environments : {}

  filename = "${path.module}/scripts/ci/${each.key}/overlay/secondary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/overlay/deploy.yaml.tpl", {
    PROJECT_ID        = local.project.project_id
    PROJECT_NUMBER    = local.project_number
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_ENV           = each.key
    APP_NFS_IP        = local.nfs_internal_ip
    DATABASE_USER     = each.value.db_user
    DATABASE_NAME     = each.value.db_name
    DATABASE_PASSWORD = each.value.db_pass_key
    DATABASE_HOST     = local.db_internal_ip
    DATABASE_INSTANCE = local.db_instance_name
    IMAGE_NAME        = var.application_name
    IMAGE_VERSION     = each.value.image_tag
    REPO_NAME         = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    REPO_REGION       = local.region
    BACKUP_BUCKET     = "${local.project.project_id}-backups"
    DATA_BUCKET       = "${local.project.project_id}-data"
    NETWORK_NAME      = var.network_name
    HOST_PROJECT_ID   = local.project.project_id
    SHARED_DIRECTORY  = each.value.shared_dir
  })

  depends_on = [null_resource.init_git_repo]
}

resource "github_repository_file" "primary_overlay_deploy" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = each.value.branch
  commit_message      = "Add overlay deploy.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/primary/deploy.yaml"
  content             = local_file.cicd_primary_overlay_deploy[each.key].content

  depends_on = [local_file.cicd_primary_overlay_deploy, null_resource.init_git_repo]
}

resource "github_repository_file" "secondary_overlay_deploy" {
  for_each = local.ci_enabled && local.use_secondary ? local.cicd_environments : {}

  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = each.value.branch
  commit_message      = "Add overlay deploy.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/secondary/deploy.yaml"
  content             = local_file.cicd_secondary_overlay_deploy[each.key].content

  depends_on = [local_file.cicd_secondary_overlay_deploy, null_resource.init_git_repo]
}

#########################################################################
# Cloud Build, Dockerfile, Skaffold, and Scripts
#########################################################################

resource "local_file" "cicd_cloudbuild" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  filename = "${path.module}/scripts/ci/${each.key}/cloudbuild.yaml"
  content  = templatefile(
    local.use_secondary ? "${path.module}/scripts/ci/cloudbuild_ha.yaml.tpl" : "${path.module}/scripts/ci/cloudbuild.yaml.tpl",
    {
      PROJECT_ID          = local.project.project_id
      APP_REGION          = local.region
      APP_NAME            = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
      APP_ENV             = each.key
      PRIMARY_HA_REGION   = local.regions[0]
      SECONDARY_HA_REGION = local.use_secondary ? local.regions[1] : ""
      IMAGE_NAME          = var.application_name
      REPO_NAME           = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    }
  )

  depends_on = [null_resource.init_git_repo]
}

resource "github_repository_file" "cloudbuild" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = each.value.branch
  commit_message      = "Add cloudbuild.yaml to repo"
  overwrite_on_create = true
  file                = "cloudbuild.yaml"
  content             = local_file.cicd_cloudbuild[each.key].content

  depends_on = [local_file.cicd_cloudbuild, null_resource.init_git_repo]
}

resource "local_file" "cicd_cloudrun_entrypoint" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  filename = "${path.module}/scripts/ci/${each.key}/cloudrun-entrypoint.sh"
  content  = file("${path.module}/scripts/ci/cloudrun-entrypoint.sh.tpl")

  depends_on = [null_resource.init_git_repo]
}

resource "github_repository_file" "cloudrun_entrypoint" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = each.value.branch
  commit_message      = "Add cloudrun-entrypoint.sh to repo"
  overwrite_on_create = true
  file                = "cloudrun-entrypoint.sh"
  content             = local_file.cicd_cloudrun_entrypoint[each.key].content

  depends_on = [local_file.cicd_cloudrun_entrypoint, null_resource.init_git_repo]
}

resource "local_file" "cicd_entrypoint" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  filename = "${path.module}/scripts/ci/${each.key}/entrypoint.sh"
  content  = file("${path.module}/scripts/ci/entrypoint.sh.tpl")

  depends_on = [null_resource.init_git_repo]
}

resource "github_repository_file" "entrypoint" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = each.value.branch
  commit_message      = "Add entrypoint.sh to repo"
  overwrite_on_create = true
  file                = "entrypoint.sh"
  content             = local_file.cicd_entrypoint[each.key].content

  depends_on = [local_file.cicd_entrypoint, null_resource.init_git_repo]
}

resource "local_file" "cicd_odoo_conf" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  filename = "${path.module}/scripts/ci/${each.key}/odoo.conf"
  content  = file("${path.module}/scripts/ci/odoo.conf.tpl")

  depends_on = [null_resource.init_git_repo]
}

resource "github_repository_file" "odoo_conf" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = each.value.branch
  commit_message      = "Add odoo.conf to repo"
  overwrite_on_create = true
  file                = "odoo.conf"
  content             = local_file.cicd_odoo_conf[each.key].content

  depends_on = [local_file.cicd_odoo_conf, null_resource.init_git_repo]
}

resource "local_file" "cicd_wait_for_psql" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  filename = "${path.module}/scripts/ci/${each.key}/wait-for-psql.py"
  content  = file("${path.module}/scripts/ci/wait-for-psql.py.tpl")

  depends_on = [null_resource.init_git_repo]
}

resource "github_repository_file" "wait_for_psql" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = each.value.branch
  commit_message      = "Add wait-for-psql.py to repo"
  overwrite_on_create = true
  file                = "wait-for-psql.py"
  content             = local_file.cicd_wait_for_psql[each.key].content

  depends_on = [local_file.cicd_wait_for_psql, null_resource.init_git_repo]
}

resource "local_file" "cicd_dockerfile" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  filename = "${path.module}/scripts/ci/${each.key}/Dockerfile"
  content  = templatefile("${path.module}/scripts/ci/dockerfile.tpl", {
    APP_VERSION = var.application_version
    APP_RELEASE = var.application_release
    APP_SHA     = var.application_sha
  })

  depends_on = [null_resource.init_git_repo]
}

resource "github_repository_file" "dockerfile" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = each.value.branch
  commit_message      = "Add Dockerfile to repo"
  overwrite_on_create = true
  file                = "Dockerfile"
  content             = local_file.cicd_dockerfile[each.key].content

  depends_on = [local_file.cicd_dockerfile, null_resource.init_git_repo]
}

resource "local_file" "cicd_skaffold" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  filename = "${path.module}/scripts/ci/${each.key}/skaffold.yaml"
  content  = templatefile("${path.module}/scripts/ci/skaffold.yaml.tpl", {
    PROJECT_ID  = local.project.project_id
    APP_NAME    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_ENV     = each.key
    APP_REGION  = local.region
    IMAGE_NAME  = var.application_name
    REPO_NAME   = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  depends_on = [null_resource.init_git_repo]
}

resource "github_repository_file" "skaffold" {
  for_each = local.ci_enabled ? local.cicd_environments : {}

  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = each.value.branch
  commit_message      = "Add skaffold.yaml to repo"
  overwrite_on_create = true
  file                = "skaffold.yaml"
  content             = local_file.cicd_skaffold[each.key].content

  depends_on = [local_file.cicd_skaffold, null_resource.init_git_repo]
}
