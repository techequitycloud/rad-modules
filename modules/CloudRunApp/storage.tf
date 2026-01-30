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
# Cloud Storage Buckets
#########################################################################

# Create storage buckets based on configuration
resource "google_storage_bucket" "buckets" {
  for_each = local.storage_buckets

  name          = each.value.name
  location      = each.value.location
  project       = local.project.project_id
  storage_class = each.value.storage_class
  force_destroy = each.value.force_destroy
  labels        = local.common_labels

  # Versioning configuration
  dynamic "versioning" {
    for_each = each.value.versioning_enabled ? [1] : []
    content {
      enabled = true
    }
  }

  # Public access prevention
  public_access_prevention = each.value.public_access_prevention

  # Uniform bucket level access
  uniform_bucket_level_access = each.value.uniform_bucket_level_access

  # Soft delete policy - disable to allow bucket deletion without waiting for retention
  soft_delete_policy {
    retention_duration_seconds = each.value.soft_delete_retention_seconds
  }

  # Lifecycle rules
  dynamic "lifecycle_rule" {
    for_each = each.value.lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action.type
        storage_class = try(lifecycle_rule.value.action.storage_class, null)
      }
      condition {
        age                        = try(lifecycle_rule.value.condition.age, null)
        created_before             = try(lifecycle_rule.value.condition.created_before, null)
        with_state                 = try(lifecycle_rule.value.condition.with_state, null)
        matches_storage_class      = try(lifecycle_rule.value.condition.matches_storage_class, null)
        num_newer_versions         = try(lifecycle_rule.value.condition.num_newer_versions, null)
        days_since_custom_time     = try(lifecycle_rule.value.condition.days_since_custom_time, null)
        days_since_noncurrent_time = try(lifecycle_rule.value.condition.days_since_noncurrent_time, null)
      }
    }
  }

  # ✅ Add lifecycle to prevent hanging on destroy
  lifecycle {
    prevent_destroy = false
    create_before_destroy = false
 }

  # Add provisioner to wait before destruction to allow GCS Fuse mounts to release
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      echo "Emptying bucket ${self.name} before destruction..."
      # Try gcloud storage first (faster), fall back to gsutil
      if command -v gcloud >/dev/null 2>&1; then
        gcloud storage rm --recursive "gs://${self.name}/**" --quiet || true
      elif command -v gsutil >/dev/null 2>&1; then
        gsutil -m rm -r "gs://${self.name}/**" || true
      fi
      echo "Waiting 60s for GCSFuse mounts to release..."
      sleep 60
    EOT
  }
}
