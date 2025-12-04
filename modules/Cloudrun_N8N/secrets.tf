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
resource "random_password" "additional_user_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

# Resource for creating a random encryption key for n8n if not provided
resource "random_password" "n8n_encryption_key" {
  length           = 32
  special          = true
  override_special = "_%@!#"
}

# Local variable to determine which encryption key to use
locals {
  n8n_encryption_key_value = var.n8n_encryption_key != "" ? var.n8n_encryption_key : random_password.n8n_encryption_key.result
}

#########################################################################
# Secret Manager resources for n8n encryption key
#########################################################################

# Resource for creating a secret in Google Secret Manager to store the n8n encryption key
resource "google_secret_manager_secret" "n8n_encryption_key" {
  count      = 1
  project    = local.project.project_id
  secret_id  = "n8n-encryption-key-${var.tenant_deployment_id}-${local.random_id}"

  replication {
    auto {}
  }
}

# Resource for adding a version of the secret with the actual encryption key
resource "google_secret_manager_secret_version" "n8n_encryption_key" {
  count       = 1
  secret      = google_secret_manager_secret.n8n_encryption_key[0].id
  secret_data = local.n8n_encryption_key_value

  depends_on = [
    google_secret_manager_secret.n8n_encryption_key,
    random_password.n8n_encryption_key,
  ]
}

# Resource to introduce a delay after creating a secret version
resource "time_sleep" "n8n_encryption_key" {
  depends_on = [
    google_secret_manager_secret_version.n8n_encryption_key
  ]

  create_duration = "30s"
}

# Data source for accessing the latest version of the secret when it's ready
data "google_secret_manager_secret_version" "n8n_encryption_key" {
  count    = 1
  project  = local.project.project_id
  provider = google

  secret   = google_secret_manager_secret.n8n_encryption_key[0].id
  version  = "latest"

  depends_on = [
    time_sleep.n8n_encryption_key,
    google_secret_manager_secret.n8n_encryption_key,
  ]
}

#########################################################################
# Secret Manager resources for Dev environment
#########################################################################

# Resource for creating a secret in Google Secret Manager to store the database password
resource "google_secret_manager_secret" "dev_db_password" {
  count      = local.sql_server_exists ? 1 : 0  
  project    = local.project.project_id  
  secret_id  = "${local.db_instance_name}-${var.application_database_name}dev-password-${var.tenant_deployment_id}-${local.random_id}" 

  replication {
    auto {}  
  }
}

# Resource for adding a version of the secret with the actual database password
resource "google_secret_manager_secret_version" "dev_db_password" {
  count       = local.sql_server_exists ? 1 : 0 
  secret      = google_secret_manager_secret.dev_db_password[0].id
  secret_data = random_password.additional_user_password.result       

  depends_on = [
    google_secret_manager_secret.dev_db_password,
    random_password.additional_user_password,
  ]
}

# Resource to introduce a delay after creating a secret version
resource "time_sleep" "dev_db_password" {
  depends_on = [
    google_secret_manager_secret_version.dev_db_password
  ]

  create_duration = "30s"  
}

# Data source for accessing the latest version of the secret when it's ready
data "google_secret_manager_secret_version" "dev_db_password" {
  count    = local.sql_server_exists ? 1 : 0  
  project  = local.project.project_id
  provider = google  

  secret   = google_secret_manager_secret.dev_db_password[0].id
  version  = "latest"  

  depends_on = [
    time_sleep.dev_db_password,
    google_secret_manager_secret.dev_db_password,
  ]
}

#########################################################################
# Secret Manager resources for QA environment
#########################################################################

# Resource for creating a secret in Google Secret Manager to store the database password
resource "google_secret_manager_secret" "qa_db_password" {
  count      = local.sql_server_exists ? 1 : 0  
  project    = local.project.project_id  
  secret_id  = "${local.db_instance_name}-${var.application_database_name}qa-password-${var.tenant_deployment_id}-${local.random_id}"             

  replication {
    auto {}  
  }
}

# Resource for adding a version of the secret with the actual database password
resource "google_secret_manager_secret_version" "qa_db_password" {
  count       = local.sql_server_exists ? 1 : 0 
  secret      = google_secret_manager_secret.qa_db_password[0].id
  secret_data = random_password.additional_user_password.result     

  depends_on = [
    google_secret_manager_secret.qa_db_password,
    random_password.additional_user_password,
  ]
}

# Resource to introduce a delay after creating a secret version
resource "time_sleep" "qa_db_password" {
  depends_on = [
    google_secret_manager_secret_version.qa_db_password
  ]

  create_duration = "30s"  
}

# Data source for accessing the latest version of the secret when it's ready
data "google_secret_manager_secret_version" "qa_db_password" {
  count    = local.sql_server_exists ? 1 : 0  
  project  = local.project.project_id
  provider = google  

  secret   = google_secret_manager_secret.qa_db_password[0].id
  version  = "latest"  

  depends_on = [
    time_sleep.qa_db_password,
    google_secret_manager_secret.qa_db_password,
  ]
}

#########################################################################
# Secret Manager resources for Prod environment
#########################################################################

# Resource for creating a secret in Google Secret Manager to store the database password
resource "google_secret_manager_secret" "prod_db_password" {
  count      = local.sql_server_exists ? 1 : 0  
  project    = local.project.project_id  
  secret_id  = "${local.db_instance_name}-${var.application_database_name}prod-password-${var.tenant_deployment_id}-${local.random_id}"             

  replication {
    auto {}  
  }
}

# Resource for adding a version of the secret with the actual database password
resource "google_secret_manager_secret_version" "prod_db_password" {
  count       = local.sql_server_exists ? 1 : 0 
  secret      = google_secret_manager_secret.prod_db_password[0].id
  secret_data = random_password.additional_user_password.result       

  depends_on = [
    google_secret_manager_secret.prod_db_password,
    random_password.additional_user_password,
  ]
}

# Resource to introduce a delay after creating a secret version
resource "time_sleep" "prod_db_password" {
  depends_on = [
    google_secret_manager_secret_version.prod_db_password
  ]

  create_duration = "30s"  
}

# Data source for accessing the latest version of the secret when it's ready
data "google_secret_manager_secret_version" "prod_db_password" {
  count    = local.sql_server_exists ? 1 : 0  
  project  = local.project.project_id
  provider = google  

  secret   = google_secret_manager_secret.prod_db_password[0].id
  version  = "latest"  

  depends_on = [
    time_sleep.prod_db_password,
    google_secret_manager_secret.prod_db_password,
  ]
}
