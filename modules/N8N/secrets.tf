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

# Only create secret version if we have a new HMAC key with secret
resource "google_secret_manager_secret_version" "storage_secret_key" {
  count = local.n8n_hmac_secret != "" ? 1 : 0

  secret      = google_secret_manager_secret.storage_secret_key.id
  secret_data = local.n8n_hmac_secret

  lifecycle {
    ignore_changes = [secret_data]
  }

  depends_on = [
    google_storage_hmac_key.n8n_key,
    null_resource.cleanup_hmac_keys
  ]
}

#########################################################################
# Handle existing HMAC key scenario
#########################################################################

# If using existing HMAC key, try to preserve existing secret
data "google_secret_manager_secret_version" "existing_storage_secret" {
  count = local.hmac_secret_in_secret_manager ? 1 : 0

  project = local.project.project_id
  secret  = google_secret_manager_secret.storage_secret_key.id
  version = "latest"

  depends_on = [
    google_secret_manager_secret.storage_secret_key
  ]
}

# Create a placeholder secret version if using existing key and no secret exists
resource "null_resource" "storage_secret_placeholder" {
  count = local.hmac_secret_in_secret_manager ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      
      PROJECT_ID="${local.project.project_id}"
      SECRET_ID="n8n-storage-secret-key-${var.tenant_deployment_id}-${local.random_id}"
      
      # Check if secret version exists
      if ! gcloud secrets versions list "$SECRET_ID" --project="$PROJECT_ID" --limit=1 2>/dev/null | grep -q "ENABLED"; then
        echo "⚠️  WARNING: No secret version exists for HMAC secret key"
        echo "Creating placeholder - YOU MUST UPDATE THIS MANUALLY"
        
        # Create placeholder
        echo "PLACEHOLDER_UPDATE_MANUALLY" | gcloud secrets versions add "$SECRET_ID" \
          --project="$PROJECT_ID" \
          --data-file=- 2>/dev/null || true
        
        echo ""
        echo "=========================================="
        echo "⚠️  ACTION REQUIRED ⚠️"
        echo "=========================================="
        echo ""
        echo "The HMAC secret key is not available."
        echo "A placeholder has been created."
        echo ""
        echo "To fix this, you must:"
        echo "1. Delete the existing HMAC key:"
        echo "   gcloud storage hmac delete ${local.active_key_id} --project=$PROJECT_ID"
        echo ""
        echo "2. Run terraform apply again to create a new key with secret"
        echo ""
      else
        echo "✅ Secret version already exists, using existing value"
      fi
    EOT
    
    interpreter = ["bash", "-c"]
  }

  triggers = {
    secret_id = google_secret_manager_secret.storage_secret_key.id
  }

  depends_on = [
    google_secret_manager_secret.storage_secret_key
  ]
}
