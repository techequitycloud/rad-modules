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
}

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
} 

#########################################################################
# Create private git repo
#########################################################################

# Provider configuration for GitHub
provider "github" {
  token  = var.application_git_token                                    
  owner  = var.application_git_organization                                      
}

# Resource for creating a private GitHub repository
resource "github_repository" "project_private_repo" {
  count      = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" ? 1 : 0
  name        = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"   
  description = "Project git repo managed by terraform"          
  visibility  = "private"                                      
}

resource "null_resource" "init_git_repo" {
  count      = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" ? 1 : 0

  triggers = {
    git_repo      = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    git_org       = var.application_git_organization
    github_token  = var.application_git_token
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = "chmod +x ./init_git_repo.sh && ./init_git_repo.sh && sleep 30"
    working_dir = "${path.module}/scripts/ci"
    environment = {
      GIT_REPO      = "${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
      GIT_ORG       = var.application_git_organization
      GITHUB_TOKEN  = var.application_git_token
      GIT_USERNAMES = "${join(",", var.application_git_usernames)}"
    }
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
  project  = local.project.project_id 
  location = local.region               
  name     = "${var.application_name}-github-connect-${var.tenant_deployment_id}-${local.random_id}" 

  github_config {
    app_installation_id = var.application_git_installation_id  

    authorizer_credential {
      oauth_token_secret_version = google_secret_manager_secret_version.github-token-secret[count.index].id  
    }
  }
  depends_on = [
    google_secret_manager_secret_iam_policy.policy,
  ]
}

# Resource for creating a Cloud Build repository which is linked to the GitHub repository
resource "google_cloudbuildv2_repository" "github_repository" {
  count    = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" ? 1 : 0
  project  = local.project.project_id  
  name     = "${var.application_name}-github-repo"  
  parent_connection = google_cloudbuildv2_connection.github_connection[count.index].id  
  remote_uri = "https://github.com/${var.application_git_organization}/${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}.git"  

  depends_on = [
    github_repository.project_private_repo,
  ]
}

#########################################################################
# Create dev, qa and prod triggers
#########################################################################

# Resource for creating a Google Cloud Build trigger for a repository
resource "google_cloudbuild_trigger" "dev_repo_trigger" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_development_environment && local.gke_cluster_exists && local.nfs_server_exists && var.create_cloud_storage && local.sql_server_exists ? 1 : 0
  project  = local.project.project_id
  name     = "${var.application_name}-dev-github-trigger-${var.tenant_deployment_id}-${local.random_id}"
  location = local.region
  disabled = true

  repository_event_config {
    repository = google_cloudbuildv2_repository.github_repository[count.index].id

    push {
      branch = "^dev$"
    }
  }

  filename = "cloudbuild.yaml"
  service_account = "projects/${local.project.project_id}/serviceAccounts/cloudbuild-sa@${local.project.project_id}.iam.gserviceaccount.com"

  depends_on = [
    github_repository_file.dev_autoscale_horizontal,
    github_repository_file.dev_backend_config,
    github_repository_file.dev_frontend_config,
    github_repository_file.dev_base_kustomization,
    github_repository_file.dev_service_cluster,
    github_repository_file.dev_ingress_app,
    github_repository_file.dev_overlay_kustomization,
    github_repository_file.dev_managedcert_app,
    github_repository_file.dev_deployment_app,
    github_repository_file.dev_cloudbuild,
    github_repository_file.dev_dockerfile,
    github_repository_file.dev_skaffold,
  ]
}

# Resource for creating a Google Cloud Build trigger for a repository
resource "google_cloudbuild_trigger" "qa_repo_trigger" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_nonproduction_environment && local.gke_cluster_exists && local.nfs_server_exists && var.create_cloud_storage && local.sql_server_exists  ? 1 : 0
  project  = local.project.project_id
  name     = "${var.application_name}-qa-github-trigger-${var.tenant_deployment_id}-${local.random_id}"
  location = local.region
  disabled = true

  repository_event_config {
    repository = google_cloudbuildv2_repository.github_repository[count.index].id
    push {
      branch = "^qa$"
    }
  }

  filename = "cloudbuild.yaml"
  service_account = "projects/${local.project.project_id}/serviceAccounts/cloudbuild-sa@${local.project.project_id}.iam.gserviceaccount.com"

  depends_on = [
    github_repository_file.qa_autoscale_horizontal,
    github_repository_file.qa_backend_config,
    github_repository_file.qa_frontend_config,
    github_repository_file.qa_base_kustomization,
    github_repository_file.qa_service_cluster,
    github_repository_file.qa_ingress_app,
    github_repository_file.qa_overlay_kustomization,
    github_repository_file.qa_managedcert_app,
    github_repository_file.qa_deployment_app,
    github_repository_file.qa_cloudbuild,
    github_repository_file.qa_dockerfile,
    github_repository_file.qa_skaffold,
  ]
}

# Resource for creating a Google Cloud Build trigger for a repository
resource "google_cloudbuild_trigger" "prod_repo_trigger" {
  count = var.configure_continuous_integration && var.application_git_token != null && var.application_git_token != "" && var.configure_production_environment && local.gke_cluster_exists && local.nfs_server_exists && var.create_cloud_storage && local.sql_server_exists  ? 1 : 0
  project  = local.project.project_id
  name     = "${var.application_name}-prod-github-trigger-${var.tenant_deployment_id}-${local.random_id}"
  location = local.region
  disabled = true

  repository_event_config {
    repository = google_cloudbuildv2_repository.github_repository[count.index].id
    push {
      branch = "^prod$"
    }
  }

  filename = "cloudbuild.yaml"
  service_account = "projects/${local.project.project_id}/serviceAccounts/cloudbuild-sa@${local.project.project_id}.iam.gserviceaccount.com"

  depends_on = [
    github_repository_file.prod_autoscale_horizontal,
    github_repository_file.prod_backend_config,
    github_repository_file.prod_frontend_config,
    github_repository_file.prod_base_kustomization,
    github_repository_file.prod_service_cluster,
    github_repository_file.prod_ingress_app,
    github_repository_file.prod_overlay_kustomization,
    github_repository_file.prod_managedcert_app,
    github_repository_file.prod_deployment_app,
    github_repository_file.prod_cloudbuild,
    github_repository_file.prod_dockerfile,
    github_repository_file.prod_skaffold,
  ]
}
