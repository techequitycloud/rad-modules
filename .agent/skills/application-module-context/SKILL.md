---
name: application-module-context
description: Understand how to work with Application Modules (e.g. Cyclos)
---

# Application Module Context

Application modules (like `Cyclos`, `Wordpress`, `Moodle`) are specialized modules that deploy specific applications using the `CloudRunApp` foundation.

## Pattern and Structure

1.  **Directory**: Located in `modules/<AppName>` (PascalCase).
2.  **Symlinks**: Most Terraform files (`main.tf`, `variables.tf`, `service.tf`, etc.) are symlinks to `../CloudRunApp/`. This means the logic is inherited from the foundation module.
3.  **Specific Configuration**: There is usually one unique `.tf` file (e.g., `cyclos.tf` for Cyclos) that defines the application-specific configuration.

## Required Directory Structure

Each application module MUST follow this structure (from `modules/AGENTS.md`):

```
modules/<AppName>/
├── README.md                           # 30-50 line overview
├── <APPNAME>.md                        # 85-120 line detailed guide
├── variables.tf                        # MUST mirror CloudRunApp variables
├── <appname>.tf                        # Application-specific configuration
├── config/
│   ├── basic-<appname>.tfvars
│   ├── advanced-<appname>.tfvars
│   └── custom-<appname>.tfvars
├── scripts/
│   ├── core -> ../../CloudRunApp/scripts/core  # Symlink
│   └── <appname>/                      # Build context
│       ├── Dockerfile
│       ├── entrypoint.sh (optional)
│       └── [application files]
└── [18 symlinked .tf files]            # See below
```

### Required Symlinks (18 files)

All application modules MUST symlink these files from `../CloudRunApp/`:

1.  `buildappcontainer.tf`
2.  `iam.tf`
3.  `jobs.tf`
4.  `main.tf`
5.  `modules.tf`
6.  `monitoring.tf`
7.  `network.tf`
8.  `nfs.tf`
9.  `outputs.tf`
10. `provider-auth.tf`
11. `registry.tf`
12. `sa.tf`
13. `secrets.tf`
14. `service.tf`
15. `sql.tf`
16. `storage.tf`
17. `trigger.tf`
18. `versions.tf`

**Create symlinks**:
```bash
cd modules/YourApp
ln -s ../CloudRunApp/main.tf main.tf
ln -s ../CloudRunApp/variables.tf variables.tf
# ... repeat for all 18 files
```

Or use `scripts/create_module.sh` which handles this automatically.

## Complete Module Configuration Schema

In `<appname>.tf`, define a comprehensive configuration using this schema:

```hcl
locals {
  <appname>_module = {
    # ===== BASIC IDENTITY =====
    app_name              = "appname"           # Lowercase, used for resource names
    display_name          = "App Display Name" # User-friendly name
    description           = "Purpose and functionality of this application"
    application_version   = var.application_version

    # ===== IMAGE CONFIGURATION =====
    # Set container_image to empty string "" for custom builds
    # Or specify prebuilt image like "wordpress:latest"
    container_image       = ""
    image_source          = "custom"  # "custom", "prebuilt", or "build"
    container_port        = 8080      # Port your app listens on

    # ===== CUSTOM BUILD CONFIGURATION =====
    # Only used when image_source = "custom"
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "<appname>"  # CRITICAL: MUST match scripts/<appname>/
      dockerfile_content = null         # Or inline Dockerfile as string
      build_args         = {
        # Build-time arguments passed to Dockerfile
        APP_VERSION = var.application_version
        BUILD_ENV   = "production"
      }
      artifact_repo_name = null  # Or specify custom Artifact Registry repo
    }

    # ===== DATABASE CONFIGURATION =====
    database_type        = "POSTGRES_15"  # "POSTGRES_15", "MYSQL_8_0", or null
    db_name              = "appdb"
    db_user              = "appuser"
    db_tier              = "db-custom-1-3840"  # Cloud SQL machine type

    # PostgreSQL-specific
    enable_postgres_extensions = true
    postgres_extensions = [
      "pg_trgm",      # Trigram matching for fuzzy search
      "unaccent",     # Remove accents from text
      "uuid-ossp",    # UUID generation
      # Add others as needed
    ]

    # MySQL-specific
    enable_mysql_plugins = false
    mysql_plugins = []

    # ===== STORAGE CONFIGURATION =====

    # Cloud SQL Volume (usually false, use private IP instead)
    enable_cloudsql_volume     = false
    cloudsql_volume_mount_path = "/cloudsql"

    # NFS Filestore
    nfs_enabled    = true   # For shared persistent storage
    nfs_mount_path = "/mnt"

    # GCS Volumes (Fuse mounting)
    gcs_volumes = [
      {
        name              = "uploads"
        mount_path        = "/app/uploads"
        bucket_name_suffix = "uploads"
        readonly          = false
      },
      {
        name              = "static"
        mount_path        = "/app/static"
        bucket_name_suffix = "static"
        readonly          = true
      }
    ]

    # ===== RESOURCE CONFIGURATION =====
    container_resources = {
      cpu_limit    = "1000m"  # 1 vCPU (1000m) or 2 vCPU (2000m)
      memory_limit = "2Gi"    # 512Mi, 1Gi, 2Gi, 4Gi
    }

    # Scaling
    min_instance_count = 0  # 0 = scale to zero when idle
    max_instance_count = 3  # Maximum instances

    # ===== HEALTH CHECK CONFIGURATION =====
    startup_probe = {
      enabled                = true
      type                   = "http"  # "http", "tcp", or "grpc"
      path                   = "/health"
      initial_delay_seconds  = 30
      timeout_seconds        = 5
      period_seconds         = 10
      failure_threshold      = 3
    }

    liveness_probe = {
      enabled         = true
      type            = "http"
      path            = "/health"
      timeout_seconds = 5
      period_seconds  = 30
      failure_threshold = 3
    }

    # ===== ENVIRONMENT VARIABLES (DEFAULTS) =====
    environment_variables = {
      LOG_LEVEL         = "info"
      ENVIRONMENT       = "production"
      TZ                = "UTC"
      # Add application-specific environment variables
      # Use module_env_vars (below) for dynamic values from Terraform
    }

    # ===== INITIALIZATION JOBS =====
    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Initialize database schema and create users"
        image           = null  # null = use app image; or specify custom

        # ✅ NEW: Use script_path for external shell scripts
        script_path     = "${path.module}/scripts/<appname>/db-init.sh"

        # NOTE: command and args are automatically handled when script_path is provided
        # The framework will: command = ["/bin/sh"], args = ["-c", file(script_path)]

        # Resource limits for job
        timeout_seconds = 600
        max_retries     = 3

        # Volume mounts (same options as service)
        mount_nfs           = true
        mount_gcs_volumes   = ["uploads"]
        mount_cloudsql      = false

        # Execution control
        execute_on_apply   = true  # true = run on every apply; false = only once

        # Custom environment variables (inherits service vars)
        env_vars = {
          MIGRATION_MODE = "safe"
        }
      },
      {
        name            = "install-extensions"
        description     = "Install required PostgreSQL extensions"
        image           = "postgres:15-alpine"

        # ✅ NEW: Use script_path for external shell scripts
        script_path     = "${path.module}/scripts/<appname>/install-extensions.sh"

        execute_on_apply = false  # Run only on initial creation
      }
    ]

    # ============================================================================
    # External Script Files
    # ============================================================================
    #
    # Create script files in: scripts/<appname>/db-init.sh
    #
    # Example: scripts/<appname>/db-init.sh
    # #!/bin/bash
    # set -e
    # echo "Running database migrations..."
    # python manage.py migrate
    # echo "Creating initial data..."
    # python manage.py loaddata initial_data.json
    # echo "Database initialization complete"
    #
    # Example: scripts/<appname>/install-extensions.sh
    # #!/bin/bash
    # set -e
    # psql -h $DB_HOST -U postgres -d $DB_NAME <<SQL
    #   CREATE EXTENSION IF NOT EXISTS pg_trgm;
    #   CREATE EXTENSION IF NOT EXISTS unaccent;
    #   CREATE EXTENSION IF NOT EXISTS uuid-ossp;
    # SQL

    # ===== STORAGE BUCKETS =====
    storage_buckets = [
      {
        name_suffix              = "uploads"
        location                 = var.deployment_region
        storage_class            = "STANDARD"  # STANDARD, NEARLINE, COLDLINE
        force_destroy            = true
        versioning_enabled       = false
        public_access_prevention = "inherited"  # "inherited" or "enforced"
        lifecycle_rules          = []
      },
      {
        name_suffix              = "backups"
        location                 = var.deployment_region
        storage_class            = "NEARLINE"
        force_destroy            = false
        versioning_enabled       = true
        public_access_prevention = "enforced"
      }
    ]

    # ===== NETWORKING =====
    vpc_egress_setting = "PRIVATE_RANGES_ONLY"  # or "ALL_TRAFFIC"
    ingress_settings   = "all"                  # "all", "internal", "internal-and-cloud-load-balancing"

    # ===== MONITORING & ALERTS =====
    enable_monitoring = true
    alert_policies = [
      {
        display_name = "High Error Rate"
        conditions   = [...]
        notification_channels = []
      }
    ]
  }

  # ===== MODULE REGISTRATION =====
  # CloudRunApp reads this map to get configuration
  application_modules = {
    <appname> = local.<appname>_module
  }

  # ===== DYNAMIC ENVIRONMENT VARIABLES =====
  # Map Terraform-computed values to environment variables
  module_env_vars = {
    # Database connection
    DB_HOST     = local.db_internal_ip
    DB_PORT     = local.db_port
    DB_NAME     = local.db_name
    DB_USER     = local.db_user

    # Redis connection (if used)
    REDIS_HOST  = local.redis_host
    REDIS_PORT  = local.redis_port

    # Storage
    GCS_BUCKET  = local.uploads_bucket_name

    # Application URLs
    APP_URL     = "https://${var.service_name}-${var.deployment_region}.a.run.app"
  }

  # ===== SECRET ENVIRONMENT VARIABLES =====
  # Map Secret Manager secrets to environment variables
  module_secret_env_vars = {
    DB_PASSWORD           = google_secret_manager_secret.db_password[0].secret_id
    SECRET_KEY            = google_secret_manager_secret.app_secret[0].secret_id
    API_KEY               = google_secret_manager_secret.api_key[0].secret_id
    # Add other secrets as needed
  }

  # ===== STORAGE BUCKETS LIST =====
  # Pass storage bucket configuration to CloudRunApp
  module_storage_buckets = local.<appname>_module.storage_buckets
}
```

## Build Context Requirements (CRITICAL)

### Directory Structure

The build context directory MUST exist at `scripts/<appname>/`:

```
modules/<AppName>/scripts/<appname>/
├── Dockerfile                    # Required for custom builds
├── entrypoint.sh                 # Optional startup script
├── requirements.txt              # Python dependencies
├── package.json                  # Node.js dependencies
├── [application source files]    # Your app code
└── [configuration files]         # App-specific configs
```

### Critical Rules

**1. context_path MUST match directory name**:
```hcl
# If your module directory is:
modules/MyApp/scripts/myapp/

# Then context_path MUST be:
container_build_config = {
  context_path = "myapp"  # MUST match "myapp" directory
}
```

**Mismatch causes build failure**:
```
ERROR: context_path 'my-app' does not exist in scripts/
```

**2. Dockerfile location**:
*   Default: `scripts/<appname>/Dockerfile`
*   Override with `dockerfile_path` if needed
*   Or provide `dockerfile_content` as inline string

**3. Build user UID for GCS Fuse**:

If using GCS volumes, container MUST run as UID 2000:

```dockerfile
FROM python:3.11-slim

# GCS Fuse requires UID 2000
RUN useradd -m -u 2000 appuser

WORKDIR /app

# Install dependencies as root
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

EXPOSE 8080
CMD ["python", "app.py"]
```

**4. Symlink scripts/core**:

Always create this symlink:
```bash
cd modules/YourApp/scripts
ln -s ../../CloudRunApp/scripts/core core
```

This provides access to shared maintenance scripts.

### Example Dockerfile Patterns

**Python (Django/Flask)**:
```dockerfile
FROM python:3.11-slim

# System dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Create user with UID 2000 for GCS Fuse
RUN useradd -m -u 2000 appuser

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY --chown=appuser:appuser . .

# Collect static files (Django)
RUN python manage.py collectstatic --noinput

USER appuser
EXPOSE 8080

# Use gunicorn for production
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "myapp.wsgi:application"]
```

**Node.js**:
```dockerfile
FROM node:18-slim

# Create user with UID 2000
RUN useradd -m -u 2000 appuser

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy application
COPY --chown=appuser:appuser . .

USER appuser
EXPOSE 8080

CMD ["node", "server.js"]
```

**PHP (WordPress)**:
```dockerfile
FROM wordpress:6.4-php8.2-apache

# Install additional extensions
RUN docker-php-ext-install opcache

# Create user with UID 2000
RUN useradd -m -u 2000 appuser || true
RUN chown -R appuser:appuser /var/www/html

# Apache runs as appuser
RUN sed -i 's/User .*/User appuser/' /etc/apache2/apache2.conf
RUN sed -i 's/Group .*/Group appuser/' /etc/apache2/apache2.conf

EXPOSE 8080
```

## Image Source Strategies

Application modules support three image source strategies:

### 1. Custom Build (`image_source = "custom"`)

**Most Common Pattern** - Used by: Django, Sample, Ghost, Medusa, Strapi, N8N, Moodle, OpenEMR, Directus, Wikijs

**Configuration**:
```hcl
container_image = ""  # Empty string for custom build
image_source    = "custom"

container_build_config = {
  enabled            = true
  dockerfile_path    = "Dockerfile"
  context_path       = "myapp"
  dockerfile_content = null
  build_args         = {}
}
```

**Build Process**:
1.  Cloud Build reads Dockerfile from `scripts/myapp/Dockerfile`
2.  Builds image with context from `scripts/myapp/`
3.  Pushes to Artifact Registry
4.  Cloud Run deploys the custom image

**When to Use**:
*   Application requires custom configuration
*   Need to install specific dependencies
*   Want to bundle application code in image
*   Application not available as prebuilt image

### 2. Prebuilt Image (`image_source = "prebuilt"`)

**Public Registry** - Used by: Wordpress, Cyclos (optional)

**Configuration**:
```hcl
container_image = "wordpress:6.4-php8.2"  # From Docker Hub
# Or: "gcr.io/cloudrun/hello"
# Or: "us-docker.pkg.dev/my-project/my-repo/my-image:tag"

image_source = "prebuilt"

container_build_config = {
  enabled = false  # No build needed
}
```

**When to Use**:
*   Official images available (WordPress, PostgreSQL, etc.)
*   No customization needed
*   Faster deployment (no build time)
*   Trust the upstream maintainer

**Image Sources**:
*   Docker Hub: `wordpress:latest`
*   Google Container Registry: `gcr.io/project/image`
*   Artifact Registry: `us-docker.pkg.dev/project/repo/image`

### 3. Build from Source (`image_source = "build"`)

**Alternative Build** - Used by: Cyclos, Odoo

**Configuration**:
```hcl
container_image = ""
image_source    = "build"

container_build_config = {
  enabled            = true
  dockerfile_path    = "Dockerfile"
  context_path       = "myapp"
  # Different build process or base images
}
```

**When to Use**:
*   Similar to custom but with different build configuration
*   Multi-stage builds
*   Complex build requirements

### Choosing an Image Source

| Scenario | Recommended Strategy | Why |
|----------|---------------------|-----|
| Official app available | Prebuilt | Fastest, no build time |
| Need customization | Custom | Full control over build |
| Complex build process | Build | Multi-stage builds supported |
| Internal application | Custom | Bundle source code |
| Rapid prototyping | Prebuilt | Quick deployment |

## Variables.tf Requirements

### Critical Rule: Mirror CloudRunApp Variables

Your `variables.tf` MUST mirror the structure from `modules/CloudRunApp/variables.tf`.

**Rules**:
1.  **Do NOT remove standard variables** unless functionally impossible to support
2.  **Preserve variable order** using UIMeta tags (see below)
3.  **Add module-specific variables** at the end, or use `environment_variables` map
4.  **Maintain all UIMeta tags** for UI rendering
5.  **Keep descriptions** accurate and helpful

### Variable Ordering (Standard Order)

Variables MUST be ordered using the `order` field in UIMeta tags:

*   **Order 100**: Basic Configuration (project_id, region, service_name, application_version)
*   **Order 200**: CI/CD (github_repository_url, enable_cicd_trigger, github_branch_pattern)
*   **Order 300**: Container Resources (cpu_limit, memory_limit, min_instances, max_instances)
*   **Order 400**: Storage & Data (nfs_server, gcs_volumes, enable_cloudsql_volume)
*   **Order 500**: Environment Variables (environment_variables, secret_environment_variables)
*   **Order 600**: Health Checks (startup_probe_config, liveness_probe_config)
*   **Order 700**: Monitoring (alert_policies, trusted_users, enable_monitoring)
*   **Order 800**: Initialization Jobs (initialization_jobs)
*   **Order 900**: Network & Security (vpc_egress_setting, ingress_settings)
*   **Order 1000**: Database Extensions & Backup (postgres_extensions, enable_backup_import)

### UIMeta Tag Format

UIMeta tags are comments that control UI rendering:

```hcl
# {{UIMeta group=0 order=100 updatesafe=false}}
variable "project_id" {
  description = "The GCP project ID where resources will be created"
  type        = string
}

# {{UIMeta group=0 order=200 updatesafe=true}}
variable "github_repository_url" {
  description = "GitHub repository URL for CI/CD integration"
  type        = string
  default     = ""
}

# {{UIMeta group=0 order=300 updatesafe=true}}
variable "container_resources" {
  description = "Container resource limits (CPU and memory)"
  type = object({
    cpu_limit    = string
    memory_limit = string
  })
  default = {
    cpu_limit    = "1000m"
    memory_limit = "2Gi"
  }
}
```

**UIMeta Parameters**:
*   `group`: Grouping for UI (usually 0)
*   `order`: Display order (100, 200, 300, etc.)
*   `updatesafe`: Can be modified after initial deployment?
    *   `false`: Only set during creation (project_id, service_name)
    *   `true`: Can be updated later (resources, environment vars)

### Module-Specific Variables

Add module-specific variables at the end with high order numbers:

```hcl
# {{UIMeta group=0 order=1100}}
variable "wordpress_admin_email" {
  description = "WordPress administrator email address"
  type        = string
  default     = "admin@example.com"
}

# {{UIMeta group=0 order=1200}}
variable "wordpress_plugins" {
  description = "List of WordPress plugins to install"
  type        = list(string)
  default     = []
}
```

**Best Practice**: Use `environment_variables` map instead when possible:

```hcl
# Instead of creating new variables, use environment_variables:
environment_variables = {
  WORDPRESS_ADMIN_EMAIL = var.admin_email
  WORDPRESS_PLUGINS     = join(",", var.plugins)
}
```

## How to Create/Modify an Application Module

### Option 1: Use create_module.sh Script (Recommended)

```bash
cd rad-modules/scripts
./create_module.sh

# Follow prompts:
# 1. Select source module to clone (e.g., Django)
# 2. Enter new module name (PascalCase, e.g., MyApp)
# 3. Script handles:
#    - Cloning all files and preserving symlinks
#    - Renaming files (django.tf -> myapp.tf)
#    - Replacing all references (Django -> MyApp, django -> myapp)
#    - Cleaning up artifacts
#    - Validating structure
```

### Option 2: Manual Creation

**1. Create Directory**:
```bash
mkdir -p modules/MyApp
cd modules/MyApp
```

**2. Create Symlinks** (18 required files):
```bash
ln -s ../CloudRunApp/buildappcontainer.tf buildappcontainer.tf
ln -s ../CloudRunApp/iam.tf iam.tf
ln -s ../CloudRunApp/jobs.tf jobs.tf
ln -s ../CloudRunApp/main.tf main.tf
ln -s ../CloudRunApp/modules.tf modules.tf
ln -s ../CloudRunApp/monitoring.tf monitoring.tf
ln -s ../CloudRunApp/network.tf network.tf
ln -s ../CloudRunApp/nfs.tf nfs.tf
ln -s ../CloudRunApp/outputs.tf outputs.tf
ln -s ../CloudRunApp/provider-auth.tf provider-auth.tf
ln -s ../CloudRunApp/registry.tf registry.tf
ln -s ../CloudRunApp/sa.tf sa.tf
ln -s ../CloudRunApp/secrets.tf secrets.tf
ln -s ../CloudRunApp/service.tf service.tf
ln -s ../CloudRunApp/sql.tf sql.tf
ln -s ../CloudRunApp/storage.tf storage.tf
ln -s ../CloudRunApp/trigger.tf trigger.tf
ln -s ../CloudRunApp/versions.tf versions.tf
```

**3. Copy variables.tf**:
```bash
cp ../CloudRunApp/variables.tf variables.tf
# Edit as needed, maintaining structure
```

**4. Create Application Configuration** (`myapp.tf`):
```hcl
# myapp.tf
locals {
  myapp_module = {
    app_name        = "myapp"
    display_name    = "My Application"
    description     = "Description of my application"
    container_image = ""
    image_source    = "custom"
    container_port  = 8080

    container_build_config = {
      enabled         = true
      dockerfile_path = "Dockerfile"
      context_path    = "myapp"  # MUST match scripts/myapp/
    }

    database_type = "POSTGRES_15"
    # ... rest of configuration
  }

  application_modules = {
    myapp = local.myapp_module
  }

  module_env_vars = {
    DB_HOST = local.db_internal_ip
    # ... environment variables
  }

  module_secret_env_vars = {
    DB_PASSWORD = google_secret_manager_secret.db_password[0].secret_id
    # ... secrets
  }

  module_storage_buckets = local.myapp_module.storage_buckets
}
```

**5. Create Build Context**:
```bash
mkdir -p scripts/myapp
cd scripts/myapp
ln -s ../../CloudRunApp/scripts/core ../core

# Create Dockerfile
cat > Dockerfile <<'EOF'
FROM python:3.11-slim

RUN useradd -m -u 2000 appuser

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=appuser:appuser . .

USER appuser
EXPOSE 8080
CMD ["python", "app.py"]
EOF

# Create application files
cat > requirements.txt <<'EOF'
flask==3.0.0
gunicorn==21.2.0
psycopg2-binary==2.9.9
EOF

cat > app.py <<'EOF'
from flask import Flask
app = Flask(__name__)

@app.route('/health')
def health():
    return {'status': 'healthy'}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
EOF
```

**6. Create Configuration Files**:
```bash
mkdir -p config

cat > config/basic-myapp.tfvars <<'EOF'
resource_creator_identity = ""
existing_project_id       = "my-gcp-project"
tenant_deployment_id      = "dev"
deployment_region         = "us-central1"
application_version       = "1.0.0"
EOF
```

**7. Create Documentation**:
```bash
# README.md (30-50 lines)
cat > README.md <<'EOF'
# MyApp Module

Deploys MyApp application to Cloud Run with PostgreSQL database.

## Features
- Custom Python application
- PostgreSQL 15 database
- Automatic schema migrations
- Health check endpoints

## Dependencies
Requires GCP_Services module for VPC and Cloud SQL.
EOF

# MYAPP.md (85-120 lines detailed guide)
# ... comprehensive documentation
```

**8. Validate Structure**:
```bash
# Check symlinks
ls -la *.tf | grep '\->'

# Verify build context
ls scripts/myapp/Dockerfile

# Run Terraform validation
terraform init
terraform validate
terraform fmt -check -recursive
```

## Common Patterns and Best Practices

### Database Initialization

**PostgreSQL with Extensions**:
```hcl
initialization_jobs = [
  {
    name    = "install-extensions"
    image   = "postgres:15-alpine"

    # ✅ NEW: Use script_path for external scripts
    script_path = "${path.module}/scripts/<appname>/install-extensions.sh"

    execute_on_apply = false
  },
  {
    name    = "run-migrations"
    image   = null  # Use app image

    # ✅ NEW: Use script_path for external scripts
    script_path = "${path.module}/scripts/<appname>/run-migrations.sh"

    execute_on_apply = true
  }
]

# External script files:
# scripts/<appname>/install-extensions.sh:
# #!/bin/bash
# psql -h $DB_HOST -U postgres -d $DB_NAME <<SQL
#   CREATE EXTENSION IF NOT EXISTS pg_trgm;
#   CREATE EXTENSION IF NOT EXISTS unaccent;
# SQL
#
# scripts/<appname>/run-migrations.sh:
# #!/bin/bash
# python manage.py migrate
# python manage.py createsuperuser --noinput || true
```

### Multi-Volume Configuration

```hcl
gcs_volumes = [
  {
    name              = "uploads"
    mount_path        = "/app/uploads"
    bucket_name_suffix = "uploads"
    readonly          = false
  },
  {
    name              = "media"
    mount_path        = "/app/media"
    bucket_name_suffix = "media"
    readonly          = false
  }
]

# Also use NFS for shared data
nfs_enabled    = true
nfs_mount_path = "/mnt/shared"
```

### Environment Variable Organization

```hcl
# Static defaults in module configuration
environment_variables = {
  LOG_LEVEL    = "info"
  ENVIRONMENT  = "production"
  TZ           = "UTC"
}

# Dynamic values computed from Terraform
module_env_vars = {
  DB_HOST      = local.db_internal_ip
  DB_PORT      = local.db_port
  REDIS_URL    = "redis://${local.redis_host}:${local.redis_port}"
  APP_URL      = "https://${var.service_name}-${var.deployment_region}.a.run.app"
}

# Sensitive values from Secret Manager
module_secret_env_vars = {
  DB_PASSWORD  = google_secret_manager_secret.db_password[0].secret_id
  SECRET_KEY   = google_secret_manager_secret.app_secret[0].secret_id
  API_KEY      = google_secret_manager_secret.external_api_key[0].secret_id
}
```

### Resource Sizing Guidelines

| Application Type | CPU | Memory | Instances |
|-----------------|-----|--------|-----------|
| Simple API | 1000m | 512Mi | 0-3 |
| Web Application | 1000m | 2Gi | 0-5 |
| Heavy Processing | 2000m | 4Gi | 1-10 |
| Background Worker | 2000m | 2Gi | 1-3 |

```hcl
container_resources = {
  cpu_limit    = "1000m"  # 1 vCPU
  memory_limit = "2Gi"    # 2 GB RAM
}

min_instance_count = 0  # Scale to zero when idle
max_instance_count = 5  # Handle traffic spikes
```

## Troubleshooting Application Modules

### Build Failures

**Problem**: context_path error
```
Error: Build failed - context directory 'myapp' not found
```

**Solution**: Verify directory exists and context_path matches:
```bash
ls -la modules/MyApp/scripts/myapp/
# Update context_path in myapp.tf if needed
```

**Problem**: Dockerfile syntax errors
```
Error: failed to solve: failed to read dockerfile
```

**Solution**: Validate Dockerfile locally:
```bash
docker build -f scripts/myapp/Dockerfile scripts/myapp/
```

### Deployment Failures

**Problem**: Container exits immediately

**Solution**: Check logs and ensure CMD is correct:
```bash
gcloud run services logs read myapp --region us-central1 --limit=50
```

**Problem**: Health check failures

**Solution**: Verify health endpoint responds:
```hcl
startup_probe = {
  enabled                = true
  path                   = "/health"  # Ensure this endpoint exists
  initial_delay_seconds  = 60         # Increase if slow startup
}
```

### Permission Issues

**Problem**: Cannot access secrets

**Solution**: Verify IAM bindings in `iam.tf` and that secret exists:
```bash
gcloud secrets describe <secret-name>
gcloud projects get-iam-policy <project-id> \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:<sa-email>"
```

### Database Connection Issues

**Problem**: Cannot connect to Cloud SQL

**Solution**: Check VPC connector and private IP configuration:
```bash
# Verify VPC connector attached
gcloud run services describe myapp --region us-central1 \
  --format="value(template.vpcAccess.connector)"

# Check database configuration
grep DB_HOST modules/MyApp/myapp.tf
```
