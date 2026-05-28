/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# Generates a 4096-bit RSA keypair used for SSH access to the Linux target VMs.
# The public key is injected into each Linux VM via project metadata.
# The private key is stored as a .pem object in GCS so users can download it
# during the MCDCv6 credential setup step of the lab.
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "google_storage_bucket" "ssh_key_bucket" {
  count                       = var.create_ssh_key_bucket ? 1 : 0
  project                     = local.project.project_id
  name                        = local.ssh_key_bucket
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  depends_on = [google_project_service.enabled_services]
}

# Stores the PEM-encoded private key in the bucket. The lab guide instructs
# users to download this file and load it into MCDCv6 as an SSH credential.
resource "google_storage_bucket_object" "ssh_private_key" {
  count   = var.create_ssh_key_bucket ? 1 : 0
  name    = "lab-ssh-key.pem"
  bucket  = google_storage_bucket.ssh_key_bucket[0].name
  content = tls_private_key.ssh_key.private_key_pem
}

# The SSH key user that MCDCv6 uses to authenticate against the Linux VMs.
# This value is surfaced in outputs and referenced in the lab guide at docs/labs/Migration_Center.md.
locals {
  ssh_key_user = "migrationcenter"
  ssh_public_key_entry = "${local.ssh_key_user}:${tls_private_key.ssh_key.public_key_openssh}"
}
