# Tutorial: Storage (storage.tf)

## Overview
The `storage.tf` file manages **Google Cloud Storage (GCS)** buckets. These are used for "blob" storage: user uploads, media files, backups, and static assets.

## Standard Pattern
A simple `google_storage_bucket` resource, often with specific IAM bindings to allow the Cloud Run Service Account to write to it.

## Implementation Example

```hcl
resource "google_storage_bucket" "storage" {
  name          = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-media"
  location      = local.region
  force_destroy = var.enable_purge # Be careful!

  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "admin" {
  bucket = google_storage_bucket.storage.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${local.cloud_run_sa_email}"
}
```

## Best Practices & Recommendations

### 1. Unique Naming
**Recommendation**: Bucket names are **globally unique** across all of Google Cloud. Always include a random ID and project/tenant identifiers.
**Why**: `bucket "my-media"` will fail because someone else in the world already took it.

### 2. Permissions
**Recommendation**: Grant `roles/storage.objectAdmin` (full control) or `objectViewer` (read-only) to the Service Account on the _bucket itself_, not the project.
**Why**: Least Privilege.

### 3. Force Destroy
**Recommendation**: Tie `force_destroy` to a variable like `enable_purge`.
**Why**: If set to `false`, `terraform destroy` will fail if the bucket is not empty. This is good for production (prevents accidental data loss) but annoying for dev/testing.
