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

# Defines a policy to enforce container image attestations before deployment.
resource "google_binary_authorization_policy" "cr_policy" {
  project = local.project.project_id

  # Whitelist specific container image patterns to bypass the attestation requirement.
  admission_whitelist_patterns {
    name_pattern = "gcr.io/google_containers/*"
  }

  default_admission_rule {
    evaluation_mode   = "REQUIRE_ATTESTATION"
    enforcement_mode  = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [google_binary_authorization_attestor.cr_attestor.name]
  }

  # Enable global policy evaluation mode.
  global_policy_evaluation_mode = "ENABLE"
}

# Represents an entity that can verify container images' attestations.
resource "google_binary_authorization_attestor" "cr_attestor" {
  name = "${var.client_deployment_id}-cr-attestor"
  project = local.project.project_id

  # Link to a Container Analysis Note, which stores metadata about the attestor.
  attestation_authority_note {
    note_reference = google_container_analysis_note.cr_note.name
    public_keys {
      id = data.google_kms_crypto_key_version.version.id
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.version.public_key[0].pem
        signature_algorithm = data.google_kms_crypto_key_version.version.public_key[0].algorithm
      }
    }
  }

  # Ensure that required GCP services are enabled before creating this resource.
  depends_on = [
    google_project_service.enabled_services,
    time_sleep.wait_120_seconds
  ]
}

# Retrieves the latest version of a specified CryptoKey.
data "google_kms_crypto_key_version" "version" {
  crypto_key = google_kms_crypto_key.cr_crypto_key.id
}

resource "google_kms_crypto_key_iam_binding" "crypto_key_owner" {
  crypto_key_id = google_kms_crypto_key.cr_crypto_key.id
  role          = "roles/owner"

  members = [
    "serviceAccount:service-${local.project_number}@compute-system.iam.gserviceaccount.com",
  ]
}

# Creates a cryptographic key for signing attestations.
resource "google_kms_crypto_key" "cr_crypto_key" {
  name     = format("%s-%s", "cr-key", random_id.note_id.hex) # Use .hex for a hexadecimal string
  key_ring = google_kms_key_ring.cr_keyring.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm = "RSA_SIGN_PKCS1_4096_SHA512"
  }
}

resource "google_kms_key_ring_iam_binding" "cr_keyring_owner" {
  key_ring_id = google_kms_key_ring.cr_keyring.id
  role        = "roles/owner"

  members = [
    "serviceAccount:service-${local.project_number}@compute-system.iam.gserviceaccount.com",
  ]
}

# Creates a key ring to organize cryptographic keys.
resource "google_kms_key_ring" "cr_keyring" {
  project = local.project.project_id
  name     = format("%s-%s", "cr-key-ring", random_id.note_id.hex) # Use .hex for a hexadecimal string
  location = "global"

  lifecycle {
    prevent_destroy = false
  }

  # Ensure that required GCP services are enabled and wait before creating this resource.
  depends_on    = [
    # google_project_service.enabled_services,
    time_sleep.wait_120_seconds
  ]
}

# Generate a random ID for unique naming
resource "random_id" "note_id" {
  byte_length = 8 # Adjust the byte length as needed for uniqueness
}

# Creates a note for storing metadata about the binary authorization attestor.
resource "google_container_analysis_note" "cr_note" {
  project = local.project.project_id
  # name = "cr-attestor-note"
  name = format("%s-%s", "cr-attestor-note", random_id.note_id.hex) # Use .hex for a hexadecimal string
  attestation_authority {
    hint {
      human_readable_name = "Attestor Note"
    }
  }

  lifecycle {
    prevent_destroy = false
  }

  # Ensure that required GCP services are enabled and wait before creating this resource.
  depends_on    = [
    # google_project_service.enabled_services,
    time_sleep.wait_120_seconds
  ]
}

# Retrieves the IAM policy for a specified attestor.
data "google_binary_authorization_attestor_iam_policy" "policy" {
  project = google_binary_authorization_attestor.cr_attestor.project
  attestor = google_binary_authorization_attestor.cr_attestor.name

  # Ensure that required GCP services are enabled and wait before accessing this data.
  depends_on    = [
    # google_project_service.enabled_services,
    time_sleep.wait_120_seconds
  ]
}

# Grants IAM roles to specified users or groups for the attestor.
resource "google_binary_authorization_attestor_iam_member" "cr_member" {
  for_each = toset(concat(formatlist("user:%s", var.trusted_users)))
  project = google_binary_authorization_attestor.cr_attestor.project
  attestor = google_binary_authorization_attestor.cr_attestor.name
  role = "roles/viewer"
  member = each.value

  # Ensure that required GCP services are enabled before creating this resource.
  depends_on = [
    # google_project_service.enabled_services,
    time_sleep.wait_120_seconds
  ]
}
