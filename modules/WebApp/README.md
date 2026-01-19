# WebApp Terraform Module

A generic, flexible Terraform module for deploying web applications on Google Cloud Platform using Cloud Run. This module provides a complete platform infrastructure including database, storage, networking, and monitoring services, allowing users to deploy any containerized application with minimal configuration.

## Overview

The WebApp module is designed to be a universal deployment platform that abstracts away the complexity of setting up cloud infrastructure. Unlike application-specific modules (like OpenEMR or Odoo), this module allows you to:

- Deploy any containerized web application
- Choose between pre-built or custom container images
- Support multiple database types (MySQL, PostgreSQL, SQL Server)
- Configure flexible storage options
- Set up custom initialization jobs
- Enable comprehensive monitoring and alerting
- Scale resources based on your needs

## Features

### Core Infrastructure
- **Cloud Run Service**: Serverless container deployment with auto-scaling
- **Cloud SQL Integration**: Automatic detection and configuration of MySQL, PostgreSQL, or SQL Server databases
- **NFS Storage**: Shared file system for persistent data
- **Cloud Storage**: Configurable GCS buckets for object storage
- **VPC Networking**: Private networking with configurable egress settings
- **Secret Manager**: Secure storage and injection of sensitive data

### Flexibility
- **Database Type Agnostic**: Support for MySQL, PostgreSQL, and SQL Server
- **Container Options**: Use pre-built images or build custom containers
- **Custom Initialization Jobs**: Define arbitrary Cloud Run jobs for setup tasks
- **Flexible Volume Mounts**: Configure NFS and GCS FUSE mounts
- **Resource Configuration**: Customize CPU, memory, and scaling settings
- **Multi-Region Support**: Deploy to multiple regions

### Observability
- **Monitoring**: CPU and memory utilization alerts
- **Uptime Checks**: Automated health monitoring
- **Service Level Objectives**: Latency and availability SLOs
- **Custom Alerts**: Define application-specific alert policies

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Internet / Users                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │   Cloud Run Service  │
              │   (Your Application) │
              └─────────┬────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  Cloud SQL   │  │ NFS Storage  │  │Cloud Storage │
│  (Database)  │  │ (Persistent) │  │   (Objects)  │
└──────────────┘  └──────────────┘  └──────────────┘
        │
        ▼
┌──────────────────────┐
│  Secret Manager      │
│  (DB Credentials)    │
└──────────────────────┘
```

## Prerequisites

Before using this module, ensure you have:

1. **GCP Project** with the following APIs enabled:
   - Cloud Run API
   - Cloud SQL Admin API
   - Cloud Build API (if using custom containers)
   - Artifact Registry API (if using custom containers)
   - Compute Engine API
   - Secret Manager API
   - Cloud Monitoring API

2. **Existing Infrastructure**:
   - A Cloud SQL instance (MySQL, PostgreSQL, or SQL Server)
   - A VPC network with subnets
   - An NFS server (optional, but recommended)
   - Service accounts: `cloudrun-sa`, `cloudbuild-sa` (if building containers)

3. **Terraform** version >= 0.13
4. **gcloud CLI** configured with appropriate permissions

## Quick Start

### Basic Example (Pre-built Container)

```hcl
module "webapp" {
  source = "./modules/WebApp"

  # Project Configuration
  existing_project_id     = "my-gcp-project"
  tenant_deployment_id    = "prod"
  deployment_region       = "us-central1"

  # Application Configuration
  application_name        = "myapp"
  application_version     = "1.0.0"
  application_description = "My Web Application"

  # Container Configuration
  container_image_source  = "prebuilt"
  container_image         = "nginx:latest"
  container_port          = 80

  # Database Configuration
  database_type                = "MYSQL"
  application_database_name    = "myapp"
  application_database_user    = "myapp"

  # Network Configuration
  network_name                 = "vpc-network"

  # Monitoring
  configure_monitoring         = true
  trusted_users                = ["admin@example.com"]

  # Environment Variables
  environment_variables = {
    APP_ENV = "production"
    LOG_LEVEL = "info"
  }
}
```

### Advanced Example (Custom Container with Initialization Jobs)

```hcl
module "webapp" {
  source = "./modules/WebApp"

  # Project Configuration
  existing_project_id  = "my-gcp-project"
  tenant_deployment_id = "prod"
  deployment_region    = "us-central1"

  # Application Configuration
  application_name        = "django-app"
  application_version     = "2.1.0"
  application_description = "Django Web Application"

  # Container Configuration - Custom Build
  container_image_source = "custom"
  container_build_config = {
    enabled            = true
    dockerfile_content = file("${path.module}/Dockerfile")
    context_path       = "."
    build_args = {
      PYTHON_VERSION = "3.11"
      APP_ENV        = "production"
    }
    artifact_repo_name = "django-repo"
  }
  container_port = 8000

  # Database Configuration
  database_type             = "POSTGRES"
  application_database_name = "django"
  application_database_user = "django"

  # Resource Configuration
  container_resources = {
    cpu_limit    = "2000m"
    memory_limit = "4Gi"
  }

  # Scaling Configuration
  min_instance_count = 1
  max_instance_count = 10

  # Storage Buckets
  storage_buckets = [
    {
      name_suffix = "media"
      location    = "US"
    },
    {
      name_suffix = "static"
      location    = "US"
    }
  ]

  # GCS Volume Mounts
  gcs_volumes = [
    {
      name        = "media"
      bucket_name = null  # Will use auto-created bucket
      mount_path  = "/app/media"
      readonly    = false
    }
  ]

  # Initialization Jobs
  initialization_jobs = [
    {
      name            = "migrate-db"
      description     = "Run Django database migrations"
      command         = ["python"]
      args            = ["manage.py", "migrate", "--noinput"]
      timeout_seconds = 600
      execute_on_apply = true
    },
    {
      name            = "collectstatic"
      description     = "Collect static files"
      command         = ["python"]
      args            = ["manage.py", "collectstatic", "--noinput"]
      timeout_seconds = 300
      execute_on_apply = true
      mount_gcs_volumes = ["media"]
    }
  ]

  # Health Check Configuration
  health_check_config = {
    enabled = true
    path    = "/health"
  }

  startup_probe_config = {
    enabled               = true
    path                  = "/health"
    timeout_seconds       = 300
  }

  # Environment Variables
  environment_variables = {
    DJANGO_SETTINGS_MODULE = "myapp.settings.production"
    ALLOWED_HOSTS          = "*"
  }

  secret_environment_variables = {
    SECRET_KEY        = "django-secret-key"
    STRIPE_API_KEY    = "stripe-api-key"
  }

  # Monitoring
  configure_monitoring = true
  trusted_users        = ["devops@example.com"]

  uptime_check_config = {
    enabled         = true
    path            = "/health"
    check_interval  = "60s"
  }

  alert_policies = [
    {
      name               = "high-error-rate"
      metric_type        = "run.googleapis.com/request_count"
      comparison         = "COMPARISON_GT"
      threshold_value    = 100
      duration_seconds   = 300
      aggregation_period = "60s"
    }
  ]
}
```

## Module Inputs

### Required Variables

| Name | Type | Description |
|------|------|-------------|
| `existing_project_id` | string | GCP project ID where resources will be deployed |
| `tenant_deployment_id` | string | Tenant identifier for multi-tenant deployments (1-20 chars) |
| `application_name` | string | Application name used in resource naming (1-20 chars) |
| `application_database_name` | string | Application database name |
| `application_database_user` | string | Application database user |

### Core Configuration

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `deployment_id` | string | null (auto-generated) | Unique deployment identifier |
| `deployment_region` | string | "us-central1" | Primary deployment region |
| `deployment_regions` | list(string) | [] | Additional regions for multi-region deployment |
| `application_version` | string | "latest" | Application version tag |
| `application_description` | string | "" | Human-readable description |

### Container Configuration

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `container_image_source` | string | "prebuilt" | "prebuilt" or "custom" |
| `container_image` | string | null | Pre-built image (e.g., "nginx:latest") |
| `container_port` | number | 8080 | Container port to expose |
| `container_protocol` | string | "http1" | "http1" or "h2c" |
| `container_build_config` | object | See below | Custom container build configuration |

#### Container Build Config Object

```hcl
{
  enabled            = bool
  dockerfile_path    = string (default: "Dockerfile")
  dockerfile_content = string (optional)
  context_path       = string (default: ".")
  build_args         = map(string) (default: {})
  artifact_repo_name = string (default: "webapp-repo")
}
```

### Database Configuration

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `database_type` | string | "MYSQL" | Database type (MYSQL, POSTGRES, SQLSERVER, etc.) |
| `database_password_length` | number | 16 | Length of auto-generated password |
| `database_flags` | map(string) | {} | Additional database flags |

### Resource Configuration

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `container_resources` | object | `{cpu_limit="1000m", memory_limit="512Mi"}` | Resource limits |
| `container_concurrency` | number | 80 | Max concurrent requests per container |
| `timeout_seconds` | number | 300 | Request timeout |

### Scaling Configuration

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `min_instance_count` | number | 0 | Minimum container instances |
| `max_instance_count` | number | 3 | Maximum container instances |
| `max_instance_request_concurrency` | number | 80 | Max requests per instance |

### Storage Configuration

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `create_cloud_storage` | bool | true | Create Cloud Storage buckets |
| `storage_buckets` | list(object) | See below | Bucket configurations |
| `nfs_enabled` | bool | true | Enable NFS volume mount |
| `nfs_mount_path` | string | "/mnt" | NFS mount path in container |
| `gcs_volumes` | list(object) | [] | GCS FUSE volume configurations |

#### Storage Bucket Object

```hcl
{
  name_suffix              = string
  location                 = string (default: "EU")
  storage_class            = string (default: "STANDARD")
  force_destroy            = bool (default: true)
  versioning_enabled       = bool (default: false)
  lifecycle_rules          = list(any) (default: [])
  public_access_prevention = string (default: "enforced")
}
```

### Initialization Jobs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `initialization_jobs` | list(object) | [] | Cloud Run jobs for initialization |

#### Initialization Job Object

```hcl
{
  name               = string
  description        = string (optional)
  image              = string (optional, defaults to main image)
  command            = list(string) (optional)
  args               = list(string) (optional)
  env_vars           = map(string) (optional)
  secret_env_vars    = map(string) (optional)
  cpu_limit          = string (default: "1000m")
  memory_limit       = string (default: "512Mi")
  timeout_seconds    = number (default: 600)
  max_retries        = number (default: 1)
  task_count         = number (default: 1)
  mount_nfs          = bool (default: false)
  mount_gcs_volumes  = list(string) (default: [])
  depends_on_jobs    = list(string) (optional)
  execute_on_apply   = bool (default: false)
  script_path        = string (optional)
}
```

### Monitoring Configuration

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `configure_monitoring` | bool | true | Enable monitoring and alerting |
| `trusted_users` | list(string) | [] | Email addresses for alerts |
| `uptime_check_config` | object | See below | Uptime check configuration |
| `alert_policies` | list(object) | [] | Custom alert policies |

### Environment Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `environment_variables` | map(string) | {} | Static environment variables |
| `secret_environment_variables` | map(string) | {} | Secret Manager references |

## Module Outputs

| Name | Description |
|------|-------------|
| `service_url` | URL of the deployed Cloud Run service |
| `service_name` | Name of the Cloud Run service |
| `database_name` | Full database name |
| `database_password_secret` | Secret Manager secret name for DB password |
| `storage_buckets` | Map of created storage buckets |
| `container_image` | Container image used for deployment |
| `deployment_summary` | Summary of the deployment |

See `outputs.tf` for complete list of outputs.

## Examples

### Example 1: Simple Node.js Application

```hcl
module "nodejs_app" {
  source = "./modules/WebApp"

  existing_project_id      = "my-project"
  tenant_deployment_id     = "prod"
  application_name         = "nodeapp"
  application_database_name = "nodeapp"
  application_database_user = "nodeapp"

  container_image  = "gcr.io/my-project/nodeapp:latest"
  container_port   = 3000
  database_type    = "POSTGRES"

  environment_variables = {
    NODE_ENV = "production"
  }
}
```

### Example 2: Python Flask with Job Migration

```hcl
module "flask_app" {
  source = "./modules/WebApp"

  existing_project_id      = "my-project"
  tenant_deployment_id     = "staging"
  application_name         = "flaskapp"
  application_database_name = "flask"
  application_database_user = "flask"

  container_image  = "python:3.11-slim"
  container_port   = 5000
  database_type    = "MYSQL"

  initialization_jobs = [
    {
      name             = "db-migrate"
      command          = ["flask"]
      args             = ["db", "upgrade"]
      execute_on_apply = true
    }
  ]

  environment_variables = {
    FLASK_APP = "app.py"
    FLASK_ENV = "production"
  }
}
```

## Best Practices

1. **Security**:
   - Always use Secret Manager for sensitive data
   - Enable private VPC egress when possible
   - Use minimal IAM permissions
   - Enable public access prevention on buckets

2. **Reliability**:
   - Configure health checks appropriately
   - Set realistic startup probe timeouts
   - Use adequate resource limits
   - Enable monitoring and alerts

3. **Cost Optimization**:
   - Set `min_instance_count = 0` for non-critical apps
   - Choose appropriate resource limits
   - Use regional storage when global isn't needed
   - Clean up unused buckets with lifecycle rules

4. **Performance**:
   - Use GCS FUSE for large file operations
   - Configure appropriate CPU and memory
   - Enable startup CPU boost
   - Use connection pooling for databases

## Troubleshooting

### Service Won't Start

1. Check startup probe timeout - increase if needed
2. Verify database connectivity
3. Check NFS server accessibility
4. Review Cloud Run logs: `gcloud run services logs read <service-name>`

### Database Connection Errors

1. Verify database instance exists and is running
2. Check VPC connectivity
3. Verify database user and password in Secret Manager
4. Ensure correct database type is specified

### Build Failures

1. Check Dockerfile syntax
2. Verify build args are correct
3. Review Cloud Build logs
4. Ensure Artifact Registry exists

## Migration Guide

### From OpenEMR Module

```hcl
# Old OpenEMR
module "openemr" {
  source = "./modules/OpenEMR"
  application_name = "openemr"
  ...
}

# New WebApp
module "openemr" {
  source = "./modules/WebApp"
  application_name = "openemr"
  container_image  = "openemr/openemr:7.0.3"
  container_port   = 80
  database_type    = "MYSQL"
  health_check_config = {
    enabled = true
    path    = "/interface/login/login.php"
  }
  ...
}
```

### From Odoo Module

```hcl
# Old Odoo
module "odoo" {
  source = "./modules/Odoo"
  application_name = "odoo"
  ...
}

# New WebApp
module "odoo" {
  source = "./modules/WebApp"
  application_name = "odoo"
  container_image_source = "custom"
  container_build_config = {
    enabled = true
    dockerfile_content = file("${path.module}/Dockerfile")
  }
  container_port  = 8069
  database_type   = "POSTGRES"
  gcs_volumes = [
    {
      name       = "data"
      mount_path = "/extra-addons"
    }
  ]
  initialization_jobs = [
    {
      name = "init-db"
      command = ["odoo"]
      args = ["-d", "odoo", "-i", "base", "--stop-after-init"]
      execute_on_apply = true
    }
  ]
  ...
}
```

## Contributing

Contributions are welcome! Please ensure:
- Code follows existing patterns
- Documentation is updated
- Examples are provided
- Changes are backward compatible

## License

Copyright 2024 (c) Tech Equity Ltd

Licensed under the Apache License, Version 2.0.

## Support

For issues, questions, or contributions, please contact Tech Equity Ltd.
