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

########################################################################################
# Use external data source to check service account existence
########################################################################################

data "external" "check_service_accounts" {
  program = ["bash", "-c", <<-EOT
    PROJECT_ID="${local.project.project_id}"
    if [ -n "${local.impersonation_service_account}" ]; then
      SA_ARG="--impersonate-service-account=${local.impersonation_service_account}"
    fi
    
    # Function to check if service account exists
    check_sa() {
      local sa_id="$1"
      if gcloud iam service-accounts describe "$sa_id@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID" $SA_ARG >/dev/null 2>&1; then
        echo "true"
      else
        echo "false"
      fi
    }
    
    # Check only service accounts used in Cloud Run deployment
    CLOUD_BUILD_SA_EXISTS=$(check_sa "cloudbuild-sa")
    CLOUD_RUN_SA_EXISTS=$(check_sa "cloudrun-sa")

    # Output JSON
    cat <<EOF
{
  "cloud_build_sa_exists": "$CLOUD_BUILD_SA_EXISTS",
  "cloud_run_sa_exists": "$CLOUD_RUN_SA_EXISTS"
}
EOF
  EOT
  ]
}

########################################################################################
# Local variables to check service account existence
########################################################################################

locals {
  # Parse the results from external data source (only Cloud Run deployment SAs)
  cloud_build_sa_exists  = data.external.check_service_accounts.result["cloud_build_sa_exists"] == "true"
  cloud_run_sa_exists    = data.external.check_service_accounts.result["cloud_run_sa_exists"] == "true"

  # Service account references (existing or newly created)
  cloud_build_sa_email  = "cloudbuild-sa@${local.project.project_id}.iam.gserviceaccount.com"
  cloud_run_sa_email    = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
}

########################################################################################
# Check existing HMAC keys for Cloud Run Service Account
########################################################################################

data "external" "check_hmac_keys" {
  program = ["bash", "-c", <<-EOT
    set -e
    
    PROJECT_ID="${local.project.project_id}"
    SA_EMAIL="${local.cloud_run_sa_email}"
    
    echo "🔍 Checking HMAC keys for $SA_EMAIL..." >&2
    
    # Get all HMAC keys for this service account
    KEYS=$(gcloud storage hmac list \
      --project="$PROJECT_ID" \
      --service-account="$SA_EMAIL" \
      --format="csv[no-heading](accessId,state)" 2>/dev/null || echo "")
    
    # Count total keys
    if [ -z "$KEYS" ]; then
      KEY_COUNT=0
      ACTIVE_KEY=""
      HAS_ACTIVE="false"
    else
      KEY_COUNT=$(echo "$KEYS" | wc -l)
      ACTIVE_KEY=$(echo "$KEYS" | grep "ACTIVE" | head -n 1 | cut -d, -f1 || echo "")
      if [ -n "$ACTIVE_KEY" ]; then
        HAS_ACTIVE="true"
      else
        HAS_ACTIVE="false"
      fi
    fi
    
    echo "Found $KEY_COUNT keys, active key: $ACTIVE_KEY" >&2
    
    # Output JSON
    cat <<EOF
{
  "key_count": "$KEY_COUNT",
  "active_key": "$ACTIVE_KEY",
  "has_active": "$HAS_ACTIVE"
}
EOF
  EOT
  ]
  
  depends_on = [
    data.external.check_service_accounts
  ]
}

locals {
  hmac_key_count  = tonumber(data.external.check_hmac_keys.result["key_count"])
  has_active_key  = data.external.check_hmac_keys.result["has_active"] == "true"
  active_key_id   = data.external.check_hmac_keys.result["active_key"]
  needs_cleanup   = local.hmac_key_count > 1
  needs_creation  = !local.has_active_key
}

########################################################################################
# Cleanup excessive HMAC keys (keep only 1 active key)
########################################################################################

resource "null_resource" "cleanup_hmac_keys" {
  count = local.needs_cleanup ? 1 : 0
  
  triggers = {
    # Run cleanup when key count exceeds 1
    key_count = local.hmac_key_count
    timestamp = timestamp()
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      PROJECT_ID="${local.project.project_id}"
      SA_EMAIL="${local.cloud_run_sa_email}"
      KEEP_KEY="${local.active_key_id}"
      
      echo "🗑️  Cleaning up excessive HMAC keys for $SA_EMAIL..."
      echo "Will keep key: $KEEP_KEY"
      
      # Get all HMAC keys
      KEYS=$(gcloud storage hmac list \
        --project="$PROJECT_ID" \
        --service-account="$SA_EMAIL" \
        --format="csv[no-heading](accessId,state)" 2>/dev/null || echo "")
      
      if [ -z "$KEYS" ]; then
        echo "✅ No keys to clean up"
        exit 0
      fi
      
      # Process each key
      echo "$KEYS" | while IFS=, read -r ACCESS_ID STATE; do
        if [ -z "$ACCESS_ID" ]; then
          continue
        fi
        
        # Skip the key we want to keep
        if [ "$ACCESS_ID" = "$KEEP_KEY" ]; then
          echo "⏭️  Skipping key to keep: $ACCESS_ID"
          continue
        fi
        
        echo "Processing key: $ACCESS_ID (state: $STATE)"
        
        if [ "$STATE" = "INACTIVE" ]; then
          echo "  Deleting inactive key..."
          gcloud storage hmac delete "$ACCESS_ID" \
            --project="$PROJECT_ID" --quiet 2>/dev/null || echo "  Failed to delete"
        elif [ "$STATE" = "ACTIVE" ]; then
          echo "  Deactivating active key..."
          gcloud storage hmac update "$ACCESS_ID" \
            --deactivate --project="$PROJECT_ID" --quiet 2>/dev/null || echo "  Failed to deactivate"
          
          sleep 2
          
          echo "  Deleting key..."
          gcloud storage hmac delete "$ACCESS_ID" \
            --project="$PROJECT_ID" --quiet 2>/dev/null || echo "  Failed to delete"
        fi
        
        echo "  ✅ Removed $ACCESS_ID"
      done
      
      echo "✅ HMAC key cleanup completed"
    EOT
    
    interpreter = ["bash", "-c"]
  }
}

########################################################################################
# Create HMAC Key for Cloud Run Service Account (only if needed)
########################################################################################

resource "google_storage_hmac_key" "n8n_key" {
  count = local.needs_creation ? 1 : 0
  
  service_account_email = local.cloud_run_sa_email
  project               = local.project.project_id
  
  depends_on = [
    null_resource.cleanup_hmac_keys
  ]
  
  lifecycle {
    # Prevent accidental deletion
    prevent_destroy = false
    
    # Don't recreate if service account changes
    create_before_destroy = false
    
    # Ignore changes to prevent unnecessary updates
    ignore_changes = [
      service_account_email
    ]
  }
}

########################################################################################
# Retrieve existing HMAC key details if not creating new one
########################################################################################

data "external" "get_existing_hmac_key" {
  count = local.has_active_key && !local.needs_creation ? 1 : 0
  
  program = ["bash", "-c", <<-EOT
    PROJECT_ID="${local.project.project_id}"
    ACCESS_ID="${local.active_key_id}"
    
    # Note: We can only get the access_id, not the secret (it's only shown once)
    # The secret must be retrieved from Secret Manager if it was stored there
    
    cat <<EOF
{
  "access_id": "$ACCESS_ID",
  "note": "Secret key must be retrieved from Secret Manager"
}
EOF
  EOT
  ]
  
  depends_on = [
    null_resource.cleanup_hmac_keys
  ]
}

########################################################################################
# Local variables for HMAC key outputs
########################################################################################

locals {
  # Use existing key if available, otherwise use newly created one
  n8n_hmac_access_id = local.needs_creation ? (
    length(google_storage_hmac_key.n8n_key) > 0 ? google_storage_hmac_key.n8n_key[0].access_id : ""
  ) : local.active_key_id
  
  # Secret is only available when creating new key
  n8n_hmac_secret = local.needs_creation && length(google_storage_hmac_key.n8n_key) > 0 ? (
    google_storage_hmac_key.n8n_key[0].secret
  ) : ""
  
  # Flag to indicate if secret needs to be retrieved from Secret Manager
  hmac_secret_in_secret_manager = !local.needs_creation
}
