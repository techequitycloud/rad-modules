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
# Customize files to add to dev branch on repo
#########################################################################

# Resource to create a local file from a base kustomization template
resource "local_file" "primary_dev_base_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/base/primary/kustomization.yaml"
  content  = file("${path.module}/scripts/ci/base/kustomization.yaml.tpl")

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file from a base kustomization template
resource "local_file" "secondary_dev_base_kustomization" {
  count     = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment && length(local.regions) >= 2 ? 1 : 0
  filename  = "${path.module}/scripts/ci/base/secondary/kustomization.yaml"
  content   = file("${path.module}/scripts/ci/base/kustomization.yaml.tpl")

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file from an overlay kustomization template, with variables substituted
resource "local_file" "primary_dev_overlay_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/overlay/primary/kustomization.yaml"
  content  = templatefile("${path.module}/scripts/ci/overlay/kustomization.yaml.tpl", {
    PROJECT_ID  = local.project.project_id
    APP_NAME    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    REPO_REGION = local.region
    HA_REGION   = "primary"
    APP_ENV     = "dev"
    IMAGE_NAME  = var.application_name
    REPO_NAME   = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file from an overlay kustomization template, with variables substituted
resource "local_file" "secondary_dev_overlay_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment && length(local.regions) >= 2 ? 1 : 0
  filename = "${path.module}/scripts/ci/overlay/secondary/kustomization.yaml"
  content  = templatefile("${path.module}/scripts/ci/overlay/kustomization.yaml.tpl", {
    PROJECT_ID  = local.project.project_id
    APP_NAME    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    REPO_REGION = local.region
    HA_REGION   = "secondary"
    APP_ENV     = "dev"
    IMAGE_NAME  = var.application_name
    REPO_NAME   = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file for base deployment, with variables substituted
resource "local_file" "primary_dev_base_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/base/primary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/base/deploy.yaml.tpl", {
    PROJECT_ID        = local.project.project_id
    APP_REGION        = local.region
    HA_REGION         = "${local.regions[0]}"
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    DATABASE_INSTANCE =  local.db_instance_name
    NETWORK_NAME      = "${var.network_name}"
    HOST_PROJECT_ID   = "${local.project.project_id}"
  })

  # Ensures that the sql_db_postgresql module is created before this resource
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file for base deployment, with variables substituted
resource "local_file" "secondary_dev_base_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment && length(local.regions) >= 2 ? 1 : 0
  filename = "${path.module}/scripts/ci/base/secondary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/base/deploy.yaml.tpl", {
    PROJECT_ID        = local.project.project_id
    APP_REGION        = local.region
    HA_REGION         = "${local.regions[1]}"
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    DATABASE_INSTANCE =  local.db_instance_name
    NETWORK_NAME      = "${var.network_name}"
    HOST_PROJECT_ID   = "${local.project.project_id}"
  })

  # Ensures that the sql_db_postgresql module is created before this resource
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local cloudbuild file from a template, with variables substituted
resource "local_file" "dev_cloudbuild" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment && length(local.regions) > 0 ? 1 : 0
  filename = "${path.module}/scripts/ci/cloudbuild.yaml"

  content  = templatefile(
    length(local.regions) >= 2 ? "${path.module}/scripts/ci/cloudbuild_ha.yaml.tpl" : "${path.module}/scripts/ci/cloudbuild.yaml.tpl",
    {
      PROJECT_ID          = local.project.project_id
      APP_REGION          = local.region
      APP_NAME            = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
      APP_ENV             = "dev"
      PRIMARY_HA_REGION   = local.regions[0]
      SECONDARY_HA_REGION = length(local.regions) >= 2 ? local.regions[1] : ""
      IMAGE_NAME          = var.application_name
      REPO_NAME           = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
      # UNIQUE_ID       = random_id.note_id.hex
      # APP_ATTESTOR    = "attestor-${var.tenant_deployment_id}-${local.random_id}"
    }
  )

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a Dockerfile from a template, which will be used to build the application's container image.
resource "local_file" "dev_dockerfile" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  filename        = "${path.module}/scripts/ci/Dockerfile"
  content         = templatefile("${path.module}/scripts/ci/dockerfile.tpl", {
    APP_VERSION  = "${var.application_version}"
  })

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local Skaffold configuration file from a template.
# Skaffold is a tool that facilitates CI/CD.
resource "local_file" "dev_skaffold" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/skaffold.yaml"
    content                   = templatefile("${path.module}/scripts/ci/skaffold.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    APP_NAME                  = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_ENV                   = "dev"
    APP_REGION                = local.region
    IMAGE_NAME                = var.application_name
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file for overlay deployment, with variables substituted
resource "local_file" "primary_dev_overlay_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/overlay/primary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/overlay/deploy.yaml.tpl", {
    # Variables are passed to the template file for dynamic content generation
    PROJECT_ID        = local.project.project_id
    PROJECT_NUMBER    = local.project_number
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_ENV           = "dev"
    APP_NFS_IP        = local.nfs_internal_ip
    DATABASE_USER     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
    DATABASE_NAME     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
    DATABASE_PASSWORD = "${local.db_instance_name}-${var.application_database_name}dev-password-${var.tenant_deployment_id}-${local.random_id}"
    DATABASE_ROOT_PASSWORD = "${ local.db_instance_name}-root-password"
    DATABASE_HOST     = local.db_internal_ip
    DATABASE_INSTANCE =  local.db_instance_name
    IMAGE_NAME        = var.application_name
    IMAGE_VERSION     = "latest-dev"
    REPO_NAME         = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    REPO_REGION        = local.region
    BACKUP_BUCKET     = "${local.project.project_id}-backups"
    DATA_BUCKET       = "${local.project.project_id}-data"
    NETWORK_NAME      = "${var.network_name}"
    HOST_PROJECT_ID   = "${local.project.project_id}"
    SHARED_DIRECTORY  = "/share/app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
  })

  # Ensures that the sql_db_postgresql module is created before this resource
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file for overlay deployment, with variables substituted
resource "local_file" "secondary_dev_overlay_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment && length(local.regions) >= 2 ? 1 : 0
  filename = "${path.module}/scripts/ci/overlay/secondary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/overlay/deploy.yaml.tpl", {
    # Variables are passed to the template file for dynamic content generation
    PROJECT_ID        = local.project.project_id
    PROJECT_NUMBER    = local.project_number
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_ENV           = "dev"
    APP_NFS_IP        = local.nfs_internal_ip
    DATABASE_USER     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
    DATABASE_NAME     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
    DATABASE_PASSWORD = "${local.db_instance_name}-${var.application_database_name}dev-password-${var.tenant_deployment_id}-${local.random_id}"
    DATABASE_ROOT_PASSWORD = "${ local.db_instance_name}-root-password"
    DATABASE_HOST     = local.db_internal_ip
    DATABASE_INSTANCE =  local.db_instance_name
    IMAGE_NAME        = var.application_name
    IMAGE_VERSION     = "latest-dev"
    REPO_NAME         = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    REPO_REGION        = local.region
    BACKUP_BUCKET     = "${local.project.project_id}-backups"
    DATA_BUCKET       = "${local.project.project_id}-data"
    NETWORK_NAME      = "${var.network_name}"
    HOST_PROJECT_ID   = "${local.project.project_id}"
    SHARED_DIRECTORY  = "/share/app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
  })

  # Ensures that the sql_db_postgresql module is created before this resource
  depends_on = [
    null_resource.init_git_repo,
  ]
}

data "local_file" "dev_auto_configure" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/auto_configure.php"
}

data "local_file" "dev_openemr_conf" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/openemr.conf"
}

data "local_file" "dev_php_ini" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/php.ini"
}

data "local_file" "dev_openemr" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/openemr.sh"
}

data "local_file" "dev_ssl" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/ssl.sh"
}

data "local_file" "dev_xdebug" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/xdebug.sh"
}

data "local_file" "dev_cloudrun_entrypoint" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/cloudrun-entrypoint.sh"
}

#########################################################################
# Add files to repo on dev branch
#########################################################################

# Resource for creating 'base/primary/kustomization.yaml' in the GitHub repository on the 'dev' branch
resource "github_repository_file" "primary_dev_base_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add base kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "base/primary/kustomization.yaml"
  content             = local_file.primary_dev_base_kustomization[count.index].content

  # Dependencies to ensure the local file and dev branch exist before creation
  depends_on = [
    local_file.primary_dev_base_kustomization,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'base/secondary/kustomization.yaml' in the GitHub repository on the 'dev' branch
resource "github_repository_file" "secondary_dev_base_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment && length(local.regions) >= 2 ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add base kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "base/secondary/kustomization.yaml"
  content             = local_file.secondary_dev_base_kustomization[count.index].content

  # Dependencies to ensure the local file and dev branch exist before creation
  depends_on = [
    local_file.secondary_dev_base_kustomization,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'overlay/primary/kustomization.yaml' in the GitHub repository
resource "github_repository_file" "primary_dev_overlay_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  # Same repository and branch as before
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add overlay kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/primary/kustomization.yaml"
  content             = local_file.primary_dev_overlay_kustomization[count.index].content

  # Dependencies for overlay kustomization
  depends_on = [
    local_file.primary_dev_overlay_kustomization,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'overlay/secondary/kustomization.yaml' in the GitHub repository
resource "github_repository_file" "secondary_dev_overlay_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment && length(local.regions) >= 2 ? 1 : 0
  # Same repository and branch as before
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add overlay kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/secondary/kustomization.yaml"
  content             = local_file.secondary_dev_overlay_kustomization[count.index].content

  # Dependencies for overlay kustomization
  depends_on = [
    local_file.secondary_dev_overlay_kustomization,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'base/deploy.yaml' in the GitHub repository
resource "github_repository_file" "primary_dev_base_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  # Configuration for repository, branch, and commit message
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add base deploy.yaml to repo"
  overwrite_on_create = true
  file                = "base/primary/deploy.yaml"
  content             = local_file.primary_dev_base_deploy[count.index].content

  # Dependencies for base deployment
  depends_on = [
    local_file.primary_dev_base_deploy,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'base/deploy.yaml' in the GitHub repository
resource "github_repository_file" "secondary_dev_base_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment && length(local.regions) >= 2 ? 1 : 0
  # Configuration for repository, branch, and commit message
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add base deploy.yaml to repo"
  overwrite_on_create = true
  file                = "base/secondary/deploy.yaml"
  content             = local_file.secondary_dev_base_deploy[count.index].content

  # Dependencies for base deployment
  depends_on = [
    local_file.secondary_dev_base_deploy,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'overlay/primary/deploy.yaml' in the GitHub repository
resource "github_repository_file" "primary_dev_overlay_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  # Configuration for repository, branch, and commit message
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add overlay deploy.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/primary/deploy.yaml"
  content             = local_file.primary_dev_overlay_deploy[count.index].content

  # Dependencies for overlay deployment
  depends_on = [
    local_file.primary_dev_overlay_deploy,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'overlay/secondary/deploy.yaml' in the GitHub repository
resource "github_repository_file" "secondary_dev_overlay_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment && length(local.regions) >= 2 ? 1 : 0
  # Configuration for repository, branch, and commit message
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add overlay deploy.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/secondary/deploy.yaml"
  content             = local_file.secondary_dev_overlay_deploy[count.index].content

  # Dependencies for overlay deployment
  depends_on = [
    local_file.secondary_dev_overlay_deploy,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the configuration
resource "github_repository_file" "dev_openemr_conf" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "openemr.conf"
  content             = data.local_file.dev_openemr_conf[count.index].content

  depends_on      = [
    data.local_file.dev_openemr_conf,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the configuration
resource "github_repository_file" "dev_php_ini" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "php.ini"
  content             = data.local_file.dev_php_ini[count.index].content

  depends_on      = [
    data.local_file.dev_php_ini,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the script
resource "github_repository_file" "dev_openemr" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "openemr.sh"
  content             = data.local_file.dev_openemr[count.index].content

  depends_on      = [
    data.local_file.dev_openemr,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the script
resource "github_repository_file" "dev_xdebug" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "xdebug.sh"
  content             = data.local_file.dev_xdebug[count.index].content

  depends_on      = [
    data.local_file.dev_xdebug,
    null_resource.init_git_repo
  ]
}

# Resource for creating the 'cloudrun-entrypoint.sh' file in the GitHub repository on the 'dev' branch
resource "github_repository_file" "dev_cloudrun_entrypoint" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add cloudrun-entrypoint.sh to repo"
  overwrite_on_create = true
  file                = "cloudrun-entrypoint.sh"
  content             = data.local_file.dev_cloudrun_entrypoint[count.index].content

  # Ensure that the local file is created and dev branch exists before this file is added to the repository
  depends_on = [
    data.local_file.dev_cloudrun_entrypoint,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the Cloud Build configuration
resource "github_repository_file" "dev_cloudbuild" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
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
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
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
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
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
