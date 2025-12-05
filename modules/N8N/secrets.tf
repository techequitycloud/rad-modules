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
resource "random_password" "dev_db_password" {
  length           = 16
  special          = false
}

resource "random_password" "dev_encryption_key" {
  length           = 16
  special          = false
}

resource "random_password" "qa_db_password" {
  length           = 16
  special          = false
}

resource "random_password" "qa_encryption_key" {
  length           = 16
  special          = false
}

resource "random_password" "prod_db_password" {
  length           = 16
  special          = false
}

resource "random_password" "prod_encryption_key" {
  length           = 16
  special          = false
}

#########################################################################
# Secret Manager resources for Dev environment
#########################################################################

resource "google_secret_manager_secret" "dev_db_password" {
  count      = var.configure_development_environment && local.sql_server_exists ? 1 : 0
  project    = local.project.project_id
  secret_id  = "n8n-db-password-${var.tenant_deployment_id}-${local.random_id}-dev"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "dev_db_password" {
  count       = var.configure_development_environment && local.sql_server_exists ? 1 : 0
  secret      = google_secret_manager_secret.dev_db_password[0].id
  secret_data = random_password.dev_db_password.result
}

resource "google_secret_manager_secret" "dev_encryption_key" {
  count      = var.configure_development_environment && local.sql_server_exists ? 1 : 0
  project    = local.project.project_id
  secret_id  = "n8n-encryption-key-${var.tenant_deployment_id}-${local.random_id}-dev"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "dev_encryption_key" {
  count       = var.configure_development_environment && local.sql_server_exists ? 1 : 0
  secret      = google_secret_manager_secret.dev_encryption_key[0].id
  secret_data = random_password.dev_encryption_key.result
}


#########################################################################
# Secret Manager resources for QA environment
#########################################################################

resource "google_secret_manager_secret" "qa_db_password" {
  count      = var.configure_nonproduction_environment && local.sql_server_exists ? 1 : 0
  project    = local.project.project_id
  secret_id  = "n8n-db-password-${var.tenant_deployment_id}-${local.random_id}-qa"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "qa_db_password" {
  count       = var.configure_nonproduction_environment && local.sql_server_exists ? 1 : 0
  secret      = google_secret_manager_secret.qa_db_password[0].id
  secret_data = random_password.qa_db_password.result
}

resource "google_secret_manager_secret" "qa_encryption_key" {
  count      = var.configure_nonproduction_environment && local.sql_server_exists ? 1 : 0
  project    = local.project.project_id
  secret_id  = "n8n-encryption-key-${var.tenant_deployment_id}-${local.random_id}-qa"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "qa_encryption_key" {
  count       = var.configure_nonproduction_environment && local.sql_server_exists ? 1 : 0
  secret      = google_secret_manager_secret.qa_encryption_key[0].id
  secret_data = random_password.qa_encryption_key.result
}

#########################################################################
# Secret Manager resources for Prod environment
#########################################################################

resource "google_secret_manager_secret" "prod_db_password" {
  count      = var.configure_production_environment && local.sql_server_exists ? 1 : 0
  project    = local.project.project_id
  secret_id  = "n8n-db-password-${var.tenant_deployment_id}-${local.random_id}-prod"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "prod_db_password" {
  count       = var.configure_production_environment && local.sql_server_exists ? 1 : 0
  secret      = google_secret_manager_secret.prod_db_password[0].id
  secret_data = random_password.prod_db_password.result
}

resource "google_secret_manager_secret" "prod_encryption_key" {
  count      = var.configure_production_environment && local.sql_server_exists ? 1 : 0
  project    = local.project.project_id
  secret_id  = "n8n-encryption-key-${var.tenant_deployment_id}-${local.random_id}-prod"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "prod_encryption_key" {
  count       = var.configure_production_environment && local.sql_server_exists ? 1 : 0
  secret      = google_secret_manager_secret.prod_encryption_key[0].id
  secret_data = random_password.prod_encryption_key.result
}

#########################################################################
# Secret Manager resources for Object Storage HMAC Key
# These are shared across environments because the SA is shared.
# If environments need isolation, multiple SAs or keys should be used,
# but for this module scope, we use the single SA's key.
#########################################################################

resource "google_secret_manager_secret" "storage_access_key" {
  project    = local.project.project_id
  secret_id  = "n8n-storage-access-key-${var.tenant_deployment_id}-${local.random_id}"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "storage_access_key" {
  secret      = google_secret_manager_secret.storage_access_key.id
  secret_data = google_storage_hmac_key.n8n_key.access_id
}

resource "google_secret_manager_secret" "storage_secret_key" {
  project    = local.project.project_id
  secret_id  = "n8n-storage-secret-key-${var.tenant_deployment_id}-${local.random_id}"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "storage_secret_key" {
  secret      = google_secret_manager_secret.storage_secret_key.id
  secret_data = google_storage_hmac_key.n8n_key.secret
}
