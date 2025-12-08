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

# Resource for creating a random password for database additional user
resource "random_password" "db_password" {
  for_each         = toset([for s in ["dev", "qa", "prod"] : s if (
    (s == "dev" && var.configure_development_environment) ||
    (s == "qa" && var.configure_nonproduction_environment) ||
    (s == "prod" && var.configure_production_environment)
  )])

  length           = 16          
  special          = true        
  override_special = "_%@"       
}

#########################################################################
# Secret Manager resources
#########################################################################

# Resource for creating a secret in Google Secret Manager to store the database password
resource "google_secret_manager_secret" "db_password" {
  for_each = toset([for s in ["dev", "qa", "prod"] : s if (
    (s == "dev" && var.configure_development_environment) ||
    (s == "qa" && var.configure_nonproduction_environment) ||
    (s == "prod" && var.configure_production_environment)
  )])

  project    = local.project.project_id  
  secret_id  = "${local.db_instance_name}-${var.application_database_name}${each.key}-password-${var.tenant_deployment_id}-${local.random_id}"

  replication {
    auto {}  
  }
}

# Resource for adding a version of the secret with the actual database password
resource "google_secret_manager_secret_version" "db_password" {
  for_each    = google_secret_manager_secret.db_password

  secret      = each.value.id
  secret_data = random_password.db_password[each.key].result

  depends_on = [
    google_secret_manager_secret.db_password,
    random_password.db_password,
  ]
}

# Resource to introduce a delay after creating a secret version
resource "time_sleep" "db_password" {
  for_each = google_secret_manager_secret_version.db_password

  depends_on = [
    google_secret_manager_secret_version.db_password
  ]

  create_duration = "30s"  
}

# Data source for accessing the latest version of the secret when it's ready
data "google_secret_manager_secret_version" "db_password" {
  for_each = google_secret_manager_secret.db_password

  project  = local.project.project_id
  provider = google  

  secret   = each.value.id
  version  = "latest"  

  depends_on = [
    time_sleep.db_password,
    google_secret_manager_secret.db_password,
  ]
}
