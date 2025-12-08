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
# Random ID Generation
#########################################################################

# Generate a random ID for unique naming (moved to top for better dependency management)
resource "random_id" "note_id" {
  byte_length = 8 # Adjust the byte length as needed for uniqueness
}

# Add a suffix to ensure unique names if keys are scheduled for destruction
resource "random_id" "key_suffix" {
  byte_length = 4  # Increased from 2 to 4 for more uniqueness
  keepers = {
    # Force new ID on each apply to avoid conflicts with destroyed keys
    timestamp = "${timestamp()}"
  }
}

#########################################################################
# Local Values
#########################################################################

# Local values for better resource reference management
locals {
  attestor_name   = "${var.tenant_deployment_id}-attestor-${local.random_id}"
  note_name       = "attestor-note-${var.tenant_deployment_id}-${local.random_id}"
  key_ring_name   = "key-ring-${var.tenant_deployment_id}-${local.random_id}"
  # Add suffix to crypto key name to avoid conflicts with destroyed keys
  crypto_key_name = "key-${var.tenant_deployment_id}-${local.random_id}-${random_id.key_suffix.hex}"
}

#########################################################################
# Check and Restore Scheduled Keys (if any)
#########################################################################

resource "null_resource" "check_and_restore_keys" {
  triggers = {
    key_ring    = local.key_ring_name
    location    = "global"
    project     = local.project.project_id
    always_run  = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "========================================="
      echo "Checking for scheduled-for-destruction keys..."
      echo "========================================="
      
      # Check if key ring exists
      KEY_RING_EXISTS=$(gcloud kms keyrings describe "${self.triggers.key_ring}" \
        --location="${self.triggers.location}" \
        --project="${self.triggers.project}" 2>/dev/null && echo "true" || echo "false")
      
      if [ "$KEY_RING_EXISTS" = "true" ]; then
        echo "Key ring exists, checking for crypto keys..."
        
        # List all crypto keys in the key ring
        gcloud kms keys list \
          --keyring="${self.triggers.key_ring}" \
          --location="${self.triggers.location}" \
          --project="${self.triggers.project}" \
          --format="value(name)" 2>/dev/null | while read key; do
          
          if [ -n "$key" ]; then
            KEY_NAME=$(basename "$key")
            echo "Found key: $KEY_NAME"
            
            # Check for scheduled-for-destruction versions
            gcloud kms keys versions list \
              --key="$KEY_NAME" \
              --keyring="${self.triggers.key_ring}" \
              --location="${self.triggers.location}" \
              --project="${self.triggers.project}" \
              --filter="state:DESTROY_SCHEDULED" \
              --format="value(name)" 2>/dev/null | while read version; do
              
              if [ -n "$version" ]; then
                VERSION_NUM=$(basename "$version")
                echo "Found scheduled-for-destruction version: $VERSION_NUM"
                echo "Attempting to restore..."
                
                gcloud kms keys versions restore "$VERSION_NUM" \
                  --key="$KEY_NAME" \
                  --keyring="${self.triggers.key_ring}" \
                  --location="${self.triggers.location}" \
                  --project="${self.triggers.project}" \
                  --quiet 2>/dev/null && echo "✓ Restored version $VERSION_NUM" || echo "✗ Could not restore version $VERSION_NUM"
              fi
            done
          fi
        done
      else
        echo "Key ring does not exist yet, will be created"
      fi
      
      echo "========================================="
    EOT
    on_failure = continue
  }
}

#########################################################################
# KMS Key Ring - Always Create with Unique Name
#########################################################################

# Creates a key ring to organize cryptographic keys.
resource "google_kms_key_ring" "keyring" {
  project  = local.project.project_id
  name     = local.key_ring_name
  location = "global"

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [name]
  }

  depends_on = [
    null_resource.check_and_restore_keys
  ]
}

#########################################################################
# KMS Key Ring IAM
#########################################################################

resource "google_kms_key_ring_iam_binding" "keyring_owner" {
  key_ring_id = google_kms_key_ring.keyring.id
  role        = "roles/owner"

  members = [
    "serviceAccount:service-${local.project_number}@compute-system.iam.gserviceaccount.com",
  ]
}

#########################################################################
# KMS Crypto Key - Always Create New with Unique Name
#########################################################################

# Creates a cryptographic key for signing attestations
resource "google_kms_crypto_key" "crypto_key" {
  name     = local.crypto_key_name
  key_ring = google_kms_key_ring.keyring.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm = "RSA_SIGN_PKCS1_4096_SHA512"
  }

  lifecycle {
    prevent_destroy       = false
    create_before_destroy = true
    ignore_changes        = [name]
  }

  depends_on = [
    google_kms_key_ring.keyring,
    null_resource.check_and_restore_keys
  ]
}

#########################################################################
# Wait for Key Version to be Ready
#########################################################################

resource "null_resource" "wait_for_key_version" {
  triggers = {
    crypto_key = google_kms_crypto_key.crypto_key.id
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for crypto key version to be ready..."
      
      # Extract key details
      KEY_RING="${google_kms_key_ring.keyring.name}"
      CRYPTO_KEY="${google_kms_crypto_key.crypto_key.name}"
      LOCATION="global"
      PROJECT="${local.project.project_id}"
      
      # Wait for at least one enabled version
      MAX_ATTEMPTS=30
      ATTEMPT=0
      
      while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        ENABLED_VERSION=$(gcloud kms keys versions list \
          --key="$CRYPTO_KEY" \
          --keyring="$KEY_RING" \
          --location="$LOCATION" \
          --project="$PROJECT" \
          --filter="state:ENABLED" \
          --format="value(name)" \
          --limit=1 2>/dev/null)
        
        if [ -n "$ENABLED_VERSION" ]; then
          echo "✓ Found enabled key version: $ENABLED_VERSION"
          exit 0
        fi
        
        ATTEMPT=$((ATTEMPT + 1))
        echo "Waiting for key version to be enabled... (attempt $ATTEMPT/$MAX_ATTEMPTS)"
        sleep 2
      done
      
      echo "✗ No enabled key version found after $MAX_ATTEMPTS attempts"
      echo "This may indicate a problem with key creation"
      exit 1
    EOT
  }

  depends_on = [
    google_kms_crypto_key.crypto_key
  ]
}

#########################################################################
# KMS Crypto Key IAM
#########################################################################

resource "google_kms_crypto_key_iam_binding" "crypto_key_owner" {
  crypto_key_id = google_kms_crypto_key.crypto_key.id
  role          = "roles/owner"

  members = [
    "serviceAccount:service-${local.project_number}@compute-system.iam.gserviceaccount.com",
  ]

  depends_on = [
    null_resource.wait_for_key_version
  ]
}

#########################################################################
# KMS Crypto Key Version
#########################################################################

# Retrieves the latest version of a specified CryptoKey.
data "google_kms_crypto_key_version" "version" {
  crypto_key = google_kms_crypto_key.crypto_key.id

  depends_on = [
    google_kms_crypto_key.crypto_key,
    null_resource.wait_for_key_version
  ]
}

#########################################################################
# Container Analysis Note
#########################################################################

# Creates a note for storing metadata about the binary authorization attestor.
resource "google_container_analysis_note" "note" {
  project = local.project.project_id
  name    = local.note_name

  attestation_authority {
    hint {
      human_readable_name = "Attestor Note"
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

#########################################################################
# Binary Authorization Attestor
#########################################################################

# Represents an entity that can verify container images' attestations.
resource "google_binary_authorization_attestor" "attestor" {
  name    = local.attestor_name
  project = local.project.project_id

  # Link to a Container Analysis Note, which stores metadata about the attestor.
  attestation_authority_note {
    note_reference = google_container_analysis_note.note.name
    public_keys {
      id = data.google_kms_crypto_key_version.version.id
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.version.public_key[0].pem
        signature_algorithm = data.google_kms_crypto_key_version.version.public_key[0].algorithm
      }
    }
  }

  # Explicit dependencies to ensure proper creation order
  depends_on = [
    google_container_analysis_note.note,
    google_kms_crypto_key.crypto_key,
    data.google_kms_crypto_key_version.version,
    null_resource.wait_for_key_version
  ]
}

#########################################################################
# Binary Authorization Policy
#########################################################################

# Defines a policy to enforce container image attestations before deployment.
resource "google_binary_authorization_policy" "policy" {
  project = local.project.project_id

  # Whitelist specific container image patterns to bypass the attestation requirement.
  admission_whitelist_patterns {
    name_pattern = "gcr.io/google_containers/*"
  }

  default_admission_rule {
    evaluation_mode  = "ALWAYS_ALLOW"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
  }

  # Enable global policy evaluation mode.
  global_policy_evaluation_mode = "ENABLE"

  # Add explicit dependencies to ensure proper resource creation order
  depends_on = [
    google_binary_authorization_attestor.attestor,
    google_container_analysis_note.note,
    google_kms_crypto_key.crypto_key,
  ]
}

#########################################################################
# Binary Authorization Attestor IAM
#########################################################################

# Retrieves the IAM policy for a specified attestor.
data "google_binary_authorization_attestor_iam_policy" "policy" {
  project  = google_binary_authorization_attestor.attestor.project
  attestor = google_binary_authorization_attestor.attestor.name

  depends_on = [google_binary_authorization_attestor.attestor]
}

# Grants IAM roles to specified users or groups for the attestor.
resource "google_binary_authorization_attestor_iam_member" "member" {
  for_each = toset(concat(formatlist("user:%s", var.trusted_users)))
  project  = google_binary_authorization_attestor.attestor.project
  attestor = google_binary_authorization_attestor.attestor.name
  role     = "roles/viewer"
  member   = each.value

  depends_on = [google_binary_authorization_attestor.attestor]
}

#########################################################################
# Cleanup for KMS resources on destroy
#########################################################################

resource "null_resource" "cleanup_kms_resources" {
  triggers = {
    key_ring    = google_kms_key_ring.keyring.name
    crypto_key  = google_kms_crypto_key.crypto_key.name
    location    = "global"
    project     = local.project.project_id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "========================================="
      echo "KMS Cleanup Information"
      echo "========================================="
      echo "Note: KMS Key Rings cannot be deleted immediately."
      echo "They are scheduled for deletion after 24 hours."
      echo ""
      echo "Key Ring: ${self.triggers.key_ring}"
      echo "Crypto Key: ${self.triggers.crypto_key}"
      echo "Location: ${self.triggers.location}"
      echo "Project: ${self.triggers.project}"
      echo ""
      echo "Attempting to schedule crypto key version for destruction..."
      
      # List and schedule all crypto key versions for destruction
      gcloud kms keys versions list \
        --key="${self.triggers.crypto_key}" \
        --keyring="${self.triggers.key_ring}" \
        --location="${self.triggers.location}" \
        --project="${self.triggers.project}" \
        --format="value(name)" 2>/dev/null | while read version; do
        if [ -n "$version" ]; then
          echo "Scheduling version $version for destruction..."
          gcloud kms keys versions destroy "$version" \
            --key="${self.triggers.crypto_key}" \
            --keyring="${self.triggers.key_ring}" \
            --location="${self.triggers.location}" \
            --project="${self.triggers.project}" \
            --quiet 2>/dev/null || echo "Version already scheduled or destroyed"
        fi
      done
      
      echo ""
      echo "KMS resources have been scheduled for deletion."
      echo "They will be permanently removed after 24 hours."
      echo "========================================="
    EOT
    on_failure = continue
  }

  depends_on = [
    google_kms_crypto_key.crypto_key,
    google_kms_key_ring.keyring,
    google_binary_authorization_attestor.attestor
  ]

  lifecycle {
    create_before_destroy = false
  }
}
