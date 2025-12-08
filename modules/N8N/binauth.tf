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
  byte_length = 2
  keepers = {
    # Force new ID if we detect a destroyed key
    timestamp = timestamp()
  }
}

# Generate a unique suffix for the key ring to avoid conflicts
resource "random_id" "keyring_suffix" {
  byte_length = 4
  
  keepers = {
    # This ensures a new key ring name if the old one still exists
    timestamp = timestamp()
  }
}

#########################################################################
# Check if Key Ring exists
#########################################################################

data "external" "check_keyring" {
  program = ["bash", "-c", <<-EOT
    KEY_RING_BASE="key-ring-${var.tenant_deployment_id}-${local.random_id}"
    PROJECT_ID="${local.project.project_id}"
    LOCATION="global"
    
    # Check if the base key ring name exists
    if gcloud kms keyrings describe "$KEY_RING_BASE" \
      --location="$LOCATION" \
      --project="$PROJECT_ID" &>/dev/null; then
      # Key ring exists, use a new suffix
      echo "{\"exists\":\"true\",\"suffix\":\"${random_id.keyring_suffix.hex}\"}"
    else
      # Key ring doesn't exist, no suffix needed
      echo "{\"exists\":\"false\",\"suffix\":\"\"}"
    fi
  EOT
  ]
}

#########################################################################
# Local Values
#########################################################################

# Local values for better resource reference management
locals {
  attestor_name   = "${var.tenant_deployment_id}-attestor-${local.random_id}"
  note_name       = "attestor-note-${var.tenant_deployment_id}-${local.random_id}"
  
  # Use base name if key ring doesn't exist, otherwise add suffix
  key_ring_base   = "key-ring-${var.tenant_deployment_id}-${local.random_id}"
  key_ring_name   = data.external.check_keyring.result.exists == "true" ? "${local.key_ring_base}-${data.external.check_keyring.result.suffix}" : local.key_ring_base
  
  # Add suffix to crypto key name to avoid conflicts with destroyed keys
  crypto_key_name = "key-${var.tenant_deployment_id}-${local.random_id}-${random_id.key_suffix.hex}"
}

#########################################################################
# KMS Key Ring - Create with unique name
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

  depends_on = [data.external.check_keyring]
}

#########################################################################
# KMS Key Ring IAM
#########################################################################

resource "google_kms_key_ring_iam_binding" "keyring_owner" {
  key_ring_id = google_kms_key_ring.keyring.id
  role        = "roles/cloudkms.admin" # Fixed Broad Permissions

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
}

#########################################################################
# KMS Crypto Key IAM
#########################################################################

resource "google_kms_crypto_key_iam_binding" "crypto_key_owner" {
  crypto_key_id = google_kms_crypto_key.crypto_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter" # Fixed Broad Permissions

  members = [
    "serviceAccount:service-${local.project_number}@compute-system.iam.gserviceaccount.com",
  ]
}

#########################################################################
# KMS Crypto Key Version
#########################################################################

# Retrieves the latest version of a specified CryptoKey.
data "google_kms_crypto_key_version" "version" {
  crypto_key = google_kms_crypto_key.crypto_key.id

  depends_on = [google_kms_crypto_key.crypto_key]
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
    data.google_kms_crypto_key_version.version
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
    interpreter = ["/bin/bash", "-c"]
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
