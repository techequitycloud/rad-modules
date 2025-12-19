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

# Cleanup dev storage bucket contents
resource "null_resource" "cleanup_dev_storage" {
  triggers = {
    bucket_name = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-dev"
  }

  provisioner "local-exec" {
    when       = destroy
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

# Cleanup dev backup bucket contents
resource "null_resource" "cleanup_dev_backup_storage" {
  triggers = {
    bucket_name = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-dev-backups"
  }

  provisioner "local-exec" {
    when       = destroy
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

resource "google_storage_bucket" "dev_storage" {
  name                        = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-dev"
  location                    = local.region
  force_destroy               = true
  uniform_bucket_level_access = false
  project                     = local.project.project_id

  depends_on = [null_resource.cleanup_dev_storage]

  lifecycle {
    prevent_destroy = false
  }
}

resource "google_storage_bucket_iam_member" "dev_storage_admin" {
  bucket = google_storage_bucket.dev_storage.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${local.cloud_run_sa_email}"
}

#########################################################################
# Backup Buckets
#########################################################################

resource "google_storage_bucket" "dev_backup_storage" {
  name                        = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-dev-backups"
  location                    = local.region
  force_destroy               = true
  uniform_bucket_level_access = false
  project                     = local.project.project_id

  depends_on = [null_resource.cleanup_dev_backup_storage]

  lifecycle {
    prevent_destroy = false
  }
}

#########################################################################
# Final Bucket Cleanup Verification
#########################################################################

resource "null_resource" "verify_bucket_cleanup" {
  triggers = {
    dev_bucket         = google_storage_bucket.dev_storage.name
    dev_backup_bucket  = google_storage_bucket.dev_backup_storage.name
  }

  provisioner "local-exec" {
    when       = destroy
    command    = <<-EOT
      echo "========================================="
      echo "Verifying bucket cleanup"
      echo "========================================="
      
      for bucket in ${self.triggers.dev_bucket} ${self.triggers.dev_backup_bucket}; do
        echo "Checking bucket: $bucket"
        gsutil ls gs://$bucket 2>/dev/null || echo "Bucket $bucket is empty or deleted"
      done
      
      echo "Bucket cleanup verification complete"
    EOT
    on_failure = continue
  }

  depends_on = [
    google_storage_bucket.dev_storage,
    google_storage_bucket.dev_backup_storage,
    google_storage_bucket_iam_member.dev_storage_admin,
    null_resource.cleanup_dev_storage,
    null_resource.cleanup_dev_backup_storage
  ]

  lifecycle {
    create_before_destroy = false
  }
}
