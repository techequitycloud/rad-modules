# Migrating from Application-Specific Modules to CloudRunApp

This guide shows how to deploy Odoo, Moodle, Cyclos, WordPress, Django, OpenEMR, and N8N using the general-purpose **CloudRunApp** module instead of their application-specific modules.

## Table of Contents

1. [Why Migrate to CloudRunApp?](#why-migrate-to-cloudrunapp)
2. [Migration Overview](#migration-overview)
3. [Application Migration Examples](#application-migration-examples)
   - [Odoo](#odoo)
   - [Moodle](#moodle)
   - [WordPress](#wordpress)
   - [Cyclos](#cyclos)
   - [Django](#django)
   - [OpenEMR](#openemr)
   - [N8N](#n8n)
4. [Advanced Features](#advanced-features)
5. [Troubleshooting](#troubleshooting)

---

## Why Migrate to CloudRunApp?

The CloudRunApp module provides several advantages over application-specific modules:

### Benefits

✅ **Single Module to Maintain** - One module for all applications
✅ **Enhanced Features** - Cloud SQL volumes, backup imports, extensions, plugins
✅ **Consistent Interface** - Same variables and patterns across all apps
✅ **Better Performance** - Unix socket connections for databases (20-30% faster)
✅ **More Flexibility** - Custom container images, environment variables, scaling options
✅ **Active Development** - New features added regularly

### Feature Comparison

| Feature | App-Specific Modules | CloudRunApp Module |
|---------|---------------------|---------------|
| Cloud SQL Unix Socket | ❌ No | ✅ Yes |
| Backup Import (GCS) | ❌ No | ✅ Yes |
| Backup Import (Google Drive) | ⚠️ Some | ✅ Yes |
| PostgreSQL Extensions | ❌ No | ✅ Yes |
| MySQL Plugins | ❌ No | ✅ Yes |
| Custom SQL Scripts | ❌ No | ✅ Yes |
| GCS Volume Mounts | ❌ No | ✅ Yes |
| Custom Environment Variables | ⚠️ Limited | ✅ Full Support |
| Resource Limits | ⚠️ Fixed | ✅ Configurable |
| Auto-Scaling | ⚠️ Limited | ✅ Full Control |

---

## Migration Overview

### General Migration Pattern

**Before (Application-Specific Module)**:
```hcl
module "odoo" {
  source = "./modules/Odoo"

  existing_project_id  = "my-project"
  tenant_deployment_id = "prod"
  network_name         = "vpc-network"

  application_name          = "odoo"
  application_version       = "18.0"
  application_database_name = "odoo"
  application_database_user = "odoo"
}
```

**After (CloudRunApp Module)**:
```hcl
module "odoo" {
  source = "./modules/CloudRunApp"

  existing_project_id  = "my-project"
  tenant_deployment_id = "prod"
  network_name         = "vpc-network"

  application_name          = "odoo"
  container_image           = "odoo:18.0"
  application_port          = 8069
  application_database_name = "odoo"
  application_database_user = "odoo"

  # Optional: Enable enhanced features
  enable_cloudsql_volume = true
}
```

### Key Differences

| Aspect | Change Required |
|--------|----------------|
| **Module Source** | Change from `./modules/Odoo` to `./modules/CloudRunApp` |
| **Container Image** | Add `container_image` variable (e.g., `"odoo:18.0"`) |
| **Application Port** | Add `application_port` variable (app-specific) |
| **Database Type** | Add `sql_server_type` if needed (defaults to PostgreSQL) |
| **Version Syntax** | Remove `application_release`, `application_sha` (use Docker tags) |

---

## Application Migration Examples

### Odoo

**Odoo** is an Enterprise Resource Planning (ERP) system with CRM, e-commerce, billing, and accounting features.

#### Original Module

```hcl
module "odoo" {
  source = "./modules/Odoo"

  existing_project_id       = "my-project"
  tenant_deployment_id      = "prod"
  deployment_region         = "us-central1"
  network_name              = "vpc-network"
  agent_service_account     = "cloudrun-sa@my-project.iam.gserviceaccount.com"
  resource_creator_identity = "user:admin@example.com"

  application_name          = "odoo"
  application_version       = "18.0"
  application_release       = "20251008"
  application_sha           = "c15a8eb3791e805b9cd3078f2dd4e0d78130b1c2"
  application_database_name = "odoo"
  application_database_user = "odoo"

  create_cloud_storage     = true
  configure_monitoring     = true
  configure_backups        = true
  application_backup_schedule = "0 0 * * *"
  application_backup_fileid   = "abc123"  # Google Drive file ID
}
```

#### CloudRunApp Migration

```hcl
module "odoo" {
  source = "./modules/CloudRunApp"

  # Common configuration (same as before)
  existing_project_id       = "my-project"
  tenant_deployment_id      = "prod"
  deployment_region         = "us-central1"
  network_name              = "vpc-network"
  agent_service_account     = "cloudrun-sa@my-project.iam.gserviceaccount.com"
  resource_creator_identity = "user:admin@example.com"

  # Application configuration
  application_name          = "odoo"
  container_image           = "odoo:18.0"  # Use official Docker image
  application_port          = 8069         # Odoo default port
  application_database_name = "odoo"
  application_database_user = "odoo"

  # Database configuration (PostgreSQL default)
  sql_server_type    = "postgres"
  sql_server_version = "15"

  # Enhanced features
  enable_cloudsql_volume    = true  # Better performance via Unix socket
  cloudsql_volume_mount_path = "/var/run/cloudsql"

  # Storage
  enable_gcs_volume = true
  gcs_volumes = [{
    bucket      = "${var.tenant_deployment_id}-odoo-filestore"
    mount_path  = "/var/lib/odoo/filestore"
    read_only   = false
  }]

  # Backup import (unified interface)
  enable_backup_import = true
  backup_source        = "gdrive"  # or "gcs"
  backup_uri           = "abc123"  # Google Drive file ID or gs:// URI
  backup_format        = "sql"

  # Monitoring and scaling
  configure_monitoring = true
  min_scale            = 1
  max_scale            = 10

  # Resource limits
  cpu_limit    = "2"
  memory_limit = "4Gi"
}
```

#### Odoo-Specific Environment Variables

```hcl
module "odoo" {
  source = "./modules/CloudRunApp"
  # ... (configuration from above)

  environment_variables = {
    # Database connection (Unix socket)
    DB_HOST = "/cloudsql/${var.existing_project_id}:${var.deployment_region}:${var.tenant_deployment_id}-odoo-postgres"
    DB_PORT = "5432"
    DB_NAME = var.application_database_name
    DB_USER = var.application_database_user

    # Odoo configuration
    ODOO_RC          = "/etc/odoo/odoo.conf"
    ADMIN_PASSWORD   = "change-me"  # Use Secret Manager in production
    LIST_DB          = "true"

    # File storage
    DATA_DIR = "/var/lib/odoo/filestore"
  }
}
```

---

### Moodle

**Moodle** is a Learning Management System (LMS) for creating and delivering online courses.

#### Original Module

```hcl
module "moodle" {
  source = "./modules/Moodle"

  existing_project_id       = "my-project"
  tenant_deployment_id      = "prod"
  network_name              = "vpc-network"
  agent_service_account     = "cloudrun-sa@my-project.iam.gserviceaccount.com"
  resource_creator_identity = "user:admin@example.com"

  application_name          = "moodle"
  application_version       = "5.0.0"
  application_database_name = "moodle"
  application_database_user = "moodle"

  configure_monitoring = true
}
```

#### CloudRunApp Migration

```hcl
module "moodle" {
  source = "./modules/CloudRunApp"

  # Common configuration
  existing_project_id       = "my-project"
  tenant_deployment_id      = "prod"
  deployment_region         = "us-central1"
  network_name              = "vpc-network"
  agent_service_account     = "cloudrun-sa@my-project.iam.gserviceaccount.com"
  resource_creator_identity = "user:admin@example.com"

  # Application configuration
  application_name          = "moodle"
  container_image           = "moodle:5.0.0-apache"  # Official Moodle image
  application_port          = 80                      # Apache default
  application_database_name = "moodle"
  application_database_user = "moodle"

  # Database configuration (MySQL for Moodle)
  sql_server_type    = "mysql"
  sql_server_version = "8.0"

  # Enhanced features
  enable_cloudsql_volume     = true
  cloudsql_volume_mount_path = "/var/run/mysqld"

  # Moodle data directory
  enable_gcs_volume = true
  gcs_volumes = [{
    bucket     = "${var.tenant_deployment_id}-moodle-data"
    mount_path = "/var/moodledata"
    read_only  = false
  }]

  # PostgreSQL extensions (if using PostgreSQL instead)
  # enable_postgres_extensions = true
  # postgres_extensions = ["pg_trgm", "btree_gin"]

  # Monitoring
  configure_monitoring = true

  # Resource limits (Moodle needs more resources)
  cpu_limit    = "2"
  memory_limit = "4Gi"
  min_scale    = 1
  max_scale    = 10

  # Environment variables
  environment_variables = {
    MOODLE_DATABASE_TYPE = "mysqli"
    MOODLE_DATABASE_HOST = "/cloudsql/${var.existing_project_id}:${var.deployment_region}:${var.tenant_deployment_id}-moodle-mysql"
    MOODLE_DATABASE_NAME = var.application_database_name
    MOODLE_DATABASE_USER = var.application_database_user

    # Moodle site configuration
    MOODLE_SITE_NAME     = "My Moodle Site"
    MOODLE_SITE_FULLNAME = "My Complete Moodle Site"
    MOODLE_SITE_SUMMARY  = "A great learning platform"
  }
}
```

---

### WordPress

**WordPress** is a popular Content Management System (CMS) for websites and blogs.

#### Original Module

```hcl
module "wordpress" {
  source = "./modules/Wordpress"

  existing_project_id       = "my-project"
  tenant_deployment_id      = "prod"
  network_name              = "vpc-network"
  agent_service_account     = "cloudrun-sa@my-project.iam.gserviceaccount.com"
  resource_creator_identity = "user:admin@example.com"

  application_name          = "wp"
  application_version       = "6.8.1"
  application_sha           = "52d5f05c96a9155f78ed84700264307e5dea14b4"
  application_database_name = "wp"
  application_database_user = "wp"

  create_cloud_storage = true
  configure_monitoring = true
}
```

#### CloudRunApp Migration

```hcl
module "wordpress" {
  source = "./modules/CloudRunApp"

  # Common configuration
  existing_project_id       = "my-project"
  tenant_deployment_id      = "prod"
  deployment_region         = "us-central1"
  network_name              = "vpc-network"
  agent_service_account     = "cloudrun-sa@my-project.iam.gserviceaccount.com"
  resource_creator_identity = "user:admin@example.com"

  # Application configuration
  application_name          = "wordpress"
  container_image           = "wordpress:6.8.1-apache"  # Official WordPress image
  application_port          = 80
  application_database_name = "wp"
  application_database_user = "wp"

  # Database configuration (MySQL for WordPress)
  sql_server_type    = "mysql"
  sql_server_version = "8.0"

  # Enhanced features
  enable_cloudsql_volume     = true
  cloudsql_volume_mount_path = "/var/run/mysqld"

  # WordPress uploads directory
  enable_gcs_volume = true
  gcs_volumes = [{
    bucket     = "${var.tenant_deployment_id}-wp-uploads"
    mount_path = "/var/www/html/wp-content/uploads"
    read_only  = false
  }]

  # MySQL plugins (optional - for advanced features)
  enable_mysql_plugins = true
  mysql_plugins = [
    "audit_log",  # MySQL audit plugin
  ]

  # Monitoring and scaling
  configure_monitoring = true
  min_scale            = 1
  max_scale            = 20  # WordPress can need high scaling

  # Resource limits
  cpu_limit    = "1"
  memory_limit = "2Gi"

  # Environment variables
  environment_variables = {
    # Database connection (Unix socket)
    WORDPRESS_DB_HOST = "localhost:/var/run/mysqld/mysqld.sock"
    WORDPRESS_DB_NAME = var.application_database_name
    WORDPRESS_DB_USER = var.application_database_user

    # WordPress configuration
    WORDPRESS_TABLE_PREFIX = "wp_"
    WORDPRESS_DEBUG        = "false"

    # Security
    WORDPRESS_CONFIG_EXTRA = <<-EOT
      define('FORCE_SSL_ADMIN', true);
      define('DISALLOW_FILE_EDIT', true);
    EOT
  }
}
```

---

### Cyclos

**Cyclos** is a Banking System (CBS) for financial institutions and community currencies.

#### Original Module

```hcl
module "cyclos" {
  source = "./modules/Cyclos"

  existing_project_id       = "my-project"
  tenant_deployment_id      = "prod"
  network_name              = "vpc-network"
  agent_service_account     = "cloudrun-sa@my-project.iam.gserviceaccount.com"
  resource_creator_identity = "user:admin@example.com"

  application_name          = "cyclos"
  application_version       = "4.16.15"
  application_database_name = "cyclos"
  application_database_user = "cyclos"

  configure_monitoring      = true
  application_backup_fileid = "xyz789"
}
```

#### CloudRunApp Migration

```hcl
module "cyclos" {
  source = "./modules/CloudRunApp"

  # Common configuration
  existing_project_id       = "my-project"
  tenant_deployment_id      = "prod"
  deployment_region         = "us-central1"
  network_name              = "vpc-network"
  agent_service_account     = "cloudrun-sa@my-project.iam.gserviceaccount.com"
  resource_creator_identity = "user:admin@example.com"

  # Application configuration
  application_name          = "cyclos"
  container_image           = "cyclos/cyclos:4.16.15"  # Cyclos Docker image
  application_port          = 8080                      # Cyclos default port
  application_database_name = "cyclos"
  application_database_user = "cyclos"

  # Database configuration (PostgreSQL for Cyclos)
  sql_server_type    = "postgres"
  sql_server_version = "15"

  # Enhanced features
  enable_cloudsql_volume     = true
  cloudsql_volume_mount_path = "/var/run/postgresql"

  # PostgreSQL extensions for Cyclos
  enable_postgres_extensions = true
  postgres_extensions = [
    "pg_trgm",      # Text search
    "uuid-ossp",    # UUID generation
  ]

  # Backup import
  enable_backup_import = true
  backup_source        = "gdrive"
  backup_uri           = "xyz789"
  backup_format        = "sql"

  # Monitoring
  configure_monitoring = true

  # Resource limits (Cyclos needs good resources)
  cpu_limit    = "2"
  memory_limit = "4Gi"
  min_scale    = 1
  max_scale    = 10

  # Environment variables
  environment_variables = {
    DB_HOST     = "/var/run/postgresql"
    DB_PORT     = "5432"
    DB_NAME     = var.application_database_name
    DB_USER     = var.application_database_user
    CYCLOS_HOME = "/usr/local/cyclos"
  }
}
```

---

### Django

**Django** is a high-level Python web framework for rapid development.

#### Original Module

```hcl
module "django" {
  source = "./modules/Django"

  existing_project_id       = "my-project"
  tenant_deployment_id      = "prod"
  network_name              = "vpc-network"
  agent_service_account     = "cloudrun-sa@my-project.iam.gserviceaccount.com"
  resource_creator_identity = "user:admin@example.com"

  application_name          = "django"
  application_version       = "5.0"
  application_database_name = "django"
  application_database_user = "django"
}
```

#### CloudRunApp Migration

```hcl
module "django" {
  source = "./modules/CloudRunApp"

  # Common configuration
  existing_project_id       = "my-project"
  tenant_deployment_id      = "prod"
  deployment_region         = "us-central1"
  network_name              = "vpc-network"
  agent_service_account     = "cloudrun-sa@my-project.iam.gserviceaccount.com"
  resource_creator_identity = "user:admin@example.com"

  # Application configuration
  application_name          = "django"
  container_image           = "your-registry/django-app:5.0"  # Custom image
  application_port          = 8000                             # Gunicorn/uWSGI port
  application_database_name = "django"
  application_database_user = "django"

  # Database configuration (PostgreSQL recommended for Django)
  sql_server_type    = "postgres"
  sql_server_version = "15"

  # Enhanced features
  enable_cloudsql_volume     = true
  cloudsql_volume_mount_path = "/cloudsql"

  # PostgreSQL extensions useful for Django
  enable_postgres_extensions = true
  postgres_extensions = [
    "pg_trgm",       # Full-text search
    "unaccent",      # Remove accents
    "hstore",        # Key-value store
    "citext",        # Case-insensitive text
  ]

  # Static files storage
  enable_gcs_volume = true
  gcs_volumes = [
    {
      bucket     = "${var.tenant_deployment_id}-django-static"
      mount_path = "/app/static"
      read_only  = false
    },
    {
      bucket     = "${var.tenant_deployment_id}-django-media"
      mount_path = "/app/media"
      read_only  = false
    }
  ]

  # Custom SQL initialization scripts
  enable_custom_sql_scripts     = true
  custom_sql_scripts_bucket     = "${var.tenant_deployment_id}-django-init"
  custom_sql_scripts_path       = "sql/"
  custom_sql_scripts_use_root   = true

  # Monitoring
  configure_monitoring = true

  # Resource limits
  cpu_limit    = "2"
  memory_limit = "2Gi"
  min_scale    = 1
  max_scale    = 10

  # Environment variables
  environment_variables = {
    # Django settings
    DJANGO_SETTINGS_MODULE = "myproject.settings.production"
    SECRET_KEY             = "use-secret-manager-in-production"
    DEBUG                  = "False"
    ALLOWED_HOSTS          = "*.run.app"

    # Database (Unix socket)
    DB_ENGINE   = "django.db.backends.postgresql"
    DB_HOST     = "/cloudsql/${var.existing_project_id}:${var.deployment_region}:${var.tenant_deployment_id}-django-postgres"
    DB_PORT     = "5432"
    DB_NAME     = var.application_database_name
    DB_USER     = var.application_database_user

    # Static/media files
    STATIC_ROOT = "/app/static"
    MEDIA_ROOT  = "/app/media"
  }
}
```

---

### OpenEMR

**OpenEMR** is an Electronic Health Records (EHR) and Medical Practice Management system.

#### Original Module

```hcl
module "openemr" {
  source = "./modules/OpenEMR"

  existing_project_id       = "my-project"
  tenant_deployment_id      = "prod"
  network_name              = "vpc-network"
  agent_service_account     = "cloudrun-sa@my-project.iam.gserviceaccount.com"
  resource_creator_identity = "user:admin@example.com"

  application_name          = "openemr"
  application_version       = "7.0.2"
  application_database_name = "openemr"
  application_database_user = "openemr"
}
```

#### CloudRunApp Migration

```hcl
module "openemr" {
  source = "./modules/CloudRunApp"

  # Common configuration
  existing_project_id       = "my-project"
  tenant_deployment_id      = "prod"
  deployment_region         = "us-central1"
  network_name              = "vpc-network"
  agent_service_account     = "cloudrun-sa@my-project.iam.gserviceaccount.com"
  resource_creator_identity = "user:admin@example.com"

  # Application configuration
  application_name          = "openemr"
  container_image           = "openemr/openemr:7.0.2"
  application_port          = 80
  application_database_name = "openemr"
  application_database_user = "openemr"

  # Database configuration (MySQL for OpenEMR)
  sql_server_type    = "mysql"
  sql_server_version = "8.0"

  # Enhanced features
  enable_cloudsql_volume     = true
  cloudsql_volume_mount_path = "/var/run/mysqld"

  # OpenEMR sites directory
  enable_gcs_volume = true
  gcs_volumes = [{
    bucket     = "${var.tenant_deployment_id}-openemr-sites"
    mount_path = "/var/www/localhost/htdocs/openemr/sites"
    read_only  = false
  }]

  # Monitoring
  configure_monitoring = true

  # Resource limits (healthcare apps need good performance)
  cpu_limit    = "2"
  memory_limit = "4Gi"
  min_scale    = 1
  max_scale    = 10

  # Environment variables
  environment_variables = {
    MYSQL_HOST = "localhost:/var/run/mysqld/mysqld.sock"
    MYSQL_ROOT_PASS = "use-secret-manager"
    MYSQL_USER      = var.application_database_user
    MYSQL_PASS      = "use-secret-manager"
    MYSQL_DATABASE  = var.application_database_name

    # OpenEMR configuration
    OE_USER  = "admin"
    OE_PASS  = "use-secret-manager"
  }
}
```

---

### N8N

**N8N** is a workflow automation platform.

#### Original Module

```hcl
module "n8n" {
  source = "./modules/N8N"

  existing_project_id       = "my-project"
  tenant_deployment_id      = "prod"
  network_name              = "vpc-network"
  agent_service_account     = "cloudrun-sa@my-project.iam.gserviceaccount.com"
  resource_creator_identity = "user:admin@example.com"

  application_name          = "n8n"
  application_version       = "latest"
  application_database_name = "n8n"
  application_database_user = "n8n"
}
```

#### CloudRunApp Migration (Simple N8N)

```hcl
module "n8n" {
  source = "./modules/CloudRunApp"

  # Common configuration
  existing_project_id       = "my-project"
  tenant_deployment_id      = "prod"
  deployment_region         = "us-central1"
  network_name              = "vpc-network"
  agent_service_account     = "cloudrun-sa@my-project.iam.gserviceaccount.com"
  resource_creator_identity = "user:admin@example.com"

  # Application configuration
  application_name          = "n8n"
  container_image           = "n8nio/n8n:latest"
  application_port          = 5678
  application_database_name = "n8n"
  application_database_user = "n8n"

  # Database configuration (PostgreSQL for N8N)
  sql_server_type    = "postgres"
  sql_server_version = "15"

  # Enhanced features
  enable_cloudsql_volume     = true
  cloudsql_volume_mount_path = "/cloudsql"

  # N8N data directory
  enable_gcs_volume = true
  gcs_volumes = [{
    bucket     = "${var.tenant_deployment_id}-n8n-data"
    mount_path = "/home/node/.n8n"
    read_only  = false
  }]

  # Monitoring
  configure_monitoring = true

  # Resource limits
  cpu_limit    = "2"
  memory_limit = "4Gi"
  min_scale    = 1
  max_scale    = 10

  # Environment variables
  environment_variables = {
    # Database connection
    DB_TYPE                   = "postgresdb"
    DB_POSTGRESDB_HOST        = "/cloudsql/${var.existing_project_id}:${var.deployment_region}:${var.tenant_deployment_id}-n8n-postgres"
    DB_POSTGRESDB_PORT        = "5432"
    DB_POSTGRESDB_DATABASE    = var.application_database_name
    DB_POSTGRESDB_USER        = var.application_database_user

    # N8N configuration
    N8N_ENCRYPTION_KEY        = "use-secret-manager"
    N8N_USER_MANAGEMENT_DISABLED = "false"
    EXECUTIONS_DATA_SAVE_ON_ERROR    = "all"
    EXECUTIONS_DATA_SAVE_ON_SUCCESS  = "all"

    # Timezone
    GENERIC_TIMEZONE = "America/New_York"
    TZ               = "America/New_York"
  }
}
```

---

## Advanced Features

### Cloud SQL Unix Socket (Recommended)

Use Unix sockets for 20-30% better database performance:

```hcl
enable_cloudsql_volume     = true
cloudsql_volume_mount_path = "/var/run/postgresql"  # or "/var/run/mysqld" for MySQL

environment_variables = {
  # PostgreSQL
  DB_HOST = "/var/run/postgresql"

  # MySQL
  DB_HOST = "localhost:/var/run/mysqld/mysqld.sock"
}
```

### Backup Import

Import existing backups during deployment:

```hcl
# From Google Cloud Storage (recommended)
enable_backup_import = true
backup_source        = "gcs"
backup_uri           = "gs://my-backups/database.sql.gz"
backup_format        = "sql"

# From Google Drive (for migrations)
enable_backup_import = true
backup_source        = "gdrive"
backup_uri           = "1abc...xyz"  # File ID from Drive URL
backup_format        = "sql"
```

### Database Extensions and Plugins

**PostgreSQL Extensions**:
```hcl
enable_postgres_extensions = true
postgres_extensions = [
  "postgis",      # Geographic data
  "pg_trgm",      # Text search
  "uuid-ossp",    # UUID generation
  "hstore",       # Key-value pairs
  "citext",       # Case-insensitive text
]
```

**MySQL Plugins**:
```hcl
enable_mysql_plugins = true
mysql_plugins = [
  "audit_log",         # Audit logging
  "authentication_pam", # PAM authentication
]
```

### Custom SQL Scripts

Execute custom SQL during deployment:

```hcl
enable_custom_sql_scripts   = true
custom_sql_scripts_bucket   = "my-init-scripts"
custom_sql_scripts_path     = "sql/"
custom_sql_scripts_use_root = true
```

Place scripts in GCS bucket:
```
gs://my-init-scripts/sql/
  001-create-tables.sql
  002-insert-data.sql
  003-create-indexes.sql
```

Scripts execute alphabetically.

### Multiple GCS Volumes

Mount multiple storage buckets:

```hcl
enable_gcs_volume = true
gcs_volumes = [
  {
    bucket     = "app-uploads"
    mount_path = "/uploads"
    read_only  = false
  },
  {
    bucket     = "app-static"
    mount_path = "/static"
    read_only  = true
  },
  {
    bucket     = "app-backups"
    mount_path = "/backups"
    read_only  = false
  }
]
```

### Auto-Scaling Configuration

Fine-tune scaling behavior:

```hcl
min_scale = 1   # Always keep 1 instance warm
max_scale = 20  # Scale up to 20 instances

# Scaling triggers
cpu_limit    = "2"      # 2 vCPU
memory_limit = "4Gi"    # 4GB RAM

# Request timeout
request_timeout_seconds = 300  # 5 minutes for long operations
```

### Custom Health Checks

Configure health check endpoints:

```hcl
startup_probe_path              = "/health/startup"
startup_probe_initial_delay     = 30
startup_probe_failure_threshold = 10

liveness_probe_path              = "/health/alive"
liveness_probe_initial_delay     = 10
liveness_probe_failure_threshold = 3
```

---

## Troubleshooting

### Container Image Not Found

**Problem**: `Error: Failed to pull image`

**Solution**: Verify the container image exists and is accessible:
```bash
docker pull odoo:18.0
docker pull wordpress:6.8.1-apache
```

For custom images, ensure they're pushed to Artifact Registry.

### Database Connection Failed

**Problem**: Application can't connect to database

**Solutions**:

1. **Check Unix socket path**:
   - PostgreSQL: `/var/run/postgresql`
   - MySQL: `/var/run/mysqld/mysqld.sock`

2. **Verify Cloud SQL instance**:
   ```hcl
   enable_cloudsql_volume = true
   ```

3. **Check environment variables**:
   ```hcl
   DB_HOST = "/var/run/postgresql"  # Not "localhost"
   ```

### Storage Mount Issues

**Problem**: Application can't write to GCS volume

**Solutions**:

1. **Verify bucket exists**:
   ```bash
   gsutil ls gs://your-bucket-name
   ```

2. **Check IAM permissions**:
   - Service account needs `roles/storage.objectAdmin`

3. **Verify mount path**:
   ```hcl
   gcs_volumes = [{
     mount_path = "/var/www/html/uploads"  # Must match app expectations
   }]
   ```

### Out of Memory Errors

**Problem**: Container crashes with OOM (Out of Memory)

**Solution**: Increase memory limit:
```hcl
memory_limit = "4Gi"  # Increase from default 2Gi
```

Applications that need more memory:
- Odoo: 4Gi+
- Moodle: 4Gi+
- OpenEMR: 4Gi+
- WordPress: 2Gi usually sufficient

### Backup Import Failed

**Problem**: Backup import job fails

**Solutions**:

1. **Check backup format**:
   ```hcl
   backup_format = "sql"  # Must match actual file format
   ```

2. **Verify backup URI**:
   - GCS: `gs://bucket-name/path/to/backup.sql.gz`
   - Google Drive: File ID from URL `https://drive.google.com/file/d/FILE_ID/view`

3. **Check file permissions**:
   - Service account needs access to GCS bucket or Google Drive file

### Migration from Application Module

**Problem**: Need to migrate existing deployment

**Steps**:

1. **Export current data**:
   ```bash
   # Export database
   gcloud sql export sql INSTANCE_NAME gs://bucket/backup.sql

   # Export files from old GCS bucket
   gsutil -m cp -r gs://old-bucket/* gs://new-bucket/
   ```

2. **Update Terraform**:
   ```hcl
   # Change module source
   source = "./modules/CloudRunApp"  # Was "./modules/Odoo"

   # Add new required variables
   container_image  = "odoo:18.0"
   application_port = 8069
   ```

3. **Import backup**:
   ```hcl
   enable_backup_import = true
   backup_source        = "gcs"
   backup_uri           = "gs://bucket/backup.sql"
   ```

4. **Apply changes**:
   ```bash
   terraform plan
   terraform apply
   ```

---

## Summary

The CloudRunApp module provides a unified, feature-rich alternative to application-specific modules. Key benefits:

✅ **Consistent interface** across all applications
✅ **Enhanced features** (Cloud SQL volumes, backup import, extensions)
✅ **Better performance** (Unix socket connections)
✅ **More flexibility** (custom images, scaling, environment variables)
✅ **Active development** with new features added regularly

### Quick Reference

| Application | Container Image | Port | Database | Notes |
|-------------|----------------|------|----------|-------|
| Odoo | `odoo:18.0` | 8069 | PostgreSQL | Use GCS for filestore |
| Moodle | `moodle:5.0.0-apache` | 80 | MySQL | Use GCS for moodledata |
| WordPress | `wordpress:6.8.1-apache` | 80 | MySQL | Use GCS for uploads |
| Cyclos | `cyclos/cyclos:4.16.15` | 8080 | PostgreSQL | Enable pg_trgm extension |
| Django | Custom | 8000 | PostgreSQL | Multiple GCS volumes |
| OpenEMR | `openemr/openemr:7.0.2` | 80 | MySQL | Use GCS for sites |
| N8N | `n8nio/n8n:latest` | 5678 | PostgreSQL | |

For more details on specific features, see:
- [COMPATIBILITY_ENHANCEMENTS.md](./COMPATIBILITY_ENHANCEMENTS.md) - Cloud SQL volumes, backup import, extensions
- [ADDITIONAL_FEATURES.md](./ADDITIONAL_FEATURES.md) - Custom SQL scripts, plugins
- [UNIFIED_BACKUP_IMPORT.md](./UNIFIED_BACKUP_IMPORT.md) - Backup import guide
