# Unified Backup Import Guide

The CloudRunApp module now provides a unified interface for importing database backups from either Google Drive or Google Cloud Storage. This document explains the new unified approach and how to migrate from the legacy variables.

## Overview

The unified backup import system provides:
- **Single configuration interface** for both Google Drive and GCS backups
- **Automatic source selection** based on your configuration
- **Backward compatibility** with legacy variables
- **Cleaner, more intuitive configuration**

---

## Unified Variables (Recommended)

### `enable_backup_import` (boolean)
- **Default**: `false`
- **Description**: Enable automatic import of database backup during deployment
- **Usage**: Set to `true` to enable backup import

### `backup_source` (string)
- **Default**: `"gcs"`
- **Valid Values**: `"gdrive"`, `"gcs"`
- **Description**: Backup source location
- **Recommendation**: Use `"gcs"` for production (better security, performance, and cost)

### `backup_uri` (string)
- **Default**: `""`
- **Description**: Location of the backup file
- **Format**:
  - **For GCS**: Full URI like `"gs://my-bucket/path/to/backup.sql"`
  - **For Google Drive**: File ID from URL `"https://drive.google.com/file/d/FILE_ID/view"`

### `backup_format` (string)
- **Default**: `"sql"`
- **Valid Values**: `"sql"`, `"tar"`, `"gz"`, `"tgz"`, `"tar.gz"`, `"zip"`
- **Description**: Backup file format
- **Note**: Google Drive supports `sql`, `tar`, `zip`. GCS additionally supports `gz`, `tgz`, `tar.gz`

---

## Usage Examples

### Example 1: GCS Backup Import (Recommended)

```hcl
module "app" {
  source = "./modules/CloudRunApp"

  # ... other configuration ...

  # Unified backup import from GCS
  enable_backup_import = true
  backup_source        = "gcs"
  backup_uri           = "gs://my-backups/production/database.sql.gz"
  backup_format        = "gz"

  database_type = "POSTGRES_15"
}
```

### Example 2: Google Drive Backup Import

```hcl
module "app" {
  source = "./modules/CloudRunApp"

  # ... other configuration ...

  # Unified backup import from Google Drive
  enable_backup_import = true
  backup_source        = "gdrive"
  backup_uri           = "1abc123def456ghi789jkl"  # File ID from Google Drive URL
  backup_format        = "sql"

  database_type = "MYSQL_8_0"
}
```

### Example 3: With Terraform Data Sources

```hcl
# Upload backup to GCS
resource "google_storage_bucket_object" "backup" {
  name   = "backups/latest.sql"
  bucket = "my-backups-bucket"
  source = "path/to/local/backup.sql"
}

module "app" {
  source = "./modules/CloudRunApp"

  # ... other configuration ...

  # Reference GCS backup
  enable_backup_import = true
  backup_source        = "gcs"
  backup_uri           = "gs://${google_storage_bucket_object.backup.bucket}/${google_storage_bucket_object.backup.name}"
  backup_format        = "sql"
}
```

### Example 4: Conditional Backup Import

```hcl
variable "import_backup" {
  description = "Whether to import a backup"
  type        = bool
  default     = false
}

variable "backup_location" {
  description = "Backup location (GCS URI or Google Drive file ID)"
  type        = string
  default     = ""
}

module "app" {
  source = "./modules/CloudRunApp"

  # ... other configuration ...

  enable_backup_import = var.import_backup
  backup_source        = startswith(var.backup_location, "gs://") ? "gcs" : "gdrive"
  backup_uri           = var.backup_location
  backup_format        = "sql"
}
```

---

## Legacy Variables (Deprecated)

The following variables are still supported for backward compatibility but are deprecated in favor of the unified variables:

### Google Drive Legacy Variables
- `enable_gdrive_backup_import` - Use `enable_backup_import` with `backup_source="gdrive"` instead
- `gdrive_backup_file_id` - Use `backup_uri` instead
- `gdrive_backup_format` - Use `backup_format` instead

### GCS Legacy Variables
- `enable_gcs_backup_import` - Use `enable_backup_import` with `backup_source="gcs"` instead
- `gcs_backup_uri` - Use `backup_uri` instead
- `gcs_backup_format` - Use `backup_format` instead

**Migration Path**: Legacy variables will continue to work, but new deployments should use the unified variables. The unified variables take precedence if both are specified.

---

## Migration Guide

### From Legacy Google Drive Variables

**Before (Legacy):**
```hcl
enable_gdrive_backup_import = true
gdrive_backup_file_id       = "1abc123def456ghi789jkl"
gdrive_backup_format        = "sql"
```

**After (Unified):**
```hcl
enable_backup_import = true
backup_source        = "gdrive"
backup_uri           = "1abc123def456ghi789jkl"
backup_format        = "sql"
```

### From Legacy GCS Variables

**Before (Legacy):**
```hcl
enable_gcs_backup_import = true
gcs_backup_uri           = "gs://my-backups/db.sql"
gcs_backup_format        = "sql"
```

**After (Unified):**
```hcl
enable_backup_import = true
backup_source        = "gcs"
backup_uri           = "gs://my-backups/db.sql"
backup_format        = "sql"
```

---

## Variable Precedence

When both unified and legacy variables are specified, the module uses the following precedence:

1. **Unified variables** (`enable_backup_import`, `backup_source`, `backup_uri`, `backup_format`) take precedence
2. **Legacy Google Drive variables** (`enable_gdrive_backup_import`, etc.) are used if unified variables are not set
3. **Legacy GCS variables** (`enable_gcs_backup_import`, etc.) are used if neither unified nor Google Drive variables are set

**Example:**
```hcl
# If both are specified, unified variables win
enable_backup_import      = true     # ✓ Used
backup_source             = "gcs"    # ✓ Used
backup_uri                = "gs://my-backups/new.sql"  # ✓ Used

enable_gdrive_backup_import = true   # ✗ Ignored
gdrive_backup_file_id       = "old"  # ✗ Ignored
```

---

## Backup Source Comparison

| Feature | Google Drive | Google Cloud Storage |
|---------|-------------|----------------------|
| **Security** | Requires file sharing | Native Cloud IAM integration |
| **Performance** | 5-10 MB/s (external API) | 100+ MB/s (in-region) |
| **Cost** | Free (Drive storage) | ~$0.02/GB/month, $0 egress (same region) |
| **Setup Complexity** | Get file ID, share file | Upload to GCS bucket |
| **IAM Integration** | Manual sharing | Standard Cloud IAM roles |
| **Versioning** | Drive versioning | GCS object versioning |
| **Lifecycle Management** | Manual | Automatic lifecycle rules |
| **Reliability** | 99.9% | 99.95% |
| **Best For** | Testing, one-time migrations | Production deployments |

**Recommendation**: Use GCS (`backup_source = "gcs"`) for production deployments.

---

## Complete Examples

### Production-Ready GCS Backup with Lifecycle

```hcl
# Create backup bucket with lifecycle rules
resource "google_storage_bucket" "backups" {
  name          = "my-app-backups-${var.project_id}"
  location      = "US"
  force_destroy = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30  # Delete backups older than 30 days
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age                = 7
      num_newer_versions = 3
    }
    action {
      type = "Delete"
    }
  }
}

# Upload backup
resource "google_storage_bucket_object" "backup" {
  name   = "backups/${formatdate("YYYY-MM-DD", timestamp())}.sql.gz"
  bucket = google_storage_bucket.backups.name
  source = var.backup_file_path
}

# Grant access to Cloud Run service account
resource "google_storage_bucket_iam_member" "backup_access" {
  bucket = google_storage_bucket.backups.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${module.app.cloud_run_service_account_email}"
}

# Deploy with backup import
module "app" {
  source = "./modules/CloudRunApp"

  existing_project_id  = var.project_id
  tenant_deployment_id = "prod"
  application_name     = "myapp"
  database_type        = "POSTGRES_15"

  # Unified backup import
  enable_backup_import = true
  backup_source        = "gcs"
  backup_uri           = "gs://${google_storage_bucket.backups.name}/${google_storage_bucket_object.backup.name}"
  backup_format        = "gz"

  depends_on = [google_storage_bucket_object.backup]
}
```

### Multi-Environment with Conditional Backup

```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "restore_from_backup" {
  description = "Whether to restore from backup"
  type        = bool
  default     = false
}

locals {
  # Only import backup in non-dev environments when explicitly requested
  should_import_backup = var.restore_from_backup && var.environment != "dev"

  # Use different backup sources per environment
  backup_uri = var.environment == "prod" ? "gs://prod-backups/latest.sql" : "gs://staging-backups/latest.sql"
}

module "app" {
  source = "./modules/CloudRunApp"

  existing_project_id  = var.project_id
  tenant_deployment_id = var.environment
  application_name     = "myapp"
  database_type        = "POSTGRES_15"

  # Conditional backup import
  enable_backup_import = local.should_import_backup
  backup_source        = "gcs"
  backup_uri           = local.backup_uri
  backup_format        = "sql"
}
```

---

## Validation Rules

The module validates backup configuration:

1. **Backup Source**: Must be `"gdrive"` or `"gcs"`
2. **Backup Format**: Must be valid for the selected source
   - GCS: `sql`, `tar`, `gz`, `tgz`, `tar.gz`, `zip`
   - Google Drive: `sql`, `tar`, `zip`
3. **Backup URI**: Must be non-empty when `enable_backup_import = true`
4. **Mutual Exclusivity**: Only one backup job runs (either GCS or Google Drive, not both)

---

## Troubleshooting

### Issue: Backup not importing

**Check:**
1. Verify `enable_backup_import = true`
2. Verify `backup_uri` is not empty
3. Check `backup_source` is correctly set
4. Review Cloud Run job logs for specific errors

### Issue: Wrong backup source being used

**Solution:**
- Unified variables take precedence
- If using legacy variables, ensure `enable_backup_import = false`
- Check variable precedence rules above

### Issue: GCS permission denied

**Solution:**
```hcl
resource "google_storage_bucket_iam_member" "backup_access" {
  bucket = "my-backup-bucket"
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${module.app.cloud_run_service_account_email}"
}
```

### Issue: Google Drive file not found

**Solution:**
1. Verify file ID is correct (from Google Drive URL)
2. Ensure file is shared with service account or is publicly accessible
3. Check file hasn't been deleted or moved

---

## Best Practices

1. **Use GCS for production** - Better security, performance, and reliability
2. **Use compressed formats** - `gz` or `tgz` for faster transfers
3. **Implement lifecycle rules** - Automatically delete old backups
4. **Version your backups** - Enable versioning on GCS buckets
5. **Test backup imports** - Validate in dev/staging before production
6. **Document backup locations** - Keep track of backup URIs in your IaC
7. **Use unified variables** - Migrate from legacy variables for cleaner config
8. **Encrypt backups** - Use customer-managed encryption keys (CMEK) for sensitive data

---

## FAQ

**Q: Can I import backups from both sources simultaneously?**
A: No, only one backup source can be used per deployment. If both are configured, unified variables take precedence.

**Q: Will legacy variables be removed?**
A: No, legacy variables will be maintained for backward compatibility. However, new deployments should use unified variables.

**Q: How do I know which backup source is being used?**
A: Check the Cloud Run job logs during deployment. It will show "Source: Google Drive" or "Source: Google Cloud Storage".

**Q: Can I switch from Google Drive to GCS after deployment?**
A: Yes, simply update the variables and run `terraform apply`. The appropriate backup job will be created.

**Q: Does this support SQL Server?**
A: Currently supports MySQL and PostgreSQL. SQL Server support is planned for future releases.

**Q: How large of a backup can I import?**
A: The job timeout is 30 minutes (1800 seconds). This typically supports backups up to 10-20GB depending on compression and network speed.

---

**Document Version:** 1.0
**Last Updated:** 2026-01-20
**Module Version:** CloudRunApp v2.2 (with unified backup import)
