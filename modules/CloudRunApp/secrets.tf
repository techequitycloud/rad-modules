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
  length           = local.database_password_length
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
  secret_id = "${local.db_instance_name}-${local.application_database_name}-password-${local.tenant_id}-${local.random_id}"

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

  create_duration = "${local.secret_propagation_delay}s"
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
# GitHub Token Secret (for CI/CD)
#########################################################################

# Data source to access existing GitHub token secret
# ✅ Fixed: Added condition to check if secret_id is not null/empty
data "google_secret_manager_secret" "github_token" {
  count     = local.enable_cicd_trigger && local.github_token_secret != null && local.github_token_secret != "" ? 1 : 0
  project   = local.project.project_id
  secret_id = local.github_token_secret
}
