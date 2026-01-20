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
# Generate random passwords
#########################################################################

# Resource for creating a random password for database user
resource "random_password" "database_password" {
  length           = var.database_password_length
  special          = true
  override_special = "_%@"
}

#########################################################################
# Secret Manager resources for database password
#########################################################################

# Resource for creating a secret in Google Secret Manager to store the database password
resource "google_secret_manager_secret" "db_password" {
  count     = local.sql_server_exists ? 1 : 0
  project   = local.project.project_id
  secret_id = "${local.db_instance_name}-${local.database_name_prefix}-password-${local.tenant_id}-${local.random_id}"

  replication {
    auto {}
  }

  labels = local.common_labels
}

# Resource for adding a version of the secret with the actual database password
resource "google_secret_manager_secret_version" "db_password" {
  count       = local.sql_server_exists ? 1 : 0
  secret      = google_secret_manager_secret.db_password[0].id
  secret_data = random_password.database_password.result

  depends_on = [
    google_secret_manager_secret.db_password,
    random_password.database_password,
  ]
}

# Resource to introduce a delay after creating a secret version
resource "time_sleep" "db_password" {
  count = local.sql_server_exists ? 1 : 0

  depends_on = [
    google_secret_manager_secret_version.db_password
  ]

  create_duration = "${var.secret_propagation_delay}s"
}

# Data source for accessing the latest version of the secret when it's ready
data "google_secret_manager_secret_version" "db_password" {
  count    = local.sql_server_exists ? 1 : 0
  project  = local.project.project_id
  provider = google

  secret  = google_secret_manager_secret.db_password[0].id
  version = "latest"

  depends_on = [
    time_sleep.db_password,
    google_secret_manager_secret.db_password,
  ]
}

#########################################################################
# Additional secrets from user configuration
#########################################################################

# Create additional secrets specified in secret_environment_variables
resource "google_secret_manager_secret" "additional_secrets" {
  for_each = var.secret_environment_variables

  project   = local.project.project_id
  secret_id = "${local.resource_prefix}-${each.key}"

  replication {
    auto {}
  }

  labels = local.common_labels
}

#########################################################################
# GitHub Token Secret (for CI/CD)
#########################################################################

# Store GitHub token in Secret Manager
resource "google_secret_manager_secret" "github_token" {
  count     = local.enable_cicd_trigger && var.github_token != null ? 1 : 0
  project   = local.project.project_id
  secret_id = "github-token-${local.resource_prefix}"

  replication {
    auto {}
  }

  labels = local.common_labels
}

# Create secret version with the GitHub token
resource "google_secret_manager_secret_version" "github_token" {
  count       = local.enable_cicd_trigger && var.github_token != null ? 1 : 0
  secret      = google_secret_manager_secret.github_token[0].id
  secret_data = var.github_token

  depends_on = [
    google_secret_manager_secret.github_token
  ]
}

#########################################################################
# Local variables for secret references
#########################################################################

locals {
  # Database password secret reference
  db_password_secret_name = local.sql_server_exists ? google_secret_manager_secret.db_password[0].secret_id : ""

  # GitHub token secret reference
  github_token_secret_ref = local.enable_cicd_trigger && var.github_token != null ? google_secret_manager_secret.github_token[0].secret_id : null

  # Map of environment variable names to secret names
  secret_env_var_map = merge(
    # Database password
    local.sql_server_exists ? {
      DB_PASSWORD = local.db_password_secret_name
    } : {},
    # User-defined secret environment variables
    var.secret_environment_variables
  )
}
