# WebApp Application Presets

## Overview

The WebApp module now supports **Application Presets** - pre-configured profiles for popular applications that eliminate the need for manual configuration of container images, ports, database types, resource limits, and environment variables.

Simply select a preset like `application_preset = "odoo"` and the module automatically configures everything needed to deploy that application.

## Benefits

✅ **Zero Configuration** - Deploy applications without knowing Docker images, ports, or environment variables
✅ **Best Practices** - Presets include optimized settings (Cloud SQL Unix sockets, proper resource limits)
✅ **Consistency** - Same configuration for the same application across all environments
✅ **Override Capability** - Can still override any preset value when needed
✅ **Easy Maintenance** - Preset definitions maintained centrally, updates benefit all deployments

## Available Presets

| Preset | Application | Database | Default Resources |
|--------|-------------|----------|-------------------|
| `odoo` | Odoo ERP 18.0 | PostgreSQL 15 | 2 CPU, 4Gi RAM |
| `wordpress` | WordPress 6.8.1 | MySQL 8.0 | 1 CPU, 2Gi RAM |
| `moodle` | Moodle 4.3 LMS | MySQL 8.0 | 2 CPU, 4Gi RAM |
| `cyclos` | Cyclos 4.16.15 Banking | PostgreSQL 15 | 2 CPU, 4Gi RAM |
| `django` | Django (Python 3.11) | PostgreSQL 15 | 2 CPU, 2Gi RAM |
| `openemr` | OpenEMR 7.0.2 EHR | MySQL 8.0 | 2 CPU, 4Gi RAM |
| `n8n` | n8n Workflow Automation | PostgreSQL 15 | 2 CPU, 4Gi RAM |
| `nextcloud` | Nextcloud 28 File Sync | PostgreSQL 15 | 2 CPU, 4Gi RAM |
| `gitlab` | GitLab CE 16.8 DevOps | PostgreSQL 15 | 4 CPU, 8Gi RAM |

## Quick Start

### Basic Usage

Deploy Odoo with zero configuration:

```hcl
module "odoo" {
  source = "./modules/WebApp"

  # Project configuration
  existing_project_id  = "my-project"
  tenant_deployment_id = "prod"
  network_name         = "my-vpc"

  # Application configuration
  application_name = "odoo"

  # Just select the preset!
  application_preset = "odoo"

  # That's it! Everything else is configured automatically:
  # - container_image: odoo:18.0
  # - container_port: 8069
  # - database_type: POSTGRES_15
  # - Cloud SQL Unix socket enabled
  # - GCS volume for filestore
  # - Environment variables
  # - Resource limits (2 CPU, 4Gi RAM)
  # - PostgreSQL extensions
}
```

### With Manual Overrides

Use a preset but customize specific values:

```hcl
module "wordpress" {
  source = "./modules/WebApp"

  existing_project_id  = "my-project"
  tenant_deployment_id = "prod"
  network_name         = "my-vpc"

  application_name = "wordpress"

  # Use WordPress preset
  application_preset = "wordpress"

  # Override specific values
  container_image = "wordpress:6.7.0-apache"  # Use older version
  container_resources = {
    cpu_limit    = "2000m"  # More CPU than default
    memory_limit = "4Gi"    # More RAM than default
  }
  max_instance_count = 50  # Scale higher than default

  # Add custom environment variables (merged with preset)
  environment_variables = {
    WP_DEBUG = "true"
    WP_CACHE = "true"
  }
}
```

## Preset Details

### Odoo ERP

**Use Case**: Enterprise Resource Planning - CRM, e-commerce, accounting, manufacturing

```hcl
application_preset = "odoo"
```

**What's Configured**:
- Container: `odoo:18.0` on port 8069
- Database: PostgreSQL 15 with Unix socket (`/var/run/postgresql`)
- Storage: GCS volume at `/var/lib/odoo/filestore`
- Resources: 2 CPU, 4Gi RAM
- Scaling: 1-10 instances
- Environment: `DB_HOST=/var/run/postgresql`, `DB_PORT=5432`

**Best For**: Medium to large businesses needing comprehensive ERP

---

### WordPress CMS

**Use Case**: Content management, blogs, marketing websites

```hcl
application_preset = "wordpress"
```

**What's Configured**:
- Container: `wordpress:6.8.1-apache` on port 80
- Database: MySQL 8.0 with Unix socket (`/var/run/mysqld/mysqld.sock`)
- Storage: GCS volume at `/var/www/html/wp-content/uploads`
- Resources: 1 CPU, 2Gi RAM
- Scaling: 1-20 instances (high scale for traffic spikes)
- Environment: `WORDPRESS_DB_HOST=localhost:/var/run/mysqld/mysqld.sock`

**Best For**: Marketing sites, blogs, content-heavy websites

---

### Moodle LMS

**Use Case**: Online learning, course management, education platforms

```hcl
application_preset = "moodle"
```

**What's Configured**:
- Container: `moodle:4.3-apache` on port 80
- Database: MySQL 8.0 with Unix socket
- Storage: GCS volume at `/var/moodledata`
- Resources: 2 CPU, 4Gi RAM
- Scaling: 1-10 instances
- Environment: `MOODLE_DATABASE_TYPE=mysqli`, `MOODLE_DATABASE_HOST=/var/run/mysqld/mysqld.sock`

**Best For**: Educational institutions, corporate training, e-learning

---

### Cyclos Banking

**Use Case**: Online banking, community currencies, financial systems

```hcl
application_preset = "cyclos"
```

**What's Configured**:
- Container: `cyclos/cyclos:4.16.15` on port 8080
- Database: PostgreSQL 15 with Unix socket + extensions (pg_trgm, uuid-ossp)
- Storage: GCS volume at `/usr/local/cyclos/data`
- Resources: 2 CPU, 4Gi RAM
- Scaling: 1-10 instances
- Environment: `DB_HOST=/var/run/postgresql`, `CYCLOS_HOME=/usr/local/cyclos`

**Best For**: Financial institutions, community banks, alternative currencies

---

### Django Web Framework

**Use Case**: Python web applications with custom logic

```hcl
application_preset = "django"
```

**What's Configured**:
- Container: `python:3.11-slim` on port 8000 (⚠️ requires custom image)
- Database: PostgreSQL 15 with Unix socket + extensions (pg_trgm, unaccent, hstore, citext)
- Storage: Two GCS volumes - `/app/static` and `/app/media`
- Resources: 2 CPU, 2Gi RAM
- Scaling: 1-10 instances
- Environment: `DJANGO_SETTINGS_MODULE`, `DEBUG=False`, `DB_ENGINE=django.db.backends.postgresql`

**Best For**: Custom web applications, APIs, data-driven sites

**Note**: You must override `container_image` with your custom Django application image.

---

### OpenEMR - Electronic Health Records

**Use Case**: Healthcare, medical practice management, patient records

```hcl
application_preset = "openemr"
```

**What's Configured**:
- Container: `openemr/openemr:7.0.2` on port 80
- Database: MySQL 8.0 with Unix socket
- Storage: GCS volume at `/var/www/localhost/htdocs/openemr/sites`
- Resources: 2 CPU, 4Gi RAM
- Scaling: 1-10 instances
- Environment: `MYSQL_HOST=localhost:/var/run/mysqld/mysqld.sock`

**Best For**: Medical clinics, hospitals, healthcare providers

---

### n8n Workflow Automation

**Use Case**: Workflow automation, integration, no-code/low-code automations

```hcl
application_preset = "n8n"
```

**What's Configured**:
- Container: `n8nio/n8n:latest` on port 5678
- Database: PostgreSQL 15 with Unix socket
- Storage: GCS volume at `/home/node/.n8n`
- Resources: 2 CPU, 4Gi RAM
- Scaling: 1-10 instances
- Environment: `DB_TYPE=postgresdb`, `N8N_USER_MANAGEMENT_DISABLED=false`, timezone settings

**Best For**: Business process automation, API integrations, data workflows

**Note**: For AI-powered n8n with Qdrant and Ollama, use the `N8N_AI_WebApp` wrapper module instead.

---

### Nextcloud - File Sync and Share

**Use Case**: Self-hosted file storage, collaboration, document management

```hcl
application_preset = "nextcloud"
```

**What's Configured**:
- Container: `nextcloud:28-apache` on port 80
- Database: PostgreSQL 15 with Unix socket
- Storage: Two GCS volumes - `/var/www/html/data` and `/var/www/html/config`
- Resources: 2 CPU, 4Gi RAM
- Scaling: 1-10 instances
- Environment: `POSTGRES_HOST=/var/run/postgresql`

**Best For**: Team collaboration, file sharing, document management

---

### GitLab - DevOps Platform

**Use Case**: Git repository management, CI/CD, DevOps workflows

```hcl
application_preset = "gitlab"
```

**What's Configured**:
- Container: `gitlab/gitlab-ce:16.8.0-ce.0` on port 80
- Database: PostgreSQL 15 with Unix socket + extensions (pg_trgm, btree_gist)
- Storage: Two GCS volumes - `/var/opt/gitlab` and `/etc/gitlab`
- Resources: 4 CPU, 8Gi RAM (GitLab needs more resources)
- Scaling: 1-5 instances
- Environment: `GITLAB_OMNIBUS_CONFIG`

**Best For**: Development teams, source code management, CI/CD pipelines

**Note**: GitLab requires significantly more resources than other applications.

## How Presets Work

### Architecture

```
User Configuration
       ↓
application_preset = "odoo"
       ↓
presets.tf (Preset Definitions)
       ↓
Local Variables (final_*)
       ↓
Module Resources
```

### Preset Selection Logic

1. **Preset Defined**: User sets `application_preset = "odoo"`
2. **Lookup**: Module looks up "odoo" in preset definitions
3. **Smart Defaults**: Module applies preset values where manual values aren't provided
4. **Manual Override**: Any manually specified value takes precedence
5. **Merge**: Environment variables from preset and manual are merged

### Override Priority

```
Manual Configuration (highest priority)
         ↓
Preset Configuration
         ↓
Module Defaults (lowest priority)
```

**Example**:
```hcl
application_preset = "wordpress"      # Preset: MySQL 8.0
database_type = "MYSQL_5_7"          # Manual: Overrides to MySQL 5.7

# Result: MySQL 5.7 is used (manual override wins)
```

## Advanced Usage

### Multi-Environment Deployment

Deploy the same application with different presets per environment:

```hcl
locals {
  environment_configs = {
    dev = {
      preset = "wordpress"
      resources = {
        cpu_limit    = "500m"
        memory_limit = "1Gi"
      }
      max_instances = 3
    }
    prod = {
      preset = "wordpress"
      resources = {
        cpu_limit    = "2000m"
        memory_limit = "4Gi"
      }
      max_instances = 50
    }
  }
}

module "wordpress" {
  source = "./modules/WebApp"

  existing_project_id  = var.project_id
  tenant_deployment_id = var.environment
  application_name     = "wordpress"

  # Use preset with environment-specific overrides
  application_preset = local.environment_configs[var.environment].preset

  container_resources = local.environment_configs[var.environment].resources
  max_instance_count  = local.environment_configs[var.environment].max_instances
}
```

### Custom Image with Preset Configuration

Use preset for configuration but provide custom image:

```hcl
module "custom_odoo" {
  source = "./modules/WebApp"

  existing_project_id  = "my-project"
  tenant_deployment_id = "prod"
  application_name     = "odoo"

  # Use Odoo preset for all configuration
  application_preset = "odoo"

  # But use custom-built image
  container_image = "gcr.io/my-project/custom-odoo:v2.0"

  # Preset still configures:
  # - Port 8069
  # - PostgreSQL 15
  # - Cloud SQL Unix socket
  # - GCS volumes
  # - Environment variables
  # - Resource limits
}
```

### Mixing Presets with Advanced Features

Combine presets with backup import, custom SQL scripts, etc.:

```hcl
module "wordpress_with_backup" {
  source = "./modules/WebApp"

  existing_project_id  = "my-project"
  tenant_deployment_id = "prod"
  application_name     = "wordpress"

  # Use WordPress preset
  application_preset = "wordpress"

  # Add backup import (not in preset)
  enable_backup_import = true
  backup_source        = "gcs"
  backup_uri           = "gs://my-backups/wordpress-prod.sql.gz"
  backup_format        = "sql"

  # Add custom SQL scripts (not in preset)
  enable_custom_sql_scripts   = true
  custom_sql_scripts_bucket   = "my-init-scripts"
  custom_sql_scripts_path     = "wordpress/"

  # Preset still handles container image, port, database type, etc.
}
```

## Troubleshooting

### Preset Not Found

**Error**: `Application preset must be one of: odoo, wordpress, ...`

**Solution**: Check spelling of preset name. Valid values are: `odoo`, `wordpress`, `moodle`, `cyclos`, `django`, `openemr`, `n8n`, `nextcloud`, `gitlab`.

### Container Image Not Working

**Problem**: Application doesn't start with preset container image

**Solutions**:
1. **Override Image**: Use a specific version
   ```hcl
   application_preset = "wordpress"
   container_image    = "wordpress:6.7.0-apache"  # Specific version
   ```

2. **Custom Image**: Provide your own image
   ```hcl
   application_preset = "odoo"
   container_image    = "gcr.io/my-project/odoo:custom"
   ```

### Need Different Database Version

**Problem**: Preset uses PostgreSQL 15 but need PostgreSQL 14

**Solution**: Override the database_type:
```hcl
application_preset = "odoo"
database_type      = "POSTGRES_14"  # Override preset
```

### Need More/Less Resources

**Problem**: Preset resource limits too high/low

**Solution**: Override resource configuration:
```hcl
application_preset = "wordpress"

# Override resources
container_resources = {
  cpu_limit    = "500m"   # Less than preset
  memory_limit = "1Gi"    # Less than preset
}
```

### Custom Environment Variables

**Problem**: Need additional environment variables

**Solution**: Add them - they merge with preset variables:
```hcl
application_preset = "wordpress"

# These merge with preset environment variables
environment_variables = {
  WP_DEBUG        = "true"
  WP_CACHE        = "true"
  CUSTOM_API_KEY  = "abc123"
}
```

## Comparison: Manual vs Preset

### Manual Configuration (Old Way)

```hcl
module "wordpress" {
  source = "./modules/WebApp"

  existing_project_id  = "my-project"
  tenant_deployment_id = "prod"
  network_name         = "my-vpc"
  application_name     = "wordpress"

  # Must configure everything manually
  container_image = "wordpress:6.8.1-apache"
  container_port  = 80
  database_type   = "MYSQL_8_0"

  enable_cloudsql_volume     = true
  cloudsql_volume_mount_path = "/var/run/mysqld"

  gcs_volumes = [{
    bucket     = "prod-wp-uploads"
    mount_path = "/var/www/html/wp-content/uploads"
    read_only  = false
  }]

  container_resources = {
    cpu_limit    = "1000m"
    memory_limit = "2Gi"
  }

  min_instance_count = 1
  max_instance_count = 20

  environment_variables = {
    WORDPRESS_DB_HOST      = "localhost:/var/run/mysqld/mysqld.sock"
    WORDPRESS_TABLE_PREFIX = "wp_"
    WORDPRESS_DEBUG        = "false"
  }
}

# Total: ~35 lines of configuration
```

### Preset Configuration (New Way)

```hcl
module "wordpress" {
  source = "./modules/WebApp"

  existing_project_id  = "my-project"
  tenant_deployment_id = "prod"
  network_name         = "my-vpc"
  application_name     = "wordpress"

  # Just select the preset!
  application_preset = "wordpress"
}

# Total: ~10 lines of configuration
# 70% less code, same result!
```

## Best Practices

### 1. Use Presets for Standard Deployments

✅ **Do**: Use presets for standard application deployments
```hcl
application_preset = "odoo"
```

❌ **Don't**: Manually configure everything when a preset exists
```hcl
container_image = "odoo:18.0"  # Preset already does this
container_port  = 8069         # Preset already does this
# ... etc
```

### 2. Override Only When Needed

✅ **Do**: Override specific values that differ from preset
```hcl
application_preset = "wordpress"
container_image    = "wordpress:6.7.0"  # Need older version
```

❌ **Don't**: Override values that match the preset
```hcl
application_preset = "wordpress"
container_port     = 80  # Unnecessary - preset already uses 80
```

### 3. Document Custom Configurations

✅ **Do**: Add comments explaining why you override preset values
```hcl
application_preset = "odoo"
# Using Odoo 17 for compatibility with legacy integrations
container_image = "odoo:17.0"
```

### 4. Start with Presets, Customize Later

✅ **Do**: Deploy with preset first, then customize based on actual needs
```hcl
# Day 1: Use preset
application_preset = "wordpress"

# Day 30: Add customizations based on usage
container_resources = { cpu_limit = "2000m", memory_limit = "4Gi" }
max_instance_count  = 50
```

### 5. Use Presets for Multiple Environments

✅ **Do**: Use same preset across dev/staging/prod with environment-specific overrides
```hcl
application_preset = "moodle"  # Same in all environments

# Environment-specific scaling
max_instance_count = var.environment == "prod" ? 20 : 5
```

## Limitations

1. **Fixed Configurations**: Presets use specific container images and versions
   - **Workaround**: Override `container_image` to use different versions

2. **Standard Topologies**: Presets assume single-service deployments
   - **Workaround**: For multi-service (e.g., N8N + Qdrant + Ollama), use wrapper modules like `N8N_AI_WebApp`

3. **Generic Environment Variables**: Preset environment variables are generic
   - **Workaround**: Add application-specific variables using `environment_variables`

4. **Limited Applications**: Only 9 presets currently available
   - **Workaround**: Use manual configuration for applications without presets

## Adding New Presets

Module maintainers can add new presets by editing `modules/WebApp/presets.tf`:

```hcl
locals {
  application_presets = {
    # ... existing presets ...

    # New preset
    myapp = {
      description     = "My Application Description"
      container_image = "myapp:latest"
      container_port  = 3000
      database_type   = "POSTGRES_15"

      enable_cloudsql_volume     = true
      cloudsql_volume_mount_path = "/cloudsql"

      gcs_volumes = [{
        bucket     = "$${tenant_id}-myapp-data"
        mount_path = "/data"
        read_only  = false
      }]

      container_resources = {
        cpu_limit    = "1000m"
        memory_limit = "2Gi"
      }
      min_instance_count = 1
      max_instance_count = 10

      environment_variables = {
        APP_PORT = "3000"
      }

      enable_postgres_extensions = false
      postgres_extensions         = []
    }
  }
}
```

Don't forget to update the validation in `variables.tf`:
```hcl
variable "application_preset" {
  # ...
  validation {
    condition = var.application_preset == null || contains([
      "odoo", "wordpress", "moodle", "cyclos", "django",
      "openemr", "n8n", "nextcloud", "gitlab", "myapp"  # Add new preset
    ], var.application_preset)
    error_message = "Application preset must be one of: ..."
  }
}
```

## Summary

Application Presets make deploying popular applications with WebApp dramatically simpler:

- **70% less configuration** for standard deployments
- **Best practice settings** included by default
- **Full override capability** when customization needed
- **Consistent deployments** across environments
- **Easy maintenance** - preset updates benefit all users

For applications without presets, the existing manual configuration approach still works perfectly - presets are completely optional and backward compatible.
