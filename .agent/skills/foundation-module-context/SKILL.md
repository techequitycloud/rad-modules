---
name: foundation-module-context
description: Understand the CloudRunApp foundation module and its core functionality.
---

# Foundation Module Context (CloudRunApp)

The `modules/CloudRunApp` module is the cornerstone of application deployment in this repository. It serves as a unified wrapper that abstracts the complexities of deploying containerized applications to Cloud Run.

## Core Responsibilities

1.  **Cloud Run Service**: Deploys the Cloud Run service (`service.tf`), configuring container image, ports, resources (CPU/Memory), and environment variables.
2.  **Networking**: Connects the service to the VPC via Serverless VPC Access (`network.tf`), enabling access to private resources like Cloud SQL and Redis.
3.  **Database Integration**: Automatically handles Cloud SQL connection strings and Sidecar (if needed), or private IP connections.
4.  **Secrets Management**: Integrates with Secret Manager (`secrets.tf`) to securely inject sensitive environment variables.
5.  **IAM**: Manages Service Accounts (`sa.tf`) and IAM bindings (`iam.tf`) for the Cloud Run service.
6.  **Presets**: Implements a "preset" system (`modules.tf`) that allows deploying standard applications (like generic web apps) with pre-configured defaults.

## Key Inputs

*   `application_module`: Determines the mode of operation. If set to `"custom"`, it expects manual configuration. If set to a preset name (e.g., `"cloudrunapp"`), it loads defaults.
*   `container_image`: The Docker image to deploy.
*   `container_port`: The port the container listens on.
*   `env_vars`: Map of environment variables to inject.
*   `secret_env_vars`: Map of secrets to inject.

## Architecture

This module is designed to be **reusable**. Application modules (like `Cyclos`, `Wordpress`) rely on it by symlinking its Terraform files. This ensures consistency across all deployed applications and simplifies maintenance.

## File Structure and Organization

CloudRunApp contains **24 Terraform files** organized by function:

### Core Logic Files

*   **`main.tf`** (17KB): Primary orchestration logic that ties all resources together
*   **`modules.tf`** (10KB): Preset selection logic, extracts values from `application_modules` map
*   **`variables.tf`** (32KB, 797 lines): Complete configuration schema with UIMeta tags
*   **`outputs.tf`** (10KB): Exports service URLs, IP addresses, connection details for consumption

### Resource Management Files

*   **`service.tf`** (11KB): Cloud Run service configuration including:
    *   Container specifications
    *   Resource limits (CPU/Memory)
    *   Scaling parameters
    *   Volume mounts
    *   Environment variables
*   **`jobs.tf`** (43KB): Initialization and cleanup job orchestration
    *   Sequential job execution
    *   Database initialization
    *   Backup/restore operations
    *   Cleanup on destroy
*   **`buildappcontainer.tf`** (4KB): Cloud Build image construction
    *   Custom Dockerfile builds
    *   Artifact Registry integration
    *   Build trigger configuration

### Security and Access Files

*   **`iam.tf`**: IAM role bindings for service accounts
*   **`sa.tf`**: Service account creation and configuration
*   **`secrets.tf`**: Secret Manager integration for sensitive data

### Infrastructure Integration Files

*   **`network.tf`**: VPC connector attachment for private networking
*   **`sql.tf`**: Cloud SQL connection configuration
*   **`nfs.tf`**: Filestore NFS mount configuration
*   **`storage.tf`**: GCS bucket creation and management

### Operations Files

*   **`monitoring.tf`** (10KB): Cloud Monitoring and logging setup
*   **`registry.tf`**: Artifact Registry configuration
*   **`trigger.tf`** (9.4KB): Cloud Build CI/CD trigger setup

### Supporting Files

*   **`provider-auth.tf`**: Google provider authentication
*   **`versions.tf`**: Provider version constraints
*   **`cloudrunapp.tf`**: Custom base application configuration (rarely used)

### Scripts Directory

```
modules/CloudRunApp/scripts/
├── core/                    # Shared maintenance scripts
│   ├── build-container.sh
│   ├── cloudbuild.yaml.tpl
│   ├── cloudbuild-cicd.yaml.tpl
│   ├── db-cleanup.sh
│   ├── get-impersonation-token.sh
│   ├── get-nfsserver-info.sh
│   ├── get-sqlserver-info.sh
│   ├── import-gcs-backup.sh
│   ├── import-gdrive-backup.sh
│   ├── install-mysql-plugins.sh
│   ├── install-postgres-extensions.sh
│   ├── mirror-image.sh
│   ├── nfs-cleanup.sh
│   ├── run-custom-sql-scripts.sh
│   └── run_ordered_jobs.py
└── cloudrunapp/             # Base application example
    ├── Dockerfile
    ├── app.py              # Flask sample application
    ├── db-init.sh
    └── requirements.txt
```

### Configuration Examples

```
modules/CloudRunApp/config/
├── advanced-cloudrunapp.tfvars   # Full-featured configuration
├── basic-cloudrunapp.tfvars      # Minimal configuration
└── custom-cloudrunapp.tfvars     # Custom scenarios
```

## Preset Selection Mechanism

CloudRunApp uses dynamic module selection to work across all application wrappers without hardcoding:

### How It Works

**1. Dynamic Module Selection** (`modules.tf`):
```hcl
locals {
  # Automatically selects the first (and only) module from application_modules map
  module_name = element(keys(local.application_modules), 0)

  # Extracts the module configuration
  selected_module = local.application_modules[local.module_name]
}
```

**2. Configuration Extraction**:
```hcl
# Extract nested configuration into flat locals for Terraform consumption
locals {
  app_name        = local.selected_module.app_name
  container_image = local.selected_module.container_image
  container_port  = local.selected_module.container_port
  # ... and so on
}
```

**3. Smart Defaults**:
*   Loads preset configurations for standard applications
*   Supports both custom builds and prebuilt images
*   Auto-naming for GCS volumes with placeholders
*   Probe configuration extraction with defaults

### Benefits

*   **No Hardcoding**: Same code works across Django, Wordpress, Cyclos, etc.
*   **Single Source of Truth**: Application modules define config once
*   **Type Safety**: Terraform validates the configuration structure
*   **Easy Extension**: Add new apps without modifying CloudRunApp

### Example Flow

```
Application Module (django.tf)
  ↓
Defines: local.application_modules = { django = {...} }
  ↓
CloudRunApp (modules.tf)
  ↓
Extracts: module_name = "django"
         selected_module = django configuration
  ↓
CloudRunApp (main.tf, service.tf, etc.)
  ↓
Consumes: local.app_name, local.container_image, etc.
  ↓
Deploys: Cloud Run Service
```

## Security Architecture

CloudRunApp implements a multi-account security strategy with least-privilege access:

### Service Account Roles

**1. Cloud Run Service Account** (created in `sa.tf`):

*   **Purpose**: Runs the application container
*   **Scope**: Runtime operations only
*   **Common Permissions** (configured in `iam.tf`):
    *   `roles/secretmanager.secretAccessor` - Access application secrets
    *   `roles/cloudsql.client` - Connect to Cloud SQL databases
    *   `roles/storage.objectAdmin` - Read/write GCS buckets
    *   `roles/redis.editor` - Access Memorystore Redis (if used)
    *   Custom roles for specific resource access

**2. Cloud Build Service Account** (deployment operations):

*   **Purpose**: Deploys new Cloud Run revisions
*   **Scope**: Build and deployment operations
*   **Key Permissions**:
    *   `roles/run.admin` - Manage Cloud Run services
    *   `roles/iam.serviceAccountUser` - Act as the Cloud Run service account
    *   `roles/artifactregistry.writer` - Push container images
    *   `roles/storage.admin` - Manage build artifacts

### Least-Privilege Pattern

```hcl
# Service account for runtime (sa.tf)
resource "google_service_account" "app_sa" {
  account_id   = "${var.service_name}-sa"
  display_name = "Service Account for ${var.service_name}"
}

# Grant only necessary permissions (iam.tf)
resource "google_project_iam_member" "app_sa_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

# Cloud Run service uses the service account (service.tf)
resource "google_cloud_run_v2_service" "app" {
  template {
    service_account = google_service_account.app_sa.email
    # ...
  }
}
```

### Security Best Practices

1.  **Separation of Concerns**: Runtime vs. deployment accounts
2.  **Minimal Permissions**: Only grant what's necessary
3.  **Secret Manager**: Never store secrets in environment variables or code
4.  **VPC Networking**: Private IP connections for databases (not public)
5.  **Service Account Keys**: Never generate or use service account keys (use Workload Identity)

## Storage Integration Patterns

CloudRunApp supports multiple storage backends for different use cases:

### 1. GCS Volumes (Fuse Mounting)

**Use Case**: File uploads, media storage, persistent user content

**Configuration**:
```hcl
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
    readonly          = true  # Read-only for serving
  }
]
```

**Requirements**:
*   Container must run as **UID 2000** for GCS Fuse compatibility
*   Service account needs `roles/storage.objectAdmin`
*   Bucket created automatically by CloudRunApp

**Example Dockerfile**:
```dockerfile
FROM python:3.11-slim

# GCS Fuse requires UID 2000
RUN useradd -m -u 2000 appuser

WORKDIR /app
COPY --chown=appuser:appuser . .

USER appuser
```

### 2. NFS Filestore

**Use Case**: Shared file storage across multiple instances, large file operations, WordPress uploads

**Configuration**:
```hcl
nfs_enabled    = true
nfs_mount_path = "/mnt/filestore"
nfs_server     = var.nfs_server  # From GCP_Services output
```

**Characteristics**:
*   Private NFS shares (not internet-accessible)
*   Persistent across deployments and restarts
*   Higher performance than GCS for small files
*   Cleanup handled automatically on destroy (via `nfs-cleanup.sh`)

**Mount in Cloud Run**:
```hcl
# Configured automatically in service.tf
volumes {
  name = "nfs"
  nfs {
    server = var.nfs_server
    path   = "/vol1"
  }
}

volume_mounts {
  name       = "nfs"
  mount_path = "/mnt/filestore"
}
```

### 3. Cloud SQL Volume (Unix Socket)

**Use Case**: Cloud SQL Proxy connection (alternative to private IP)

**Configuration**:
```hcl
enable_cloudsql_volume     = true
cloudsql_volume_mount_path = "/cloudsql"
```

**When to Use**:
*   When private IP connection isn't available
*   When using Cloud SQL Proxy is required
*   Legacy applications expecting Unix socket connections

**Default Behavior**: Most applications use **private IP connections** instead:
```hcl
enable_cloudsql_volume = false  # Default
# Application connects via private IP through VPC connector
```

### 4. Local Ephemeral Storage

**Use Case**: Temporary files, build artifacts, caches

**Characteristics**:
*   **Not persistent** - data lost on instance restart
*   Fast local SSD
*   Suitable only for temporary data
*   No additional configuration needed

**Example**:
```python
# Python application
import tempfile

with tempfile.NamedTemporaryFile() as tmp:
    tmp.write(b"temporary data")
    # File deleted when container stops
```

### Storage Selection Guide

| Use Case | Recommended Storage | Why |
|----------|-------------------|-----|
| User file uploads | GCS Volumes | Scalable, durable, cost-effective |
| Media/images | GCS Volumes | CDN integration, global access |
| Shared WordPress uploads | NFS Filestore | Multi-instance access |
| Database files | Managed Cloud SQL | Fully managed, automated backups |
| Session data | Memorystore Redis | Fast, in-memory |
| Temporary files | Local ephemeral | Fastest, no cost |
| Application logs | Cloud Logging | Managed, searchable, integrated |

## Initialization Jobs System

CloudRunApp orchestrates initialization jobs that run as Cloud Run Jobs before the service starts.

### Job Configuration

Jobs are defined in the application module's configuration:

```hcl
initialization_jobs = [
  {
    name            = "db-init"
    description     = "Initialize database schema and users"
    image           = null  # null = use app image; or specify custom image
    command         = ["/bin/sh", "-c"]
    args            = [<<-EOT
      #!/bin/bash
      set -e

      echo "Creating database..."
      psql -h $DB_HOST -U postgres -c "CREATE DATABASE IF NOT EXISTS myapp;"

      echo "Running migrations..."
      python manage.py migrate

      echo "Creating superuser..."
      python manage.py createsuperuser --noinput
    EOT]

    # Resource configuration
    timeout_seconds = 600
    max_retries     = 3

    # Volume mounts
    mount_nfs           = true
    mount_gcs_volumes   = ["uploads", "static"]
    mount_cloudsql      = true

    # Execution control
    execute_on_apply   = true  # Run on every terraform apply

    # Environment variables (inherits from service + custom)
    env_vars = {
      MIGRATION_MODE = "safe"
    }
  },
  {
    name            = "install-extensions"
    description     = "Install PostgreSQL extensions"
    image           = "postgres:15-alpine"  # Custom image
    command         = ["/bin/sh", "-c"]
    args            = [<<-EOT
      psql -h $DB_HOST -U postgres -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
      psql -h $DB_HOST -U postgres -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS unaccent;"
    EOT]
    execute_on_apply = false  # Run only on initial creation
  }
]
```

### Execution Order

Jobs run **sequentially** via `run_ordered_jobs.py`:

```
1. Job: install-extensions
   ↓ (waits for completion)
2. Job: db-init
   ↓ (waits for completion)
3. Cloud Run Service starts
```

### Job Execution Control

**`execute_on_apply` Options**:

*   `true`: Job runs on **every** `terraform apply`
    *   Use for: Idempotent operations (migrations, updates)
    *   Safe for repeated execution
*   `false`: Job runs **only on initial creation**
    *   Use for: One-time setup (extension installation, initial data load)
    *   Skipped on subsequent applies

### Common Use Cases

**1. Database Schema Creation**:
```hcl
args = [<<-EOT
  python manage.py migrate
  python manage.py loaddata initial_data.json
EOT]
```

**2. PostgreSQL Extension Installation**:
```hcl
args = [<<-EOT
  psql -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
  psql -c "CREATE EXTENSION IF NOT EXISTS uuid-ossp;"
EOT]
```

**3. MySQL Plugin Setup**:
```hcl
args = [<<-EOT
  mysql -e "INSTALL PLUGIN auth_socket SONAME 'auth_socket.so';"
EOT]
```

**4. User Account Provisioning**:
```hcl
args = [<<-EOT
  python manage.py createsuperuser \
    --username admin \
    --email admin@example.com \
    --noinput
EOT]
```

**5. Backup Restoration**:
```hcl
args = [<<-EOT
  /scripts/core/import-gcs-backup.sh \
    --bucket=gs://backups/myapp-db.sql \
    --database=$DB_NAME
EOT]
```

### Job Debugging

**View job executions**:
```bash
gcloud run jobs executions list \
  --job=<job-name> \
  --region=<region>
```

**View job logs**:
```bash
gcloud run jobs executions logs <execution-name> \
  --region=<region>
```

**Common issues**:
*   Timeout: Increase `timeout_seconds`
*   Permissions: Verify service account has necessary roles
*   Mount failures: Check volume configurations
*   Environment variables: Ensure secrets are accessible

## Cloud Build Integration

CloudRunApp supports custom container builds via Cloud Build:

### Build Configuration

**In application module** (`<app>.tf`):
```hcl
container_build_config = {
  enabled            = true
  dockerfile_path    = "Dockerfile"
  context_path       = "myapp"  # MUST match scripts/myapp/
  dockerfile_content = null     # Or inline Dockerfile content
  build_args         = {
    APP_VERSION = var.application_version
    BUILD_ENV   = "production"
  }
  artifact_repo_name = null     # Or specify custom repo
}
```

### Build Process

**Triggered by** `buildappcontainer.tf`:

1.  **Context Preparation**: Copies `scripts/<context_path>/` to build context
2.  **Dockerfile Resolution**: Uses `dockerfile_path` or `dockerfile_content`
3.  **Cloud Build Submission**: Submits to Cloud Build API
4.  **Image Storage**: Stores in Artifact Registry
5.  **Service Update**: Updates Cloud Run service with new image

### Build Args Support

Pass build-time variables to Dockerfile:

```dockerfile
# Dockerfile
ARG APP_VERSION
ARG BUILD_ENV

FROM python:3.11-slim

ENV VERSION=${APP_VERSION}
ENV ENVIRONMENT=${BUILD_ENV}

# Rest of Dockerfile...
```

### CI/CD Triggers

CloudRunApp can create Cloud Build triggers for automated deployments:

```hcl
# Enable CI/CD (trigger.tf)
enable_cicd_trigger    = true
github_repository_url  = "https://github.com/myorg/myapp"
github_branch_pattern  = "^main$"
```

**Trigger Behavior**:
*   Monitors GitHub repository for commits
*   Automatically builds new container image
*   Deploys new revision to Cloud Run
*   Uses `scripts/core/cloudbuild-cicd.yaml.tpl` template

## Advanced Features

### Multi-Region Deployment Support

```hcl
deployment_regions = ["us-central1", "europe-west1", "asia-east1"]
```

Infrastructure for deploying the same application across multiple regions (future capability).

### Image Mirroring

Mirror prebuilt images to private Artifact Registry:

```hcl
# Use public image but mirror to private registry
container_image = "wordpress:latest"
mirror_to_artifact_registry = true
```

Uses `scripts/core/mirror-image.sh` to pull and push to private registry.

### Backup and Restore

**GCS-based backups**:
```bash
/scripts/core/import-gcs-backup.sh \
  --bucket=gs://backups/db.sql \
  --database=myapp
```

**Google Drive backup import**:
```bash
/scripts/core/import-gdrive-backup.sh \
  --file-id=<drive-file-id> \
  --database=myapp
```

### Custom SQL Scripts

Run custom SQL during initialization:

```bash
/scripts/core/run-custom-sql-scripts.sh \
  --database=$DB_NAME \
  --scripts-dir=/app/sql-scripts
```

### Health Probes

Configurable startup and liveness probes:

```hcl
startup_probe = {
  enabled                = true
  type                   = "http"  # or "tcp", "grpc"
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
  period_seconds  = 30
}
```

## Troubleshooting CloudRunApp Issues

### Build Failures

**Problem**: "Error building container image"

**Solution**:
1.  Check Cloud Build logs:
    ```bash
    gcloud builds list --limit=5
    gcloud builds log <build-id>
    ```
2.  Verify Dockerfile syntax and base image availability
3.  Check build context path matches directory structure
4.  Verify service account has necessary build permissions

### Service Won't Start

**Problem**: Cloud Run service fails to start

**Solution**:
1.  Check service logs:
    ```bash
    gcloud run services logs read <service-name> --region=<region> --limit=50
    ```
2.  Verify container port matches application port
3.  Check health probe configuration
4.  Ensure all required environment variables are set
5.  Verify secrets are accessible

### Networking Issues

**Problem**: Cannot connect to Cloud SQL or Redis

**Solution**:
1.  Verify VPC connector is attached:
    ```bash
    gcloud run services describe <service-name> \
      --region=<region> \
      --format="value(template.vpcAccess)"
    ```
2.  Check private IP is used for database connection
3.  Verify firewall rules allow traffic
4.  Test connectivity from Cloud Shell in same VPC

### Permission Errors

**Problem**: "Permission denied" accessing resources

**Solution**:
1.  Verify service account exists and is attached to service
2.  Check IAM bindings in GCP Console or via:
    ```bash
    gcloud projects get-iam-policy <project-id> \
      --flatten="bindings[].members" \
      --filter="bindings.members:<service-account-email>"
    ```
3.  Grant necessary roles via `iam.tf`
4.  Wait a few minutes for IAM propagation
