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
  project    = local.project.project_id
  secret_id  = "github-token-secret-${var.tenant_deployment_id}-${local.random_id}"

  replication {
    auto {}
  }
}

# Resource for creating a version of the secret with the actual GitHub token data
resource "google_secret_manager_secret_version" "github-token-secret" {
  count      = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" ? 1 : 0
  secret      = google_secret_manager_secret.github-token-secret[count.index].id
  secret_data = var.application_git_token

  depends_on = [
    google_secret_manager_secret.github-token-secret,
  ]
}

# Data source for defining an IAM policy that grants access to the GitHub token secret
data "google_iam_policy" "github-secret-accessor" {
  count      = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" ? 1 : 0
  binding {
    role    = "roles/secretmanager.secretAccessor"
    members = [
      "serviceAccount:service-${local.project_number}@gcp-sa-cloudbuild.iam.gserviceaccount.com",
    ]
  }
}

# Resource for applying the IAM policy to the GitHub token secret
resource "google_secret_manager_secret_iam_policy" "policy" {
  count      = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" ? 1 : 0
  project     = local.project.project_id
  secret_id   = google_secret_manager_secret.github-token-secret[count.index].id
  policy_data = data.google_iam_policy.github-secret-accessor[count.index].policy_data

  depends_on = [
    google_secret_manager_secret.github-token-secret,
  ]
}

#########################################################################
# Create private git repo and manage via GitHub Provider
#########################################################################

# Provider configuration for GitHub
provider "github" {
  token  = var.application_git_token
  owner  = var.application_git_organization
}

# Resource for creating a private GitHub repository
resource "github_repository" "project_private_repo" {
  count       = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" ? 1 : 0
  name        = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  description = "Project git repo managed by terraform"
  visibility  = "private"
  auto_init   = true # Initialize with README to allow branching immediately
}

# Resource for README.md (replacing script logic)
resource "github_repository_file" "readme" {
  count               = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" ? 1 : 0
  repository          = github_repository.project_private_repo[0].name
  branch              = "main"
  file                = "README.md"
  content             = "Banking Portal on GKE"
  commit_message      = "Initialize main branch with README"
  overwrite_on_create = true
}

locals {
  # Define a local variable to capture the condition logic, but keep it non-sensitive if possible
  # The problem is `var.application_git_token` is sensitive.
  # We can't use it directly in for_each if we can't determine the keys.
  # However, the keys here are just env names ('dev', 'qa', 'prod'). They are NOT sensitive.
  # Terraform complains because the *condition* uses a sensitive variable.
  # We can use `nonsensitive()` function if we are sure it's safe for the plan logic,
  # or better, rely on `var.configure_continuous_integration` which is boolean and not sensitive.
  # But we must check if token is provided.
  # We can create a local boolean:
  cicd_enabled = var.configure_continuous_integration && nonsensitive(var.application_git_token != null && var.application_git_token != "")

  # Filter environments based on this non-sensitive boolean
  cicd_environments = { for k, v in local.environments : k => v if local.cicd_enabled }
}

# Resource for creating branches (dev, qa, prod)
resource "github_branch" "branches" {
  for_each = local.cicd_environments
  repository = github_repository.project_private_repo[0].name
  branch     = each.key
  source_branch = "main" # Create from main

  depends_on = [github_repository_file.readme]
}

# Add collaborators
resource "github_repository_collaborator" "collaborators" {
  for_each = local.cicd_enabled ? var.application_git_usernames : []
  repository = github_repository.project_private_repo[0].name
  username   = each.value
  permission = "push" # Equivalent to write access
}


#########################################################################
# Create Connection to github.com
#########################################################################

# Resource for creating a Cloud Build GitHub connection
resource "google_cloudbuildv2_connection" "github_connection" {
  count    = local.cicd_enabled ? 1 : 0
  project  = local.project.project_id
  location = local.region
  name     = "${var.application_name}-github-connect-${var.tenant_deployment_id}-${local.random_id}"

  github_config {
    app_installation_id = var.application_git_installation_id

    authorizer_credential {
      oauth_token_secret_version = google_secret_manager_secret_version.github-token-secret[0].id
    }
  }
  depends_on = [
    google_secret_manager_secret_iam_policy.policy,
  ]
}

# Resource for creating a Cloud Build repository which is linked to the GitHub repository
resource "google_cloudbuildv2_repository" "github_repository" {
  count    = local.cicd_enabled ? 1 : 0
  project  = local.project.project_id
  name     = "${var.application_name}-github-repo"
  parent_connection = google_cloudbuildv2_connection.github_connection[0].id
  remote_uri = "https://github.com/${var.application_git_organization}/${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}.git"

  depends_on = [
    github_repository.project_private_repo,
  ]
}

#########################################################################
# Create dev, qa and prod triggers (Duplication Removed)
#########################################################################

resource "google_cloudbuild_trigger" "repo_trigger" {
  for_each = local.cicd_environments

  project  = local.project.project_id
  name     = "${var.application_name}-${each.key}-github-trigger-${var.tenant_deployment_id}-${local.random_id}"
  location = local.region
  disabled = true

  repository_event_config {
    repository = google_cloudbuildv2_repository.github_repository[0].id
    push {
      branch = "^${each.key}$"
    }
  }

  filename = "cloudbuild.yaml"

  service_account = "projects/${local.project.project_id}/serviceAccounts/cloudbuild-sa@${local.project.project_id}.iam.gserviceaccount.com"

  depends_on = [
    google_cloud_run_v2_service.app_service,
  ]
}
