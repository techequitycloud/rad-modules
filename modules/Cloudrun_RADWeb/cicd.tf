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
# Configure Github secret and policies
#########################################################################

# Resource for creating a secret in Google Secret Manager to store a GitHub token
resource "google_secret_manager_secret" "github-token-secret" {
  count      = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" ? 1 : 0
  project    = local.project.project_id  # The project where the secret is managed
  secret_id  = "github-token-secret-${var.tenant_deployment_id}-${local.random_id}"  # The identifier for the secret

  # Configuration for automatic replication of the secret
  replication {
    auto {}
  }
}

# Resource for creating a version of the secret with the actual GitHub token data
resource "google_secret_manager_secret_version" "github-token-secret" {
  count      = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" ? 1 : 0
  secret      = google_secret_manager_secret.github-token-secret[count.index].id  # Reference to the secret ID
  secret_data = var.application_git_token                                         # The GitHub token
}

# Data source for defining an IAM policy that grants access to the GitHub token secret
data "google_iam_policy" "github-secret-accessor" {
  count      = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" ? 1 : 0
  binding {
    role    = "roles/secretmanager.secretAccessor"  # Role granting access to read secrets
    members = [
      "serviceAccount:service-${local.project_number}@gcp-sa-cloudbuild.iam.gserviceaccount.com",
    ]
  }
}

# Resource for applying the IAM policy to the GitHub token secret
resource "google_secret_manager_secret_iam_policy" "policy" {
  count      = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" ? 1 : 0
  project     = local.project.project_id                             # The project where the secret is managed
  secret_id   = google_secret_manager_secret.github-token-secret[count.index].id  # The identifier for the secret
  policy_data = data.google_iam_policy.github-secret-accessor[count.index].policy_data   # The IAM policy data to apply
} 

#########################################################################
# Create private git repo
#########################################################################

# Provider configuration for GitHub
provider "github" {
  token  = var.application_git_token                                    # The GitHub token file
  owner  = var.application_git_organization                                      # The GitHub organization or user
}

# Resource for creating a private GitHub repository
resource "github_repository" "project_private_repo" {
  count       = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" ? 1 : 0
  name        = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"   # The name of the repository
  description = "Project git repo managed by terraform"           # Description of the repository
  visibility  = "private"                                         # Visibility set to private
}

resource "null_resource" "init_git_repo" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" ? 1 : 0

  triggers = {
    git_repo     = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    git_org      = var.application_git_organization
    github_token = var.application_git_token
  }

  provisioner "local-exec" {
    command     = "chmod +x ./init_git_repo.sh && ./init_git_repo.sh && sleep 30"
    working_dir = "${path.module}/scripts/ci"
    
    environment = {
      GIT_REPO      = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
      GIT_ORG       = var.application_git_organization
      GITHUB_TOKEN  = var.application_git_token
      GIT_USERNAMES = join(",", var.application_git_usernames)
      CLEANUP_GIT   = "false"  # Don't cleanup during apply
    }
  }

  # Add destroy-time provisioner to cleanup
  provisioner "local-exec" {
    when        = destroy
    command     = "rm -rf .git 2>/dev/null || true"
    working_dir = "${path.module}/scripts/ci"
    on_failure  = continue
  }

  depends_on = [
    google_cloudbuildv2_repository.github_repository,
    google_secret_manager_secret_version.github-token-secret
  ]
}

#########################################################################
# Create Connection to github.com
#########################################################################

# Resource for creating a Cloud Build GitHub connection
resource "google_cloudbuildv2_connection" "github_connection" {
  count    = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" ? 1 : 0
  project  = local.project.project_id  # The project ID where the connection will be created
  location = local.region                # The location/region where the connection will be created
  name     = "${var.application_name}-github-connect-${var.tenant_deployment_id}-${local.random_id}"  # The name of the connection

  # Configuration block for GitHub settings
  github_config {
    app_installation_id = var.application_git_installation_id  # The GitHub App installation ID

    # Configuration block for authorizer credentials using OAuth token
    authorizer_credential {
      oauth_token_secret_version = google_secret_manager_secret_version.github-token-secret[count.index].id  # Reference to the secret version containing the OAuth token
    }
  }
  depends_on = [
    google_secret_manager_secret_iam_policy.policy,
  ]
}

# Resource for creating a Cloud Build repository which is linked to the GitHub repository
resource "google_cloudbuildv2_repository" "github_repository" {
  count    = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" ? 1 : 0
  project  = local.project.project_id  # The project ID where the repository will be created
  name     = "${var.application_name}-github-repo"  # The name of the Cloud Build repository
  parent_connection = google_cloudbuildv2_connection.github_connection[count.index].id  # Reference to the parent connection created above
  remote_uri = "https://github.com/${var.application_git_organization}/${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}.git"  # URI of the GitHub repository to connect

  depends_on = [
    github_repository.project_private_repo,
  ]
}

#########################################################################
# Create dev, qa and prod triggers
#########################################################################

# Resource for creating a Google Cloud Build trigger for a repository
resource "google_cloudbuild_trigger" "dev_repo_trigger" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment ? 1 : 0
  # The ID of the project where the trigger will be created
  project  = local.project.project_id

  # Name of the trigger, which includes the application name from a variable
  name     = "${var.application_name}-dev-github-trigger-${var.tenant_deployment_id}-${local.random_id}"

  # The location/region where the trigger will be applied
  location = local.region

  # The trigger can be disabled
  disabled = true

  # Configuration for repository events that will invoke this trigger
  repository_event_config {
    # The ID of the repository that this trigger is associated with
    repository = google_cloudbuildv2_repository.github_repository[count.index].id

    # Specifies that the trigger should only fire on push events to the 'dev' branch
    push {
      branch = "^dev$"
    }
  }

  # The path to the build configuration file (cloudbuild.yaml) within the repository
  filename = "cloudbuild.yaml"

  service_account = "projects/${local.project.project_id}/serviceAccounts/cloudbuild-sa@${local.project.project_id}.iam.gserviceaccount.com"

  # Dependencies ensure that all the specified GitHub repository files are created before this trigger
  depends_on = [
    github_repository_file.primary_dev_overlay_kustomization,
    github_repository_file.primary_dev_base_kustomization,
    github_repository_file.primary_dev_overlay_deploy,
    github_repository_file.primary_dev_base_deploy,
    github_repository_file.secondary_dev_overlay_kustomization,
    github_repository_file.secondary_dev_base_kustomization,
    github_repository_file.secondary_dev_overlay_deploy,
    github_repository_file.secondary_dev_base_deploy,
    github_repository_file.dev_cloudbuild,
    github_repository_file.dev_skaffold,
    google_cloud_run_v2_service.dev_app_service
  ]
}

# Resource for creating a Google Cloud Build trigger for a repository
resource "google_cloudbuild_trigger" "qa_repo_trigger" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment ? 1 : 0
  # The ID of the project where the trigger will be created
  project  = local.project.project_id

  # Name of the trigger, which includes the application name from a variable
  name     = "${var.application_name}-qa-github-trigger-${var.tenant_deployment_id}-${local.random_id}"

  # The location/region where the trigger will be applied
  location = local.region

  # Tnethe trigger can be disabled
  disabled = true

  # Configuration for repository events that will invoke this trigger
  repository_event_config {
    # The ID of the repository that this trigger is associated with
    repository = google_cloudbuildv2_repository.github_repository[count.index].id

    # Specifies that the trigger should only fire on push events to the 'qa' branch
    push {
      branch = "^qa$"
    }
  }

  # The path to the build configuration file (cloudbuild.yaml) within the repository
  filename = "cloudbuild.yaml"

  service_account = "projects/${local.project.project_id}/serviceAccounts/cloudbuild-sa@${local.project.project_id}.iam.gserviceaccount.com"

  # Dependencies ensure that all the specified GitHub repository files are created before this trigger
  depends_on = [
    github_repository_file.primary_qa_overlay_kustomization,
    github_repository_file.primary_qa_base_kustomization,
    github_repository_file.primary_qa_overlay_deploy,
    github_repository_file.primary_qa_base_deploy,
    github_repository_file.secondary_qa_overlay_kustomization,
    github_repository_file.secondary_qa_base_kustomization,
    github_repository_file.secondary_qa_overlay_deploy,
    github_repository_file.secondary_qa_base_deploy,
    github_repository_file.qa_cloudbuild,
    github_repository_file.qa_skaffold,
    google_cloud_run_v2_service.qa_app_service
  ]
}

# Resource for creating a Google Cloud Build trigger for a repository
resource "google_cloudbuild_trigger" "prod_repo_trigger" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment ? 1 : 0
  # The ID of the project where the trigger will be created
  project  = local.project.project_id

  # Name of the trigger, which includes the application name from a variable
  name     = "${var.application_name}-prod-github-trigger-${var.tenant_deployment_id}-${local.random_id}"

  # The location/region where the trigger will be applied
  location = local.region

  # Tnethe trigger can be disabled
  disabled = true

  # Configuration for repository events that will invoke this trigger
  repository_event_config {
    # The ID of the repository that this trigger is associated with
    repository = google_cloudbuildv2_repository.github_repository[count.index].id

    # Specifies that the trigger should only fire on push events to the 'prod' branch
    push {
      branch = "^prod$"
    }
  }

  # The path to the build configuration file (cloudbuild.yaml) within the repository
  filename = "cloudbuild.yaml"

  service_account = "projects/${local.project.project_id}/serviceAccounts/cloudbuild-sa@${local.project.project_id}.iam.gserviceaccount.com"

  # Dependencies ensure that all the specified GitHub repository files are created before this trigger
  depends_on = [
    github_repository_file.primary_prod_overlay_kustomization,
    github_repository_file.primary_prod_base_kustomization,
    github_repository_file.primary_prod_overlay_deploy,
    github_repository_file.primary_prod_base_deploy,
    github_repository_file.secondary_prod_overlay_kustomization,
    github_repository_file.secondary_prod_base_kustomization,
    github_repository_file.secondary_prod_overlay_deploy,
    github_repository_file.secondary_prod_base_deploy,
    github_repository_file.prod_cloudbuild,
    github_repository_file.prod_skaffold,
    google_cloud_run_v2_service.prod_app_service
  ]
}
