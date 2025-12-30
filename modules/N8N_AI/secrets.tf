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
resource "random_password" "encryption_key" {
  length           = 16
  special          = false
}

#########################################################################
# Secret Manager resources
#########################################################################

resource "google_secret_manager_secret" "db_password" {
  project    = local.project.project_id
  secret_id  = "n8n-db-password-${var.tenant_deployment_id}-${local.random_id}"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

resource "google_secret_manager_secret" "encryption_key" {
  project    = local.project.project_id
  secret_id  = "n8n-encryption-key-${var.tenant_deployment_id}-${local.random_id}"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "encryption_key" {
  secret      = google_secret_manager_secret.encryption_key.id
  secret_data = random_password.encryption_key.result
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

# --- Additional Data Sources for Scripts (DB Passwords) ---

data "google_secret_manager_secret_version" "db_password" {
  secret  = google_secret_manager_secret.db_password.id
  version = "latest"
  depends_on = [google_secret_manager_secret_version.db_password]
}
