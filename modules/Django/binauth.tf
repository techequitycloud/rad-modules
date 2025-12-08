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
# KMS Key Ring - Check for Existing or Create New
#########################################################################

# Try to get existing key ring
data "google_kms_key_ring" "existing_keyring" {
  count    = 1
  name     = local.key_ring_name
  location = "global"
  project  = local.project.project_id
}

# Create key ring only if it doesn't exist
resource "google_kms_key_ring" "keyring" {
  count    = length(data.google_kms_key_ring.existing_keyring) == 0 ? 1 : 0
  project  = local.project.project_id
  name     = local.key_ring_name
  location = "global"

  lifecycle {
    prevent_destroy = false
  }
}

# Reference the key ring (either existing or newly created)
locals {
  keyring_id = length(data.google_kms_key_ring.existing_keyring) > 0 ? data.google_kms_key_ring.existing_keyring[0].id : google_kms_key_ring.keyring[0].id
}

#########################################################################
# KMS Key Ring IAM
#########################################################################

resource "google_kms_key_ring_iam_binding" "keyring_owner" {
  key_ring_id = local.keyring_id
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
  key_ring = local.keyring_id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm = "RSA_SIGN_PKCS1_4096_SHA512"
  }

  lifecycle {
    prevent_destroy = false
    create_before_destroy = true
  }
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
