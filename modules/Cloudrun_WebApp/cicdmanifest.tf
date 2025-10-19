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
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment && length(local.regions) >= 2 ? 1 : 0
  filename = "${path.module}/scripts/ci/base/secondary/kustomization.yaml"
  content  = file("${path.module}/scripts/ci/base/kustomization.yaml.tpl")

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
    HOST_PROJECT_ID   = "${local.project.project_id}"
  })

  # Ensures that the sql_db_postgresql module is created before this resource
  depends_on = [
    null_resource.init_git_repo,
  ]
}

resource "local_file" "secondary_dev_base_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment && length(local.regions) >= 2 ? 1 : 0

  filename = "${path.module}/scripts/ci/base/secondary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/base/deploy.yaml.tpl", {
    PROJECT_ID        = local.project.project_id
    APP_REGION        = local.region
    HA_REGION         = local.regions[1]  # No need for interpolation here
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    HOST_PROJECT_ID   = local.project.project_id  # No need for interpolation here
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
  content         = templatefile("${path.module}/scripts/ci/Dockerfile.tpl", {
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

# Resource for creating a local HTML file (no variable substitution needed)
resource "local_file" "dev_html" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/html/index.html"
  content  = file("${path.module}/scripts/app/html/index.html")

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
    IMAGE_NAME        = var.application_name
    IMAGE_VERSION     = "latest-dev"
    REPO_NAME         = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    REPO_REGION        = local.region
    HOST_PROJECT_ID   = "${local.project.project_id}"
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
    IMAGE_NAME        = var.application_name
    IMAGE_VERSION     = "latest-dev"
    REPO_NAME         = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    REPO_REGION        = local.region
    HOST_PROJECT_ID   = "${local.project.project_id}"
  })

  # Ensures that the sql_db_postgresql module is created before this resource
  depends_on = [
    null_resource.init_git_repo,
  ]
}

#########################################################################
# Customize files to add to qa branch on repo
#########################################################################

# Resource to create a local file from a base kustomization template
resource "local_file" "primary_qa_base_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/base/primary/kustomization.yaml"
  content  = file("${path.module}/scripts/ci/base/kustomization.yaml.tpl")

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file from a base kustomization template
resource "local_file" "secondary_qa_base_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment && length(local.regions) >= 2 ? 1 : 0
  filename = "${path.module}/scripts/ci/base/secondary/kustomization.yaml"
  content  = file("${path.module}/scripts/ci/base/kustomization.yaml.tpl")

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file from an overlay kustomization template, with variables substituted
resource "local_file" "primary_qa_overlay_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/overlay/primary/kustomization.yaml"
  content  = templatefile("${path.module}/scripts/ci/overlay/kustomization.yaml.tpl", {
    PROJECT_ID  = local.project.project_id
    APP_NAME    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    REPO_REGION = local.region
    HA_REGION   = "primary"
    APP_ENV     = "qa"
    IMAGE_NAME  = var.application_name
    REPO_NAME   = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file from an overlay kustomization template, with variables substituted
resource "local_file" "secondary_qa_overlay_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment && length(local.regions) >= 2 ? 1 : 0
  filename = "${path.module}/scripts/ci/overlay/secondary/kustomization.yaml"
  content  = templatefile("${path.module}/scripts/ci/overlay/kustomization.yaml.tpl", {
    PROJECT_ID  = local.project.project_id
    APP_NAME    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    REPO_REGION = local.region
    HA_REGION   = "secondary"
    APP_ENV     = "qa"
    IMAGE_NAME  = var.application_name
    REPO_NAME   = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file for base deployment, with variables substituted
resource "local_file" "primary_qa_base_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/base/primary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/base/deploy.yaml.tpl", {
    PROJECT_ID        = local.project.project_id
    APP_REGION        = local.region
    HA_REGION         = "${local.regions[0]}"
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  })

  # Ensures that the sql_db_postgresql module is created before this resource
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file for base deployment, with variables substituted
resource "local_file" "secondary_qa_base_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment && length(local.regions) >= 2 ? 1 : 0
  filename = "${path.module}/scripts/ci/base/secondary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/base/deploy.yaml.tpl", {
    PROJECT_ID        = local.project.project_id
    APP_REGION        = local.region
    HA_REGION         = "${local.regions[1]}"
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  })

  # Ensures that the sql_db_postgresql module is created before this resource
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local cloudbuild file from a template, with variables substituted
resource "local_file" "qa_cloudbuild" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment && length(local.regions) > 0 ? 1 : 0
  filename = "${path.module}/scripts/ci/cloudbuild.yaml"

  content  = templatefile(
    length(local.regions) >= 2 ? "${path.module}/scripts/ci/cloudbuild_ha.yaml.tpl" : "${path.module}/scripts/ci/cloudbuild.yaml.tpl",
    {
      PROJECT_ID          = local.project.project_id
      APP_REGION          = local.region
      APP_NAME            = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
      APP_ENV             = "qa"
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
resource "local_file" "qa_dockerfile" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  filename        = "${path.module}/scripts/ci/Dockerfile"
  content         = templatefile("${path.module}/scripts/ci/Dockerfile.tpl", {
    APP_VERSION  = "${var.application_version}"
  })

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local Skaffold configuration file from a template.
# Skaffold is a tool that facilitates CI/CD.
resource "local_file" "qa_skaffold" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
    filename                  = "${path.module}/scripts/ci/skaffold.yaml"
    content                   = templatefile("${path.module}/scripts/ci/skaffold.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    APP_NAME                  = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_ENV                   = "qa"
    APP_REGION                = local.region
    IMAGE_NAME                = var.application_name
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local HTML file (no variable substitution needed)
resource "local_file" "qa_html" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/html/index.html"
  content  = file("${path.module}/scripts/app/html/index.html")

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file for overlay deployment, with variables substituted
resource "local_file" "primary_qa_overlay_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/overlay/primary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/overlay/deploy.yaml.tpl", {
    # Variables are passed to the template file for dynamic content generation
    PROJECT_ID        = local.project.project_id
    PROJECT_NUMBER    = local.project_number
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_ENV           = "qa"
    IMAGE_NAME        = var.application_name
    IMAGE_VERSION     = "latest-qa"
    REPO_NAME         = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    REPO_REGION        = local.region
  })

  # Ensures that the sql_db_postgresql module is created before this resource
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file for overlay deployment, with variables substituted
resource "local_file" "secondary_qa_overlay_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment && length(local.regions) >= 2 ? 1 : 0
  filename = "${path.module}/scripts/ci/overlay/secondary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/overlay/deploy.yaml.tpl", {
    # Variables are passed to the template file for dynamic content generation
    PROJECT_ID        = local.project.project_id
    PROJECT_NUMBER    = local.project_number
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_ENV           = "qa"
    IMAGE_NAME        = var.application_name
    IMAGE_VERSION     = "latest-qa"
    REPO_NAME         = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    REPO_REGION        = local.region
  })

  # Ensures that the sql_db_postgresql module is created before this resource
  depends_on = [
    null_resource.init_git_repo,
  ]
}

#########################################################################
# Customize files to add to prod branch on repo
#########################################################################

# Resource to create a local file from a base kustomization template
resource "local_file" "primary_prod_base_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/base/primary/kustomization.yaml"
  content  = file("${path.module}/scripts/ci/base/kustomization.yaml.tpl")

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file from a base kustomization template
resource "local_file" "secondary_prod_base_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment && length(local.regions) >= 2 ? 1 : 0
  filename = "${path.module}/scripts/ci/base/secondary/kustomization.yaml"
  content  = file("${path.module}/scripts/ci/base/kustomization.yaml.tpl")

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file from an overlay kustomization template, with variables substituted
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

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file from an overlay kustomization template, with variables substituted
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

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file for base deployment, with variables substituted
resource "local_file" "primary_prod_base_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/base/primary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/base/deploy.yaml.tpl", {
    PROJECT_ID        = local.project.project_id
    APP_REGION        = local.region
    HA_REGION         = "${local.regions[0]}"
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  })

  # Ensures that the sql_db_postgresql module is created before this resource
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file for base deployment, with variables substituted
resource "local_file" "secondary_prod_base_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment && length(local.regions) >= 2 ? 1 : 0
  filename = "${path.module}/scripts/ci/base/secondary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/base/deploy.yaml.tpl", {
    PROJECT_ID        = local.project.project_id
    APP_REGION        = local.region
    HA_REGION         = "${local.regions[1]}"
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  })

  # Ensures that the sql_db_postgresql module is created before this resource
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local cloudbuild file from a template, with variables substituted
resource "local_file" "prod_cloudbuild" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment && length(local.regions) > 0 ? 1 : 0
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
resource "local_file" "prod_dockerfile" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  filename        = "${path.module}/scripts/ci/Dockerfile"
  content         = templatefile("${path.module}/scripts/ci/Dockerfile.tpl", {
    APP_VERSION  = "${var.application_version}"
  })

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local Skaffold configuration file from a template.
# Skaffold is a tool that facilitates CI/CD.
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

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local HTML file (no variable substitution needed)
resource "local_file" "prod_html" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/html/index.html"
  content  = file("${path.module}/scripts/app/html/index.html")

  # Dependency to ensure the file is only created after initializing the git repository
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file for overlay deployment, with variables substituted
resource "local_file" "primary_prod_overlay_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  filename = "${path.module}/scripts/ci/overlay/primary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/overlay/deploy.yaml.tpl", {
    # Variables are passed to the template file for dynamic content generation
    PROJECT_ID        = local.project.project_id
    PROJECT_NUMBER    = local.project_number
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_ENV           = "prod"
    IMAGE_NAME        = var.application_name
    IMAGE_VERSION     = "latest-prod"
    REPO_NAME         = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    REPO_REGION        = local.region
  })

  # Ensures that the sql_db_postgresql module is created before this resource
  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource to create a local file for overlay deployment, with variables substituted
resource "local_file" "secondary_prod_overlay_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment && length(local.regions) >= 2 ? 1 : 0
  filename = "${path.module}/scripts/ci/overlay/secondary/deploy.yaml"
  content  = templatefile("${path.module}/scripts/ci/overlay/deploy.yaml.tpl", {
    # Variables are passed to the template file for dynamic content generation
    PROJECT_ID        = local.project.project_id
    PROJECT_NUMBER    = local.project_number
    APP_NAME          = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_ENV           = "prod"
    IMAGE_NAME        = var.application_name
    IMAGE_VERSION     = "latest-prod"
    REPO_NAME         = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    REPO_REGION        = local.region
  })

  # Ensures that the sql_db_postgresql module is created before this resource
  depends_on = [
    null_resource.init_git_repo,
  ]
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

# Resource definition for a GitHub repository file for the HTML index file
resource "github_repository_file" "dev_html" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "dev"
  commit_message      = "Add HTML file to repo"
  overwrite_on_create = true
  file                = "html/index.html"
  content             = local_file.dev_html[count.index].content

  depends_on      = [
    local_file.dev_html,
    null_resource.init_git_repo
  ]
}

#########################################################################
# Add files to repo on qa branch
#########################################################################

# Resource for creating 'base/primary/kustomization.yaml' in the GitHub repository on the 'qa' branch
resource "github_repository_file" "primary_qa_base_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "qa"
  commit_message      = "Add base kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "base/primary/kustomization.yaml"
  content             = local_file.primary_qa_base_kustomization[count.index].content

  # Dependencies to ensure the local file and qa branch exist before creation
  depends_on = [
    local_file.primary_qa_base_kustomization,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'base/secondary/kustomization.yaml' in the GitHub repository on the 'qa' branch
resource "github_repository_file" "secondary_qa_base_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment && length(local.regions) >= 2 ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "qa"
  commit_message      = "Add base kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "base/secondary/kustomization.yaml"
  content             = local_file.secondary_qa_base_kustomization[count.index].content

  # Dependencies to ensure the local file and qa branch exist before creation
  depends_on = [
    local_file.secondary_qa_base_kustomization,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'overlay/primary/kustomization.yaml' in the GitHub repository
resource "github_repository_file" "primary_qa_overlay_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  # Same repository and branch as before
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "qa"
  commit_message      = "Add overlay kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/primary/kustomization.yaml"
  content             = local_file.primary_qa_overlay_kustomization[count.index].content

  # Dependencies for overlay kustomization
  depends_on = [
    local_file.primary_qa_overlay_kustomization,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'overlay/secondary/kustomization.yaml' in the GitHub repository
resource "github_repository_file" "secondary_qa_overlay_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment && length(local.regions) >= 2 ? 1 : 0
  # Same repository and branch as before
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "qa"
  commit_message      = "Add overlay kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/secondary/kustomization.yaml"
  content             = local_file.secondary_qa_overlay_kustomization[count.index].content

  # Dependencies for overlay kustomization
  depends_on = [
    local_file.secondary_qa_overlay_kustomization,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'base/deploy.yaml' in the GitHub repository
resource "github_repository_file" "primary_qa_base_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  # Configuration for repository, branch, and commit message
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "qa"
  commit_message      = "Add base deploy.yaml to repo"
  overwrite_on_create = true
  file                = "base/primary/deploy.yaml"
  content             = local_file.primary_qa_base_deploy[count.index].content

  # Dependencies for base deployment
  depends_on = [
    local_file.primary_qa_base_deploy,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'base/deploy.yaml' in the GitHub repository
resource "github_repository_file" "secondary_qa_base_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment && length(local.regions) >= 2 ? 1 : 0
  # Configuration for repository, branch, and commit message
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "qa"
  commit_message      = "Add base deploy.yaml to repo"
  overwrite_on_create = true
  file                = "base/secondary/deploy.yaml"
  content             = local_file.secondary_qa_base_deploy[count.index].content

  # Dependencies for base deployment
  depends_on = [
    local_file.secondary_qa_base_deploy,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'overlay/primary/deploy.yaml' in the GitHub repository
resource "github_repository_file" "primary_qa_overlay_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  # Configuration for repository, branch, and commit message
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "qa"
  commit_message      = "Add overlay deploy.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/primary/deploy.yaml"
  content             = local_file.primary_qa_overlay_deploy[count.index].content

  # Dependencies for overlay deployment
  depends_on = [
    local_file.primary_qa_overlay_deploy,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'overlay/secondary/deploy.yaml' in the GitHub repository
resource "github_repository_file" "secondary_qa_overlay_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment && length(local.regions) >= 2 ? 1 : 0
  # Configuration for repository, branch, and commit message
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "qa"
  commit_message      = "Add overlay deploy.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/secondary/deploy.yaml"
  content             = local_file.secondary_qa_overlay_deploy[count.index].content

  # Dependencies for overlay deployment
  depends_on = [
    local_file.secondary_qa_overlay_deploy,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the Cloud Build configuration
resource "github_repository_file" "qa_cloudbuild" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
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
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "qa"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "Dockerfile"
  content             = local_file.qa_dockerfile[count.index].content

  depends_on = [
    local_file.qa_dockerfile,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the Skaffold configuration
resource "github_repository_file" "qa_skaffold" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
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

# Resource definition for a GitHub repository file for the HTML index file
resource "github_repository_file" "qa_html" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "qa"
  commit_message      = "Add HTML file to repo"
  overwrite_on_create = true
  file                = "html/index.html"
  content             = local_file.qa_html[count.index].content

  depends_on      = [
    local_file.qa_html,
    null_resource.init_git_repo
  ]
}

#########################################################################
# Add files to repo on prod branch
#########################################################################

# Resource for creating 'base/primary/kustomization.yaml' in the GitHub repository on the 'prod' branch
resource "github_repository_file" "primary_prod_base_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add base kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "base/primary/kustomization.yaml"
  content             = local_file.primary_prod_base_kustomization[count.index].content

  # Dependencies to ensure the local file and prod branch exist before creation
  depends_on = [
    local_file.primary_prod_base_kustomization,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'base/secondary/kustomization.yaml' in the GitHub repository on the 'prod' branch
resource "github_repository_file" "secondary_prod_base_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment && length(local.regions) >= 2 ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add base kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "base/secondary/kustomization.yaml"
  content             = local_file.secondary_prod_base_kustomization[count.index].content

  # Dependencies to ensure the local file and prod branch exist before creation
  depends_on = [
    local_file.secondary_prod_base_kustomization,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'overlay/primary/kustomization.yaml' in the GitHub repository
resource "github_repository_file" "primary_prod_overlay_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  # Same repository and branch as before
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add overlay kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/primary/kustomization.yaml"
  content             = local_file.primary_prod_overlay_kustomization[count.index].content

  # Dependencies for overlay kustomization
  depends_on = [
    local_file.primary_prod_overlay_kustomization,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'overlay/secondary/kustomization.yaml' in the GitHub repository
resource "github_repository_file" "secondary_prod_overlay_kustomization" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment && length(local.regions) >= 2 ? 1 : 0
  # Same repository and branch as before
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add overlay kustomization.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/secondary/kustomization.yaml"
  content             = local_file.secondary_prod_overlay_kustomization[count.index].content

  # Dependencies for overlay kustomization
  depends_on = [
    local_file.secondary_prod_overlay_kustomization,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'base/deploy.yaml' in the GitHub repository
resource "github_repository_file" "primary_prod_base_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  # Configuration for repository, branch, and commit message
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add base deploy.yaml to repo"
  overwrite_on_create = true
  file                = "base/primary/deploy.yaml"
  content             = local_file.primary_prod_base_deploy[count.index].content

  # Dependencies for base deployment
  depends_on = [
    local_file.primary_prod_base_deploy,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'base/deploy.yaml' in the GitHub repository
resource "github_repository_file" "secondary_prod_base_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment && length(local.regions) >= 2 ? 1 : 0
  # Configuration for repository, branch, and commit message
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add base deploy.yaml to repo"
  overwrite_on_create = true
  file                = "base/secondary/deploy.yaml"
  content             = local_file.secondary_prod_base_deploy[count.index].content

  # Dependencies for base deployment
  depends_on = [
    local_file.secondary_prod_base_deploy,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'overlay/primary/deploy.yaml' in the GitHub repository
resource "github_repository_file" "primary_prod_overlay_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  # Configuration for repository, branch, and commit message
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add overlay deploy.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/primary/deploy.yaml"
  content             = local_file.primary_prod_overlay_deploy[count.index].content

  # Dependencies for overlay deployment
  depends_on = [
    local_file.primary_prod_overlay_deploy,
    null_resource.init_git_repo
  ]
}

# Resource for creating 'overlay/secondary/deploy.yaml' in the GitHub repository
resource "github_repository_file" "secondary_prod_overlay_deploy" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment && length(local.regions) >= 2 ? 1 : 0
  # Configuration for repository, branch, and commit message
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add overlay deploy.yaml to repo"
  overwrite_on_create = true
  file                = "overlay/secondary/deploy.yaml"
  content             = local_file.secondary_prod_overlay_deploy[count.index].content

  # Dependencies for overlay deployment
  depends_on = [
    local_file.secondary_prod_overlay_deploy,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the Cloud Build configuration
resource "github_repository_file" "prod_cloudbuild" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
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
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add file to repo"
  overwrite_on_create = true
  file                = "Dockerfile"
  content             = local_file.prod_dockerfile[count.index].content

  depends_on = [
    local_file.prod_dockerfile,
    null_resource.init_git_repo
  ]
}

# Resource definition for a GitHub repository file for the Skaffold configuration
resource "github_repository_file" "prod_skaffold" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
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

# Resource definition for a GitHub repository file for the HTML index file
resource "github_repository_file" "prod_html" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  repository          = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  branch              = "prod"
  commit_message      = "Add HTML file to repo"
  overwrite_on_create = true
  file                = "html/index.html"
  content             = local_file.prod_html[count.index].content

  depends_on      = [
    local_file.prod_html,
    null_resource.init_git_repo
  ]
}
