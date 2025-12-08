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
# CICD resources
#########################################################################

# Resource for generating a random id.
resource "random_id" "cicd_random_id" {
  count       = (var.configure_development_environment || var.configure_nonproduction_environment || var.configure_production_environment) ? 1 : 0
  byte_length = 2
}

# Define local variables
locals {
  github_token      = var.application_git_token != "" ? var.application_git_token : null
  github_owner      = var.application_git_organization
  github_repo_name  = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
}

#########################################################################
# Create repository
#########################################################################

# Create a new private repository
resource "github_repository" "project_private_repo" {
  count       = (var.configure_development_environment || var.configure_nonproduction_environment || var.configure_production_environment) ? 1 : 0
  name        = local.github_repo_name
  description = "Private repository for ${var.application_name}"
  visibility  = "private"
  auto_init   = true
}

# Resource to manage collaborators on the repository
resource "github_repository_collaborator" "collaborators" {
  for_each   = toset(var.application_git_usernames)
  repository = github_repository.project_private_repo[0].name
  username   = each.value
  permission = "push"

  depends_on = [
    github_repository.project_private_repo
  ]
}

#########################################################################
# Configure repository
#########################################################################

# Resource to initialize the git repository locally and push to the remote repository
resource "null_resource" "init_git_repo" {
  count    = (var.configure_development_environment || var.configure_nonproduction_environment || var.configure_production_environment) ? 1 : 0
  # Trigger based on the hash of the git initialization script
  triggers = {
    script_hash = filesha256("${path.module}/scripts/ci/init_git_repo.sh")
    # always_run = "${timestamp()}" # Trigger to always run on apply
  }

  # Provisioner to execute a local script that initializes the git repo
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    working_dir = "${path.module}/scripts/ci"  # Updated to correct directory
    command = "bash init_git_repo.sh \"${local.project.project_id}\" \"${var.resource_creator_identity}\" \"${var.application_git_token}\" \"${var.application_git_organization}\" \"${local.github_repo_name}\""
  }

  # Dependencies to ensure resources are created in the correct order
  depends_on = [
    github_repository.project_private_repo,
    google_secret_manager_secret.db_password, # Implicit wait
  ]
}

# Resource to connect the repository to Google Cloud Build
resource "google_cloudbuildv2_connection" "default" {
  count    = (var.configure_development_environment || var.configure_nonproduction_environment || var.configure_production_environment) ? 1 : 0
  project  = local.project.project_id
  location = local.region
  name     = "conn${var.application_name}${var.tenant_deployment_id}${local.random_id}"

  github_config {
    app_installation_id = var.application_git_installation_id
    authorizer_credential {
      oauth_token_secret_version = google_secret_manager_secret_version.github_token_secret_version[0].id
    }
  }

  depends_on = [google_secret_manager_secret_version.github_token_secret_version]
}

# Resource to link the repository to the connection
resource "google_cloudbuildv2_repository" "default" {
  count             = (var.configure_development_environment || var.configure_nonproduction_environment || var.configure_production_environment) ? 1 : 0
  project           = local.project.project_id
  location          = local.region
  name              = local.github_repo_name
  parent_connection = google_cloudbuildv2_connection.default[0].name
  remote_uri        = github_repository.project_private_repo[0].html_url
}

#########################################################################
# Create secrets
#########################################################################

# Resource for creating a secret in Google Secret Manager to store the GitHub token
resource "google_secret_manager_secret" "github_token_secret" {
  count     = (var.configure_development_environment || var.configure_nonproduction_environment || var.configure_production_environment) ? 1 : 0
  project   = local.project.project_id
  secret_id = "github-token-secret-${var.tenant_deployment_id}-${local.random_id}"

  replication {
    auto {}
  }
}

# Resource for adding a version of the secret with the GitHub token
resource "google_secret_manager_secret_version" "github_token_secret_version" {
  count       = (var.configure_development_environment || var.configure_nonproduction_environment || var.configure_production_environment) ? 1 : 0
  secret      = google_secret_manager_secret.github_token_secret[0].id
  secret_data = local.github_token

  depends_on = [
    google_secret_manager_secret.github_token_secret
  ]
}

# Resource to grant the Secret Manager Secret Accessor role to the Cloud Build service account
resource "google_secret_manager_secret_iam_member" "secret_accessor" {
  count     = (var.configure_development_environment || var.configure_nonproduction_environment || var.configure_production_environment) ? 1 : 0
  project   = local.project.project_id
  secret_id = google_secret_manager_secret.github_token_secret[0].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:service-${local.project_number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"

  depends_on = [
    google_secret_manager_secret.github_token_secret
  ]
}
