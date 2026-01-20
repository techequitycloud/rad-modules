# WebApp Module Compatibility Enhancements

This document describes the compatibility enhancements added to the WebApp module to support deployment patterns from application-specific modules (Cyclos, Django, Moodle, N8N, N8N_AI, Odoo, OpenEMR, WordPress).

## Overview

Three major compatibility features have been implemented:

1. **Cloud SQL Instance Volume Support** - Enables Unix socket connections to Cloud SQL
2. **Google Drive Backup Import** - Automated database backup import from Google Drive
3. **PostgreSQL Extensions Installation** - Automated installation of PostgreSQL extensions

## Feature 1: Cloud SQL Instance Volume Support

### Description
Adds support for mounting Cloud SQL instances as volumes, enabling Unix socket connections instead of TCP/IP. This is required by applications like N8N and WordPress that prefer Unix socket connections for better performance and security.

### Configuration Variables

#### `enable_cloudsql_volume` (boolean)
- **Default**: `false`
- **Description**: Enable Cloud SQL instance volume for Unix socket connections
- **Usage**: Set to `true` to mount the Cloud SQL instance as a volume
- **Group**: Storage & Volume Configuration (Group 7)

#### `cloudsql_volume_mount_path` (string)
- **Default**: `"/cloudsql"`
- **Description**: Mount path for Cloud SQL Unix socket
- **Usage**: Customize the mount path for the Cloud SQL Unix socket
- **Group**: Storage & Volume Configuration (Group 7)

### Implementation Details

**Files Modified:**
- `modules/WebApp/variables.tf` - Added volume configuration variables
- `modules/WebApp/service.tf` - Added Cloud SQL volume mount and volume definition

**Technical Implementation:**
```hcl
# Volume mount
dynamic "volume_mounts" {
  for_each = var.enable_cloudsql_volume && local.sql_server_exists ? [1] : []
  content {
    name       = "cloudsql"
    mount_path = var.cloudsql_volume_mount_path
  }
}

# Volume definition
dynamic "volumes" {
  for_each = var.enable_cloudsql_volume && local.sql_server_exists ? [1] : []
  content {
    name = "cloudsql"
    cloud_sql_instance {
      instances = ["${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}"]
    }
  }
}
```

### Usage Example

**For N8N deployment with Unix socket:**
```hcl
module "n8n_webapp" {
  source = "./modules/WebApp"

  # ... other configuration ...

  enable_cloudsql_volume     = true
  cloudsql_volume_mount_path = "/cloudsql"

  environment_variables = {
    DB_TYPE           = "postgresdb"
    DB_POSTGRESDB_HOST = "/cloudsql/${var.project_id}:${var.region}:${var.db_instance}"
  }
}
```

**For WordPress deployment:**
```hcl
module "wordpress_webapp" {
  source = "./modules/WebApp"

  # ... other configuration ...

  enable_cloudsql_volume = true

  environment_variables = {
    WORDPRESS_DB_HOST = ":/cloudsql/${var.project_id}:${var.region}:${var.db_instance}"
  }
}
```

### Benefits
- **Performance**: Unix sockets are faster than TCP/IP for local connections
- **Security**: No network exposure of database connections
- **Compatibility**: Enables deployment of N8N, WordPress, and other apps that prefer Unix sockets

---

## Feature 2: Google Drive Backup Import

### Description
Automatically downloads and imports database backups from Google Drive during deployment. This is required by Cyclos, Odoo, and OpenEMR modules that use Google Drive for backup storage.

### Configuration Variables

#### `enable_gdrive_backup_import` (boolean)
- **Default**: `false`
- **Description**: Enable automatic import of database backup from Google Drive
- **Usage**: Set to `true` to enable backup import during deployment
- **Group**: Database Extensions & Backup Configuration (Group 13)

#### `gdrive_backup_file_id` (string)
- **Default**: `""`
- **Description**: Google Drive file ID of the backup to import
- **Usage**: Extract from Google Drive URL: `https://drive.google.com/file/d/FILE_ID/view`
- **Group**: Database Extensions & Backup Configuration (Group 13)

#### `gdrive_backup_format` (string)
- **Default**: `"sql"`
- **Description**: Backup file format
- **Valid Values**: `sql`, `tar`, `zip`
- **Group**: Database Extensions & Backup Configuration (Group 13)

### Implementation Details

**Files Created:**
- `modules/WebApp/scripts/import-gdrive-backup.sh` - Backup import script

**Files Modified:**
- `modules/WebApp/variables.tf` - Added backup configuration variables
- `modules/WebApp/jobs.tf` - Added Google Drive backup import job

**Script Features:**
- Downloads backups from Google Drive using `gdown`
- Supports SQL dumps, tar archives, and zip files
- Supports MySQL and PostgreSQL databases
- Automatic extraction and import of compressed backups
- Comprehensive error handling and logging

### Usage Example

**For Cyclos deployment with backup:**
```hcl
module "cyclos_webapp" {
  source = "./modules/WebApp"

  # ... other configuration ...

  enable_gdrive_backup_import = true
  gdrive_backup_file_id       = "1abc123def456ghi789jkl"  # From Google Drive URL
  gdrive_backup_format        = "sql"

  database_type = "POSTGRES_15"
}
```

**For Odoo deployment with tar backup:**
```hcl
module "odoo_webapp" {
  source = "./modules/WebApp"

  # ... other configuration ...

  enable_gdrive_backup_import = true
  gdrive_backup_file_id       = "1xyz987wvu654tsr321qpo"
  gdrive_backup_format        = "tar"

  database_type = "POSTGRES_15"
}
```

### Job Execution Details

**Job Name:** `${resource_prefix}-gdrive-backup`
**Container Image:** `debian:12-slim`
**Timeout:** 30 minutes (1800 seconds)
**Resources:** 2 CPU, 2Gi memory
**Execution:** Runs during `terraform apply` after PostgreSQL extensions (if enabled)

**Environment Variables Passed:**
- `GDRIVE_FILE_ID` - Google Drive file ID
- `BACKUP_FORMAT` - Backup format (sql/tar/zip)
- `DB_TYPE` - Database type (MYSQL/POSTGRES)
- `DB_HOST` - Database host (internal IP)
- `DB_PORT` - Database port
- `DB_NAME` - Database name
- `DB_USER` - Database username
- `DB_PASSWORD` - Database password (from Secret Manager)
- `ROOT_PASSWORD` - Database root password (from Secret Manager)

### Benefits
- **Automated Restoration**: No manual backup import steps
- **Flexible Formats**: Supports multiple backup formats
- **Multi-Database**: Works with MySQL and PostgreSQL
- **Large Backups**: 30-minute timeout for large databases

---

## Feature 3: PostgreSQL Extensions Installation

### Description
Automatically installs PostgreSQL extensions during deployment. This is required by Cyclos and other applications that depend on PostgreSQL extensions like PostGIS, cube, earthdistance, etc.

### Configuration Variables

#### `enable_postgres_extensions` (boolean)
- **Default**: `false`
- **Description**: Enable automatic installation of PostgreSQL extensions
- **Usage**: Set to `true` to install extensions during deployment
- **Group**: Database Extensions & Backup Configuration (Group 13)
- **Note**: Only applicable when using PostgreSQL databases

#### `postgres_extensions` (list of strings)
- **Default**: `[]`
- **Description**: List of PostgreSQL extensions to install
- **Common Extensions**:
  - `postgis` - Geographic objects support
  - `cube` - Multidimensional cube data type
  - `earthdistance` - Earth surface distance calculations
  - `unaccent` - Text search without accents
  - `pg_stat_statements` - SQL execution statistics
  - `uuid-ossp` - UUID generation
  - `pg_trgm` - Text similarity using trigrams
  - `hstore` - Key-value pair storage
  - `citext` - Case-insensitive text
- **Validation**: Extension names must start with a letter/underscore and contain only lowercase letters, numbers, underscores, and hyphens
- **Group**: Database Extensions & Backup Configuration (Group 13)

### Implementation Details

**Files Created:**
- `modules/WebApp/scripts/install-postgres-extensions.sh` - Extension installation script

**Files Modified:**
- `modules/WebApp/variables.tf` - Added extension configuration variables
- `modules/WebApp/jobs.tf` - Added PostgreSQL extensions installation job

**Script Features:**
- Installs PostgreSQL client automatically
- Installs extensions using database root credentials
- Continues on failure (non-blocking for optional extensions)
- Verifies installed extensions using `\dx` command
- Comprehensive logging

### Usage Example

**For Cyclos deployment:**
```hcl
module "cyclos_webapp" {
  source = "./modules/WebApp"

  # ... other configuration ...

  database_type = "POSTGRES_15"

  enable_postgres_extensions = true
  postgres_extensions = [
    "cube",
    "earthdistance",
    "postgis",
    "unaccent"
  ]
}
```

**For custom GIS application:**
```hcl
module "gis_app" {
  source = "./modules/WebApp"

  # ... other configuration ...

  database_type = "POSTGRES_15"

  enable_postgres_extensions = true
  postgres_extensions = [
    "postgis",
    "postgis_topology",
    "postgis_raster",
    "hstore"
  ]
}
```

### Job Execution Details

**Job Name:** `${resource_prefix}-postgres-ext`
**Container Image:** `debian:12-slim`
**Timeout:** 5 minutes (300 seconds)
**Resources:** 1 CPU, 512Mi memory
**Execution:** Runs during `terraform apply` before backup import (if enabled)

**Environment Variables Passed:**
- `POSTGRES_EXTENSIONS` - Comma-separated list of extensions
- `DB_HOST` - Database host (internal IP)
- `DB_PORT` - Database port
- `DB_NAME` - Database name
- `ROOT_USER` - Database root user (typically 'postgres')
- `ROOT_PASSWORD` - Database root password (from Secret Manager)

### Benefits
- **Automated Setup**: No manual extension installation
- **Flexible**: Install any number of extensions
- **Safe**: Non-blocking on extension failures
- **Verified**: Lists installed extensions after completion

---

## Deployment Order

When multiple features are enabled, jobs execute in this order:

1. **NFS Setup Job** (if NFS enabled)
2. **PostgreSQL Extensions Job** (if enabled)
3. **Google Drive Backup Import Job** (if enabled)
4. **Custom Initialization Jobs** (if configured)
5. **Cloud Run Service Deployment**

This ensures:
- Extensions are installed before data import
- Data is imported before application startup
- Application has all dependencies ready

---

## Complete Usage Example

Here's a complete example using all three features together:

```hcl
module "cyclos_on_webapp" {
  source = "./modules/WebApp"

  # Basic Configuration
  existing_project_id  = "my-gcp-project"
  tenant_deployment_id = "prod"
  deployment_region    = "us-central1"
  application_name     = "cyclos"
  application_version  = "4.16.3"

  # Container Configuration
  container_image_source = "prebuilt"
  container_image        = "cyclos/cyclos:4.16.3"
  container_port         = 8080

  # Database Configuration
  database_type              = "POSTGRES_15"
  application_database_name  = "cyclos"
  application_database_user  = "cyclos"

  # FEATURE 1: Cloud SQL Unix Socket
  enable_cloudsql_volume     = true
  cloudsql_volume_mount_path = "/cloudsql"

  # FEATURE 2: PostgreSQL Extensions
  enable_postgres_extensions = true
  postgres_extensions = [
    "cube",
    "earthdistance",
    "postgis",
    "unaccent"
  ]

  # FEATURE 3: Google Drive Backup Import
  enable_gdrive_backup_import = true
  gdrive_backup_file_id       = "1abc123def456ghi789jkl"
  gdrive_backup_format        = "sql"

  # Environment Variables
  environment_variables = {
    CYCLOS_DB_HOST = "/cloudsql/my-gcp-project:us-central1:cyclos-db"
  }

  # Resource Limits
  container_resources = {
    cpu_limit    = "2000m"
    memory_limit = "4Gi"
  }

  # Scaling
  min_instance_count = 1
  max_instance_count = 3
}
```

---

## Compatibility Matrix

| Module | Cloud SQL Volume | PostgreSQL Extensions | GDrive Backup | Notes |
|--------|-----------------|----------------------|---------------|-------|
| **Cyclos** | ✅ Optional | ✅ Required | ✅ Optional | Needs cube, earthdistance, postgis, unaccent |
| **Django** | ✅ Optional | ⚠️ App-specific | ❌ Not needed | May need specific extensions |
| **Moodle** | ✅ Optional | ⚠️ App-specific | ❌ Not needed | Check Moodle requirements |
| **N8N** | ✅ Recommended | ❌ Not needed | ❌ Not needed | Prefers Unix socket |
| **N8N_AI** | ⚠️ Multi-service | ❌ Not needed | ❌ Not needed | Requires architectural changes |
| **Odoo** | ✅ Optional | ⚠️ App-specific | ✅ Optional | May need specific extensions |
| **OpenEMR** | ✅ Optional | ❌ Uses MySQL | ✅ Optional | MySQL database |
| **WordPress** | ✅ Recommended | ❌ Uses MySQL | ❌ Not needed | MySQL database, prefers Unix socket |

**Legend:**
- ✅ Supported and recommended
- ⚠️ Supported but application-specific
- ❌ Not applicable or not needed

---

## Migration Guide

### Migrating from Cyclos Module

**Before:**
```hcl
module "cyclos" {
  source = "./modules/Cyclos"
  # ... configuration ...
}
```

**After:**
```hcl
module "cyclos" {
  source = "./modules/WebApp"

  # Add PostgreSQL extensions
  enable_postgres_extensions = true
  postgres_extensions = ["cube", "earthdistance", "postgis", "unaccent"]

  # Add backup import if needed
  enable_gdrive_backup_import = true
  gdrive_backup_file_id       = "your-file-id"

  # ... other configuration ...
}
```

### Migrating from N8N Module

**Before:**
```hcl
module "n8n" {
  source = "./modules/N8N"
  # ... configuration ...
}
```

**After:**
```hcl
module "n8n" {
  source = "./modules/WebApp"

  # Enable Cloud SQL Unix socket
  enable_cloudsql_volume = true

  environment_variables = {
    DB_TYPE           = "postgresdb"
    DB_POSTGRESDB_HOST = "/cloudsql/${var.project}:${var.region}:${var.db_instance}"
  }

  # ... other configuration ...
}
```

### Migrating from WordPress Module

**Before:**
```hcl
module "wordpress" {
  source = "./modules/Wordpress"
  # ... configuration ...
}
```

**After:**
```hcl
module "wordpress" {
  source = "./modules/WebApp"

  # Enable Cloud SQL Unix socket
  enable_cloudsql_volume = true

  # Configure for MySQL
  database_type = "MYSQL_8_0"

  environment_variables = {
    WORDPRESS_DB_HOST = ":/cloudsql/${var.project}:${var.region}:${var.db_instance}"
  }

  # ... other configuration ...
}
```

---

## Troubleshooting

### Cloud SQL Volume Issues

**Problem:** Container can't connect via Unix socket

**Solutions:**
1. Verify `enable_cloudsql_volume = true`
2. Check mount path in environment variables matches `cloudsql_volume_mount_path`
3. Ensure Cloud SQL instance exists and is in the same region
4. Verify service account has `cloudsql.client` role

### Google Drive Backup Issues

**Problem:** Backup download fails

**Solutions:**
1. Verify file ID is correct (extract from Google Drive URL)
2. Ensure file is publicly accessible or shared with service account
3. Check file size - large files may need increased timeout
4. Verify backup format matches actual file format

**Problem:** Import fails

**Solutions:**
1. Check database credentials in Secret Manager
2. Verify database exists before import
3. Review Cloud Run job logs for specific error messages
4. Ensure database type matches backup format

### PostgreSQL Extensions Issues

**Problem:** Extension installation fails

**Solutions:**
1. Verify extension name spelling
2. Check PostgreSQL version supports the extension
3. Some extensions require additional database flags - add via `database_flags`
4. Review job logs to see specific SQL error

**Problem:** Extension already exists error

**Solutions:**
1. This is normal - script uses `CREATE EXTENSION IF NOT EXISTS`
2. Non-blocking - other extensions will still install
3. Check final extension list in job logs

---

## Performance Considerations

### Cloud SQL Unix Sockets
- **Benefit:** ~20% faster than TCP/IP for high-throughput apps
- **Trade-off:** Ties deployment to specific instance
- **Recommendation:** Use for production workloads with high database I/O

### Google Drive Backup Import
- **Timeout:** 30 minutes default
- **Network:** Requires internet egress
- **Size Limits:** Tested up to 5GB backups
- **Recommendation:** For initial deployment only; use Cloud SQL backups for ongoing operations

### PostgreSQL Extensions
- **Timeout:** 5 minutes default
- **Impact:** Minimal - runs once during deployment
- **Recommendation:** Install only required extensions to minimize deployment time

---

## Security Considerations

### Secrets Management
All sensitive data (passwords, credentials) are stored in Secret Manager:
- Database passwords
- Root passwords
- Never logged or exposed in job output

### Network Security
- Jobs run in VPC with private IP access to Cloud SQL
- Egress can be controlled via `vpc_egress_setting`
- Cloud SQL instances not publicly exposed

### Google Drive Access
- Backup files should be private or shared only with service account
- File ID exposure is low risk (file still requires authentication)
- Consider rotating file IDs after deployment

---

## Future Enhancements

Potential future additions to further improve compatibility:

1. **Multi-Service Support** - Deploy multiple interconnected Cloud Run services (for N8N_AI)
2. **Cloud Storage Backup Import** - Import backups from GCS instead of Google Drive
3. **MySQL Extensions** - Support for MySQL plugins and extensions
4. **Custom Extension Scripts** - User-provided SQL scripts for database initialization
5. **Backup Export Jobs** - Automated backup to Google Drive or GCS
6. **Health Checks for Jobs** - Verify extensions and data after import

---

## Support

For issues or questions:
1. Check Terraform plan output for validation errors
2. Review Cloud Run job logs in GCP Console
3. Check Secret Manager for correct secret values
4. Review this documentation for configuration examples

---

**Document Version:** 1.0
**Last Updated:** 2026-01-20
**Module Version:** WebApp v2.0 (with compatibility enhancements)
