# CloudRunApp Module Additional Enhancement Features

This document describes three additional enhancement features added to the CloudRunApp module to further improve compatibility, security, and flexibility.

> **📢 NEW: Unified Backup Import Interface**
>
> The backup import features (Google Drive and GCS) now have a unified, easier-to-use interface!
> See **[UNIFIED_BACKUP_IMPORT.md](./UNIFIED_BACKUP_IMPORT.md)** for the recommended approach.
>
> **Quick Start with Unified Interface:**
> ```hcl
> enable_backup_import = true
> backup_source        = "gcs"  # or "gdrive"
> backup_uri           = "gs://my-bucket/backup.sql"
> backup_format        = "sql"
> ```
>
> Legacy variables documented below are still supported but deprecated.

## Overview

Three additional enhancement features have been implemented:

1. **Cloud Storage Backup Import** - Import backups from GCS (more secure than Google Drive)
2. **MySQL Plugins Installation** - Automated installation of MySQL plugins and components
3. **Custom SQL Scripts Execution** - Run user-provided SQL scripts for custom initialization

**Plus:** Unified backup import interface for easier configuration!

---

## Feature 1: Cloud Storage Backup Import

### Description
Imports database backups from Google Cloud Storage instead of Google Drive. This provides better security, performance, and integration with Google Cloud infrastructure. Recommended over Google Drive import for production deployments.

### Advantages over Google Drive Import
- **Security**: Uses Cloud IAM for access control (no public sharing required)
- **Performance**: Faster downloads within Google Cloud network
- **Integration**: Seamless with existing GCS buckets and IAM policies
- **Reliability**: No external API dependencies
- **Cost**: No bandwidth charges for same-region transfers

### Configuration Variables

#### `enable_gcs_backup_import` (boolean)
- **Default**: `false`
- **Description**: Enable automatic import of database backup from Google Cloud Storage
- **Usage**: Set to `true` to enable backup import during deployment
- **Group**: Database Extensions & Backup Configuration (Group 13)
- **Order**: 1305

#### `gcs_backup_uri` (string)
- **Default**: `""`
- **Description**: Full GCS URI of the backup file
- **Format**: `gs://bucket-name/path/to/backup.sql`
- **Examples**:
  - `gs://my-backups/production/database-2024-01-20.sql`
  - `gs://app-backups/cyclos/backup.tar.gz`
- **Group**: Database Extensions & Backup Configuration (Group 13)
- **Order**: 1306

#### `gcs_backup_format` (string)
- **Default**: `"sql"`
- **Description**: Backup file format
- **Valid Values**: `sql`, `tar`, `gz`, `tgz`, `tar.gz`, `zip`
- **Group**: Database Extensions & Backup Configuration (Group 13)
- **Order**: 1307

### Implementation Details

**Files Created:**
- `modules/CloudRunApp/scripts/core/import-gcs-backup.sh` - GCS backup import script

**Script Features:**
- Uses `gsutil` (pre-installed in Cloud Run) for downloads
- Supports SQL dumps, gzip, tar archives, and zip files
- Automatic extraction and import of compressed backups
- Works with MySQL and PostgreSQL databases
- No external dependencies (no pip installs required)
- Faster execution than Google Drive import

### Usage Examples

**Basic SQL dump import:**
```hcl
module "app" {
  source = "./modules/CloudRunApp"

  # ... other configuration ...

  enable_gcs_backup_import = true
  gcs_backup_uri           = "gs://my-backups/production/database.sql"
  gcs_backup_format        = "sql"

  database_type = "POSTGRES_15"
}
```

**Compressed backup import:**
```hcl
module "app" {
  source = "./modules/CloudRunApp"

  # ... other configuration ...

  enable_gcs_backup_import = true
  gcs_backup_uri           = "gs://my-backups/database-backup.tar.gz"
  gcs_backup_format        = "tgz"

  database_type = "MYSQL_8_0"
}
```

**Using existing bucket:**
```hcl
resource "google_storage_bucket" "backups" {
  name          = "my-app-backups-${var.project_id}"
  location      = "US"
  force_destroy = false

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket_object" "backup" {
  name   = "backups/latest.sql"
  bucket = google_storage_bucket.backups.name
  source = "path/to/local/backup.sql"
}

module "app" {
  source = "./modules/CloudRunApp"

  # ... other configuration ...

  enable_gcs_backup_import = true
  gcs_backup_uri           = "gs://${google_storage_bucket.backups.name}/backups/latest.sql"
  gcs_backup_format        = "sql"
}
```

### IAM Permissions Required

The Cloud Run service account needs the following permissions on the GCS bucket:

```hcl
resource "google_storage_bucket_iam_member" "backup_access" {
  bucket = "my-backups-bucket"
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${local.cloud_run_sa_email}"
}
```

### Job Execution Details

**Job Name:** `${resource_prefix}-gcs-backup`
**Container Image:** `debian:12-slim`
**Timeout:** 30 minutes (1800 seconds)
**Resources:** 2 CPU, 2Gi memory
**Execution:** Runs after PostgreSQL extensions and MySQL plugins (if enabled)

**Environment Variables:**
- `GCS_BACKUP_URI` - Full GCS URI
- `BACKUP_FORMAT` - Backup format
- `DB_TYPE` - Database type (MYSQL/POSTGRES)
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` - Database connection details
- `DB_PASSWORD`, `ROOT_PASSWORD` - From Secret Manager

### Benefits
- **No Public Access**: Backups remain private in your GCS bucket
- **Fast Transfer**: In-region transfers are nearly instantaneous
- **Cost Effective**: No egress charges for same-region transfers
- **Versioning**: Use GCS versioning for backup history
- **Lifecycle**: Automatic deletion of old backups with lifecycle rules

---

## Feature 2: MySQL Plugins Installation

### Description
Automatically installs MySQL plugins and components during deployment. Similar to PostgreSQL extensions, this enables features like password validation, audit logging, LDAP authentication, and more.

### Configuration Variables

#### `enable_mysql_plugins` (boolean)
- **Default**: `false`
- **Description**: Enable automatic installation of MySQL plugins and components
- **Usage**: Set to `true` to install plugins during deployment
- **Group**: Database Extensions & Backup Configuration (Group 13)
- **Order**: 1308
- **Note**: Only applicable when using MySQL databases

#### `mysql_plugins` (list of strings)
- **Default**: `[]`
- **Description**: List of MySQL plugins to install
- **Common Plugins**:
  - `validate_password` / `component_validate_password` - Password strength validation (MySQL 8.0+)
  - `audit_log` - Audit logging for compliance
  - `clone` - Database cloning (MySQL 8.0+)
  - `group_replication` - Multi-master replication
  - `authentication_ldap_simple` - LDAP authentication (simple)
  - `authentication_ldap_sasl` - LDAP authentication (SASL)
  - `rpl_semi_sync_master` - Semisynchronous replication (master)
  - `rpl_semi_sync_slave` - Semisynchronous replication (slave)
- **Validation**: Plugin names must start with letter/underscore, contain only lowercase letters, numbers, and underscores
- **Group**: Database Extensions & Backup Configuration (Group 13)
- **Order**: 1309

### Implementation Details

**Files Created:**
- `modules/CloudRunApp/scripts/core/install-mysql-plugins.sh` - Plugin installation script

**Script Features:**
- Installs MySQL client automatically
- Handles both traditional plugins and new components (MySQL 8.0+)
- Uses database root credentials for installation
- Continues on failure (non-blocking for optional plugins)
- Verifies installed plugins from INFORMATION_SCHEMA
- Special handling for different plugin types

### Usage Examples

**Password validation for security:**
```hcl
module "app" {
  source = "./modules/CloudRunApp"

  # ... other configuration ...

  database_type = "MYSQL_8_0"

  enable_mysql_plugins = true
  mysql_plugins = [
    "component_validate_password"
  ]
}
```

**Audit logging for compliance:**
```hcl
module "app" {
  source = "./modules/CloudRunApp"

  # ... other configuration ...

  database_type = "MYSQL_8_0"

  enable_mysql_plugins = true
  mysql_plugins = [
    "audit_log",
    "component_validate_password"
  ]

  # Additional MySQL configuration for audit log
  database_flags = {
    audit_log_policy = "ALL"
    audit_log_format = "JSON"
  }
}
```

**LDAP authentication:**
```hcl
module "app" {
  source = "./modules/CloudRunApp"

  # ... other configuration ...

  database_type = "MYSQL_8_0"

  enable_mysql_plugins = true
  mysql_plugins = [
    "authentication_ldap_simple"
  ]

  database_flags = {
    authentication_ldap_simple_server_host = "ldap.example.com"
    authentication_ldap_simple_server_port = "389"
  }
}
```

**Replication setup:**
```hcl
module "app" {
  source = "./modules/CloudRunApp"

  # ... other configuration ...

  database_type = "MYSQL_8_0"

  enable_mysql_plugins = true
  mysql_plugins = [
    "rpl_semi_sync_master",
    "rpl_semi_sync_slave"
  ]
}
```

### Job Execution Details

**Job Name:** `${resource_prefix}-mysql-plugins`
**Container Image:** `debian:12-slim`
**Timeout:** 5 minutes (300 seconds)
**Resources:** 1 CPU, 512Mi memory
**Execution:** Runs after NFS setup, before backup import

**Environment Variables:**
- `MYSQL_PLUGINS` - Comma-separated list of plugins
- `DB_HOST`, `DB_PORT`, `DB_NAME` - Database connection details
- `ROOT_USER` - Database root user (typically 'root')
- `ROOT_PASSWORD` - From Secret Manager

### Plugin Installation Commands

The script uses appropriate commands for different plugin types:

```sql
-- Components (MySQL 8.0+)
INSTALL COMPONENT 'file://component_validate_password';

-- Traditional plugins
INSTALL PLUGIN audit_log SONAME 'audit_log.so';

-- Verification
SELECT PLUGIN_NAME, PLUGIN_STATUS, PLUGIN_TYPE, PLUGIN_LIBRARY
FROM INFORMATION_SCHEMA.PLUGINS
WHERE PLUGIN_LIBRARY IS NOT NULL;
```

### Benefits
- **Security**: Password validation, audit logging
- **Compliance**: Track database access and changes
- **Authentication**: LDAP/AD integration
- **High Availability**: Replication plugins
- **Automated Setup**: No manual plugin installation

---

## Feature 3: Custom SQL Scripts Execution

### Description
Executes user-provided SQL scripts from Google Cloud Storage during database initialization. This is the most flexible initialization method, allowing you to run any custom SQL commands for schema creation, data seeding, user management, or complex initialization logic.

### Configuration Variables

#### `enable_custom_sql_scripts` (boolean)
- **Default**: `false`
- **Description**: Enable execution of custom SQL scripts from GCS during initialization
- **Usage**: Set to `true` to execute SQL scripts during deployment
- **Use Cases**: Data seeding, schema migrations, custom user creation, multi-tenant setup
- **Group**: Database Extensions & Backup Configuration (Group 13)
- **Order**: 1310

#### `custom_sql_scripts_bucket` (string)
- **Default**: `""`
- **Description**: GCS bucket name containing SQL scripts (without gs:// prefix)
- **Format**: `bucket-name` (not `gs://bucket-name`)
- **Examples**: `my-sql-scripts`, `app-initialization-scripts`
- **Group**: Database Extensions & Backup Configuration (Group 13)
- **Order**: 1311

#### `custom_sql_scripts_path` (string)
- **Default**: `""`
- **Description**: Path prefix in GCS bucket for SQL scripts
- **Format**: `path/to/scripts/` (with or without trailing slash)
- **Examples**: `scripts/init/`, `sql/`, `initialization/`
- **Naming Convention**: Use numeric prefixes for execution order
  - `001_schema.sql` - Create schema first
  - `002_tables.sql` - Create tables
  - `003_indexes.sql` - Create indexes
  - `004_data.sql` - Seed data
- **Group**: Database Extensions & Backup Configuration (Group 13)
- **Order**: 1312

#### `custom_sql_scripts_use_root` (boolean)
- **Default**: `false`
- **Description**: Execute scripts as database root user instead of application user
- **Usage**: Set to `true` for scripts requiring elevated privileges
- **Use Cases**:
  - Creating additional databases
  - Creating additional users
  - Installing extensions (if not using dedicated extension jobs)
  - Granting privileges
  - System configuration
- **Group**: Database Extensions & Backup Configuration (Group 13)
- **Order**: 1313

### Implementation Details

**Files Created:**
- `modules/CloudRunApp/scripts/core/run-custom-sql-scripts.sh` - SQL script executor

**Script Features:**
- Downloads all `.sql` files from specified GCS path
- Executes scripts in **alphabetical order**
- Supports both MySQL and PostgreSQL
- Can execute as application user or root user
- Fails immediately on first script error
- Comprehensive logging of execution

### Usage Examples

**Basic data seeding:**
```hcl
# Upload scripts to GCS
resource "google_storage_bucket" "scripts" {
  name     = "my-app-scripts-${var.project_id}"
  location = "US"
}

resource "google_storage_bucket_object" "seed_data" {
  name    = "init/001_seed_data.sql"
  bucket  = google_storage_bucket.scripts.name
  content = file("${path.module}/sql/seed_data.sql")
}

module "app" {
  source = "./modules/CloudRunApp"

  # ... other configuration ...

  enable_custom_sql_scripts = true
  custom_sql_scripts_bucket = google_storage_bucket.scripts.name
  custom_sql_scripts_path   = "init/"
}
```

**Multi-tenant initialization:**
```hcl
module "app" {
  source = "./modules/CloudRunApp"

  # ... other configuration ...

  enable_custom_sql_scripts    = true
  custom_sql_scripts_bucket    = "my-init-scripts"
  custom_sql_scripts_path      = "multi-tenant/"
  custom_sql_scripts_use_root  = true  # Need root to create schemas
}

# Example scripts in GCS:
# gs://my-init-scripts/multi-tenant/001_create_schemas.sql
# gs://my-init-scripts/multi-tenant/002_create_users.sql
# gs://my-init-scripts/multi-tenant/003_grant_permissions.sql
# gs://my-init-scripts/multi-tenant/004_seed_tenants.sql
```

**Complex initialization with extensions:**
```hcl
module "app" {
  source = "./modules/CloudRunApp"

  # ... other configuration ...

  # Install extensions first
  enable_postgres_extensions = true
  postgres_extensions = ["postgis", "uuid-ossp"]

  # Then run custom SQL scripts
  enable_custom_sql_scripts   = true
  custom_sql_scripts_bucket   = "my-init-scripts"
  custom_sql_scripts_path     = "postgis-app/"
  custom_sql_scripts_use_root = false  # App user has sufficient permissions

  depends_on = [
    # Extension job runs first, then custom scripts
  ]
}
```

### Example SQL Scripts

**001_schema.sql** (PostgreSQL):
```sql
-- Create additional schemas
CREATE SCHEMA IF NOT EXISTS reporting;
CREATE SCHEMA IF NOT EXISTS analytics;

-- Grant access to application user
GRANT ALL ON SCHEMA reporting TO current_user;
GRANT ALL ON SCHEMA analytics TO current_user;
```

**002_tables.sql**:
```sql
-- Create tables in main database
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**003_seed_data.sql**:
```sql
-- Insert default data
INSERT INTO users (email) VALUES
    ('admin@example.com'),
    ('support@example.com')
ON CONFLICT (email) DO NOTHING;

INSERT INTO products (name, price) VALUES
    ('Starter Plan', 9.99),
    ('Pro Plan', 29.99),
    ('Enterprise Plan', 99.99)
ON CONFLICT DO NOTHING;
```

**004_functions.sql** (PostgreSQL):
```sql
-- Create custom functions
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.modified_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER update_users_modtime
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_column();
```

### Script Organization Best Practices

1. **Numeric Prefixes**: Use 3-digit prefixes (001, 002, 003, ...)
2. **Descriptive Names**: `001_create_schema.sql`, not `script1.sql`
3. **Logical Order**:
   - 001-099: Schema and structure
   - 100-199: Tables and relations
   - 200-299: Indexes and constraints
   - 300-399: Functions and procedures
   - 400-499: Triggers and views
   - 500-599: Initial data seeding
   - 600-699: Default configurations
   - 900-999: Final validations

4. **Idempotent Scripts**: Use `IF NOT EXISTS`, `ON CONFLICT`, etc.
5. **Comments**: Document purpose and assumptions
6. **Testing**: Test locally before uploading to GCS

### IAM Permissions Required

```hcl
resource "google_storage_bucket_iam_member" "scripts_access" {
  bucket = var.custom_sql_scripts_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${local.cloud_run_sa_email}"
}
```

### Job Execution Details

**Job Name:** `${resource_prefix}-custom-sql`
**Container Image:** `debian:12-slim`
**Timeout:** 10 minutes (600 seconds)
**Resources:** 1 CPU, 1Gi memory
**Retries:** 0 (no retry on failure - prevents duplicate executions)
**Execution:** Runs last, after all other initialization jobs

**Environment Variables:**
- `SQL_SCRIPTS_BUCKET` - Bucket name (without gs://)
- `SQL_SCRIPTS_PATH` - Path prefix in bucket
- `DB_TYPE` - Database type (MYSQL/POSTGRES)
- `DB_HOST`, `DB_PORT`, `DB_NAME` - Database connection
- `DB_USER`, `DB_PASSWORD` - Application user credentials
- `ROOT_USER`, `ROOT_PASSWORD` - Root user credentials
- `USE_ROOT` - "true" or "false"

### Error Handling

- **Script Not Found**: Job fails if no .sql files found
- **Execution Failure**: Job stops on first failed script
- **No Retry**: Prevents duplicate executions of partially completed scripts
- **Logging**: Each script execution is logged with status

### Benefits
- **Maximum Flexibility**: Run any SQL commands
- **Version Control**: SQL scripts in git alongside Terraform
- **Repeatability**: Idempotent scripts ensure consistent state
- **Order Control**: Numeric prefixes guarantee execution order
- **Complex Logic**: Multi-step initialization processes
- **Data Seeding**: Load reference data, test data, or production data

---

## Combined Usage: All Features Together

Here's an example using all six database initialization features:

```hcl
module "complete_app" {
  source = "./modules/CloudRunApp"

  # Basic Configuration
  existing_project_id  = "my-project"
  tenant_deployment_id = "prod"
  application_name     = "myapp"
  database_type        = "POSTGRES_15"

  # Feature 1: PostgreSQL Extensions (from original enhancements)
  enable_postgres_extensions = true
  postgres_extensions = [
    "postgis",
    "uuid-ossp",
    "pg_trgm"
  ]

  # Feature 2: Cloud Storage Backup Import (NEW)
  enable_gcs_backup_import = true
  gcs_backup_uri           = "gs://my-backups/production/latest.sql.gz"
  gcs_backup_format        = "gz"

  # Feature 3: Custom SQL Scripts (NEW)
  enable_custom_sql_scripts   = true
  custom_sql_scripts_bucket   = "my-init-scripts"
  custom_sql_scripts_path     = "production/init/"
  custom_sql_scripts_use_root = true

  # Cloud SQL Unix Socket (from original enhancements)
  enable_cloudsql_volume     = true
  cloudsql_volume_mount_path = "/cloudsql"
}
```

**For MySQL:**

```hcl
module "mysql_app" {
  source = "./modules/CloudRunApp"

  # Basic Configuration
  existing_project_id  = "my-project"
  tenant_deployment_id = "prod"
  application_name     = "myapp"
  database_type        = "MYSQL_8_0"

  # Feature 1: MySQL Plugins (NEW)
  enable_mysql_plugins = true
  mysql_plugins = [
    "component_validate_password",
    "audit_log"
  ]

  # Feature 2: GCS Backup Import (NEW)
  enable_gcs_backup_import = true
  gcs_backup_uri           = "gs://my-backups/mysql-backup.tar.gz"
  gcs_backup_format        = "tgz"

  # Feature 3: Custom SQL Scripts (NEW)
  enable_custom_sql_scripts  = true
  custom_sql_scripts_bucket  = "my-mysql-scripts"
  custom_sql_scripts_path    = "init/"
  custom_sql_scripts_use_root = true
}
```

---

## Job Execution Order

When all features are enabled, jobs execute in this order:

1. **NFS Setup Job** (if NFS enabled)
2. **PostgreSQL Extensions Job** (if PostgreSQL + extensions enabled)
3. **MySQL Plugins Job** (if MySQL + plugins enabled)
4. **Google Drive Backup Import** (if GDrive backup enabled)
5. **GCS Backup Import** (if GCS backup enabled)
6. **Custom SQL Scripts** (if custom scripts enabled)
7. **Custom Initialization Jobs** (user-defined jobs)
8. **Cloud Run Service Deployment**

**Note:** You should typically use **either** Google Drive **or** GCS backup import, not both.

---

## Comparison: Google Drive vs GCS Backup Import

| Feature | Google Drive | Google Cloud Storage |
|---------|-------------|----------------------|
| **Security** | Requires public sharing or service account sharing | Native Cloud IAM integration |
| **Performance** | External API, slower downloads | In-network, fast transfers |
| **Cost** | Free (Google Drive storage) | GCS storage costs, but no egress in same region |
| **Reliability** | Depends on Google Drive API | Native GCS reliability |
| **Setup** | Need to get file ID, share file | Upload to GCS bucket |
| **IAM** | Manual sharing required | Standard Cloud IAM |
| **Versioning** | Drive versioning | GCS object versioning |
| **Lifecycle** | Manual deletion | Automatic lifecycle rules |
| **Recommended For** | Quick tests, one-time migrations | Production deployments |

**Recommendation**: Use GCS backup import for production deployments and Google Drive only for quick tests or migrations from external systems.

---

## Security Considerations

### GCS Backup Import
- **Bucket Access**: Grant minimum permissions (objectViewer only)
- **Private Buckets**: Keep backup buckets private
- **Encryption**: Use customer-managed encryption keys (CMEK) for sensitive backups
- **Versioning**: Enable versioning to recover from accidental deletions
- **Lifecycle**: Automatically delete old backups

### MySQL Plugins
- **Audit Logs**: Store audit logs securely, review regularly
- **Password Validation**: Enforce strong password policies
- **Authentication**: Use LDAP/AD for centralized user management
- **Minimal Plugins**: Only install required plugins

### Custom SQL Scripts
- **Code Review**: Review all SQL scripts before deployment
- **Least Privilege**: Use application user when possible (not root)
- **Idempotency**: Ensure scripts can run multiple times safely
- **Secrets**: Never hardcode passwords in SQL scripts
- **Validation**: Test scripts in development first
- **Audit Trail**: Track which scripts were executed

---

## Troubleshooting

### GCS Backup Import Issues

**Problem:** `gsutil` fails to download backup

**Solutions:**
1. Verify GCS URI format: `gs://bucket/path/file.sql`
2. Check service account has `storage.objectViewer` role
3. Verify bucket and file exist
4. Check bucket location matches job region (for performance)

**Problem:** Backup import times out

**Solutions:**
1. Check backup file size - files >10GB may need timeout adjustment
2. Use compressed formats (gz, tar.gz) for faster transfers
3. Consider splitting large backups into smaller chunks

### MySQL Plugins Issues

**Problem:** Plugin installation fails

**Solutions:**
1. Verify plugin name spelling
2. Check MySQL version supports the plugin
3. Some plugins require specific Cloud SQL database flags
4. Review job logs for specific error messages

**Problem:** Component vs Plugin confusion (MySQL 8.0)

**Solutions:**
- Use `component_validate_password` for MySQL 8.0+ (not `validate_password`)
- Script handles both automatically based on plugin name

### Custom SQL Scripts Issues

**Problem:** No scripts found

**Solutions:**
1. Verify bucket name (without `gs://` prefix)
2. Check path prefix matches actual structure
3. Ensure scripts have `.sql` extension
4. Verify service account has access to bucket

**Problem:** Scripts execute in wrong order

**Solutions:**
1. Use numeric prefixes: `001_`, `002_`, `003_`
2. Pad with zeros: `001` not `1`
3. Check alphabetical sorting matches intended order

**Problem:** Script fails midway

**Solutions:**
1. Review job logs for specific SQL error
2. Test script locally first
3. Make scripts idempotent (use `IF NOT EXISTS`, etc.)
4. Check user permissions (may need `use_root = true`)

**Problem:** Need to re-run scripts after failure

**Solutions:**
1. Job has no retries to prevent duplicates
2. Fix the failing script in GCS
3. Run `terraform apply` again to re-execute job
4. Or manually execute: `gcloud run jobs execute <job-name>`

---

## Migration Examples

### From Google Drive to GCS

**Before:**
```hcl
enable_gdrive_backup_import = true
gdrive_backup_file_id       = "1abc123def..."
gdrive_backup_format        = "sql"
```

**After:**
```hcl
# Upload backup to GCS first
resource "google_storage_bucket_object" "backup" {
  name   = "backups/database.sql"
  bucket = "my-backups"
  source = "path/to/backup.sql"
}

# Use GCS import
enable_gcs_backup_import = true
gcs_backup_uri           = "gs://my-backups/backups/database.sql"
gcs_backup_format        = "sql"
```

### Adding MySQL Plugins to Existing Deployment

**Step 1: Add plugin configuration**
```hcl
enable_mysql_plugins = true
mysql_plugins = ["component_validate_password"]
```

**Step 2: Apply changes**
```bash
terraform apply
```

**Step 3: Verify plugins installed**
```sql
SELECT PLUGIN_NAME, PLUGIN_STATUS
FROM INFORMATION_SCHEMA.PLUGINS
WHERE PLUGIN_NAME = 'validate_password';
```

### Migrating Manual Scripts to Automated Execution

**Before:** Manual SQL script execution after deployment

**After:**
```hcl
# Upload scripts to GCS
resource "google_storage_bucket" "scripts" {
  name     = "my-scripts-${var.project_id}"
  location = "US"
}

resource "google_storage_bucket_object" "init_scripts" {
  for_each = fileset("${path.module}/sql", "*.sql")

  name   = "init/${each.value}"
  bucket = google_storage_bucket.scripts.name
  source = "${path.module}/sql/${each.value}"
}

# Configure automated execution
enable_custom_sql_scripts = true
custom_sql_scripts_bucket = google_storage_bucket.scripts.name
custom_sql_scripts_path   = "init/"
```

---

## Performance Optimization

### GCS Backup Import
- **Same Region**: Store backups in same region as database
- **Compression**: Use gzip compression for faster transfers
- **Parallel Uploads**: Use `gsutil -m` for multiple file uploads
- **Transfer Service**: For large historical data, use Storage Transfer Service

### MySQL Plugins
- **Minimal Set**: Only install plugins you actually use
- **Performance Impact**: Some plugins (audit_log) can impact performance
- **Configuration**: Tune plugin settings via `database_flags`

### Custom SQL Scripts
- **Batch Operations**: Use multi-row INSERTs instead of individual rows
- **Indexes**: Create indexes after bulk data loads
- **Transactions**: Wrap related operations in transactions
- **COPY/LOAD**: Use PostgreSQL COPY or MySQL LOAD DATA for bulk imports

---

## Cost Considerations

### GCS Backup Import
- **Storage**: GCS Standard storage costs (~ $0.02/GB/month)
- **Operations**: Negligible (one download per deployment)
- **Egress**: Free for same-region transfers
- **Recommendation**: Use lifecycle rules to delete old backups

### MySQL Plugins
- **No Additional Cost**: Plugins don't incur charges
- **Audit Logs**: May increase storage (if stored in database)

### Custom SQL Scripts
- **Storage**: GCS storage for scripts (minimal cost)
- **Execution**: Cloud Run job execution (minutes billed)
- **Typical Cost**: <$0.01 per deployment for script execution

---

## Best Practices Summary

1. **Prefer GCS over Google Drive** for production backups
2. **Use compressed formats** (gz, tar.gz) for large backups
3. **Test SQL scripts locally** before uploading to GCS
4. **Make scripts idempotent** to allow safe re-runs
5. **Use numeric prefixes** for script execution order
6. **Grant minimal IAM permissions** to service accounts
7. **Enable versioning** on backup buckets
8. **Document plugin purposes** in comments
9. **Review audit logs regularly** if using audit_log plugin
10. **Start with application user** for scripts, only use root when necessary

---

**Document Version:** 1.0
**Last Updated:** 2026-01-20
**Module Version:** CloudRunApp v2.1 (with additional enhancements)
