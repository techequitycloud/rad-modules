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
  length  = 30
  special = false
}

# Resource for creating a random password for encryption key
resource "random_password" "encryption_key" {
  length  = 16
  special = false
}

#########################################################################
# Secret Manager resources
#########################################################################

resource "google_secret_manager_secret" "db_password" {
  count     = local.sql_server_exists ? 1 : 0
  project   = local.project.project_id
  secret_id = "${local.db_instance_name}-${var.application_database_name}-password-${var.tenant_deployment_id}-${local.random_id}"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  count       = local.sql_server_exists ? 1 : 0
  secret      = google_secret_manager_secret.db_password[0].id
  secret_data = random_password.db_password.result
}

# Resource to introduce a delay after creating a secret version
resource "time_sleep" "db_password" {
  depends_on = [
    google_secret_manager_secret_version.db_password
  ]

  create_duration = "30s"
}

# Data source for accessing the latest version of the secret when it's ready
data "google_secret_manager_secret_version" "db_password" {
  count   = local.sql_server_exists ? 1 : 0
  project = local.project.project_id

  secret  = google_secret_manager_secret.db_password[0].id
  version = "latest"

  depends_on = [
    time_sleep.db_password,
    google_secret_manager_secret.db_password,
  ]
}

resource "google_secret_manager_secret" "encryption_key" {
  project   = local.project.project_id
  secret_id = "n8n-encryption-key-${var.tenant_deployment_id}-${local.random_id}"

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
#########################################################################

resource "google_secret_manager_secret" "storage_access_key" {
  project   = local.project.project_id
  secret_id = "n8n-storage-access-key-${var.tenant_deployment_id}-${local.random_id}"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "storage_access_key" {
  secret      = google_secret_manager_secret.storage_access_key.id
  secret_data = local.n8n_hmac_access_id

  lifecycle {
    ignore_changes = [secret_data]
  }

  depends_on = [
    google_storage_hmac_key.n8n_key,
    null_resource.cleanup_hmac_keys
  ]
}

resource "google_secret_manager_secret" "storage_secret_key" {
  project   = local.project.project_id
  secret_id = "n8n-storage-secret-key-${var.tenant_deployment_id}-${local.random_id}"

  replication {
    auto {}
  }
}

#########################################################################
# HMAC Secret Version - Always create with appropriate value
#########################################################################

# Generate a placeholder secret for cases where HMAC key already exists
resource "random_password" "hmac_placeholder" {
  length  = 40
  special = false
}

# Always create secret version, but use placeholder if no real secret available
resource "google_secret_manager_secret_version" "storage_secret_key" {
  secret = google_secret_manager_secret.storage_secret_key.id
  
  # Use actual secret if available, otherwise use placeholder
  secret_data = length(google_storage_hmac_key.n8n_key) > 0 ? (
    google_storage_hmac_key.n8n_key[0].secret
  ) : random_password.hmac_placeholder.result

  lifecycle {
    # Ignore changes to prevent overwriting with placeholder on subsequent runs
    ignore_changes = [secret_data]
  }

  depends_on = [
    google_storage_hmac_key.n8n_key,
    null_resource.cleanup_hmac_keys
  ]
}

#########################################################################
# Warning output for placeholder usage
#########################################################################

resource "null_resource" "hmac_secret_warning" {
  # Only warn if we're using a placeholder (no new HMAC key created)
  count = length(google_storage_hmac_key.n8n_key) == 0 ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo ""
      echo "⚠️  =========================================="
      echo "⚠️  WARNING: Using Existing HMAC Key"
      echo "⚠️  =========================================="
      echo ""
      echo "A placeholder secret has been created because an existing"
      echo "HMAC key is being reused (secret not available)."
      echo ""
      echo "If n8n fails to access storage, you need to:"
      echo "  1. Retrieve the actual HMAC secret from previous deployment"
      echo "  2. Update the secret manually:"
      echo "     echo 'YOUR_ACTUAL_SECRET' | gcloud secrets versions add \\"
      echo "       n8n-storage-secret-key-${var.tenant_deployment_id}-${local.random_id} \\"
      echo "       --project=${local.project.project_id} --data-file=-"
      echo ""
      echo "OR delete the HMAC key and redeploy:"
      echo "  1. List keys: gcloud storage hmac list --project=${local.project.project_id}"
      echo "  2. Delete key: gcloud storage hmac delete KEY_ID --project=${local.project.project_id}"
      echo "  3. Run: terraform apply"
      echo ""
    EOT
  }

  triggers = {
    always_run = timestamp()
  }

  depends_on = [
    google_secret_manager_secret_version.storage_secret_key
  ]
}
