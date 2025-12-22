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
# Generate a random ID for unique naming (moved to top for better dependency management)

resource "random_id" "note_id" {
  byte_length = 8 # Adjust the byte length as needed for uniqueness
}

# Local values for better resource reference management
locals {
  attestor_name = "${var.tenant_deployment_id}-attestor-${local.random_id}"
  note_name = "attestor-note-${var.tenant_deployment_id}-${local.random_id}"
  key_ring_name = "key-ring-${var.tenant_deployment_id}-${local.random_id}"
  crypto_key_name = "key-${var.tenant_deployment_id}-${local.random_id}"
}

# Creates a key ring to organize cryptographic keys.
resource "google_kms_key_ring" "keyring" {
  project  = local.project.project_id
  name     = local.key_ring_name
  location = "global"

  lifecycle {
    prevent_destroy = false
  }
}

resource "google_kms_key_ring_iam_binding" "keyring_owner" {
  key_ring_id = google_kms_key_ring.keyring.id
  role        = "roles/owner"

  members = [
    "serviceAccount:service-${local.project_number}@compute-system.iam.gserviceaccount.com",
  ]
}

# Creates a cryptographic key for signing attestations.
resource "google_kms_crypto_key" "crypto_key" {
  name     = local.crypto_key_name
  key_ring = google_kms_key_ring.keyring.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm = "RSA_SIGN_PKCS1_4096_SHA512"
  }

  depends_on = [google_kms_key_ring.keyring]
}

resource "google_kms_crypto_key_iam_binding" "crypto_key_owner" {
  crypto_key_id = google_kms_crypto_key.crypto_key.id
  role          = "roles/owner"

  members = [
    "serviceAccount:service-${local.project_number}@compute-system.iam.gserviceaccount.com",
  ]
}

# Retrieves the latest version of a specified CryptoKey.
data "google_kms_crypto_key_version" "version" {
  crypto_key = google_kms_crypto_key.crypto_key.id

  depends_on = [google_kms_crypto_key.crypto_key]
}

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
    google_kms_key_ring.keyring,
  ]
}

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
