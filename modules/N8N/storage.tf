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
# Bucket Cleanup Resources (executed on destroy)
#########################################################################

# Cleanup storage bucket contents
resource "null_resource" "cleanup_storage" {
  for_each = local.environments

  triggers = {
    bucket_name = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-${each.key}"
  }

  provisioner "local-exec" {
    when       = destroy
    interpreter = ["/bin/bash", "-c"]
    command    = <<-EOT
      echo "Emptying bucket: ${self.triggers.bucket_name}"
      gsutil -m rm -r gs://${self.triggers.bucket_name}/** 2>/dev/null || echo "Bucket already empty or does not exist"
    EOT
    on_failure = continue
  }

  lifecycle {
    create_before_destroy = false
  }
}

# Cleanup backup bucket contents
resource "null_resource" "cleanup_backup_storage" {
  for_each = local.environments

  triggers = {
    bucket_name = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-${each.key}-backups"
  }

  provisioner "local-exec" {
    when       = destroy
    interpreter = ["/bin/bash", "-c"]
    command    = <<-EOT
      echo "Emptying backup bucket: ${self.triggers.bucket_name}"
      gsutil -m rm -r gs://${self.triggers.bucket_name}/** 2>/dev/null || echo "Bucket already empty or does not exist"
    EOT
    on_failure = continue
  }

  lifecycle {
    create_before_destroy = false
  }
}

#########################################################################
# Cloud Storage Buckets for Application Data
#########################################################################

resource "google_storage_bucket" "storage" {
  for_each = local.environments

  name                        = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-${each.key}"
  location                    = local.region
  force_destroy               = true
  uniform_bucket_level_access = true  # Set to true for better security
  project                     = local.project.project_id

  depends_on = [null_resource.cleanup_storage]

  lifecycle {
    prevent_destroy = false
  }
}

resource "google_storage_bucket_iam_member" "storage_admin" {
  for_each = local.environments

  bucket = google_storage_bucket.storage[each.key].name
  role   = "roles/storage.objectAdmin" # Fixed Over-Permissive Storage Role
  member = "serviceAccount:${local.cloud_run_sa_email}"
}

#########################################################################
# Backup Buckets
#########################################################################

resource "google_storage_bucket" "backup_storage" {
  for_each = local.environments

  name                        = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-${each.key}-backups"
  location                    = local.region
  force_destroy               = true
  uniform_bucket_level_access = true
  project                     = local.project.project_id

  depends_on = [null_resource.cleanup_backup_storage]

  lifecycle {
    prevent_destroy = false
  }
}

#########################################################################
# Final Bucket Cleanup Verification
#########################################################################

resource "null_resource" "verify_bucket_cleanup" {
  triggers = {
    buckets        = join(" ", [for k, v in google_storage_bucket.storage : v.name])
    backup_buckets = join(" ", [for k, v in google_storage_bucket.backup_storage : v.name])
  }

  provisioner "local-exec" {
    when       = destroy
    interpreter = ["/bin/bash", "-c"]
    command    = <<-EOT
      echo "========================================="
      echo "Verifying bucket cleanup"
      echo "========================================="
      
      for bucket in ${self.triggers.buckets} ${self.triggers.backup_buckets}; do
        echo "Checking bucket: $bucket"
        gsutil ls gs://$bucket 2>/dev/null || echo "Bucket $bucket is empty or deleted"
      done
      
      echo "Bucket cleanup verification complete"
    EOT
    on_failure = continue
  }

  depends_on = [
    google_storage_bucket_iam_member.storage_admin,
    null_resource.cleanup_storage,
    null_resource.cleanup_backup_storage
  ]

  lifecycle {
    create_before_destroy = false
  }
}
