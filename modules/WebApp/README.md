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
- **CI/CD Integration**: Automated GitHub-triggered builds and deployments
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
   - Cloud Build API (if using custom containers or CI/CD)
   - Cloud Build v2 API (if using CI/CD with GitHub)
   - Artifact Registry API (if using custom containers or CI/CD)
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

### CI/CD with GitHub Integration

This example shows how to set up automated CI/CD pipeline with GitHub integration:

```hcl
module "webapp" {
  source = "./modules/WebApp"

  # Project Configuration
  existing_project_id  = "my-gcp-project"
  tenant_deployment_id = "prod"
  deployment_region    = "us-central1"

  # Application Configuration
  application_name        = "nodejs-app"
  application_version     = "1.0.0"
  application_description = "Node.js Application with CI/CD"

  # Container Configuration - CI/CD Pipeline
  container_image_source = "custom"
  container_build_config = {
    enabled            = true
    dockerfile_path    = "Dockerfile"
    context_path       = "."
    artifact_repo_name = "nodejs-repo"
    build_args = {
      NODE_ENV = "production"
    }
  }
  container_port = 3000

  # GitHub Integration for CI/CD
  enable_cicd_trigger        = true
  github_repository_url      = "https://github.com/myorg/nodejs-app"
  github_token_secret_name   = "github-token"  # Must exist in Secret Manager
  github_app_installation_id = "12345678"      # Your GitHub App installation ID

  cicd_trigger_config = {
    branch_pattern = "^main$"  # Trigger on pushes to main branch
    description    = "Automated build and deployment for Node.js app"
    included_files = ["src/**", "package.json", "Dockerfile"]
    ignored_files  = ["*.md", "docs/**"]
  }

  # Database Configuration
  database_type             = "MYSQL_8_0"
  application_database_name = "nodejs"
  application_database_user = "nodejs"

  # Resource Configuration
  container_resources = {
    cpu_limit    = "1000m"
    memory_limit = "2Gi"
  }

  # Scaling Configuration
  min_instance_count = 0
  max_instance_count = 5

  # Environment Variables
  environment_variables = {
    NODE_ENV = "production"
    API_URL  = "https://api.example.com"
  }

  secret_environment_variables = {
    JWT_SECRET = "jwt-secret-key"
  }
}
```

#### Setting up CI/CD

To enable CI/CD with GitHub integration:

1. **Install GitHub App**:
   - Go to your GitHub repository settings
   - Install the Google Cloud Build GitHub App
   - Note the installation ID from the URL (e.g., `https://github.com/settings/installations/{installation_id}`)

2. **Create GitHub Personal Access Token**:
   - Go to GitHub Settings > Developer Settings > Personal Access Tokens
   - Create a token with `repo` and `read:packages` scopes
   - Store the token in Secret Manager:
     ```bash
     echo -n "ghp_your_token_here" | gcloud secrets create github-token \
       --project=my-gcp-project \
       --data-file=-
     ```

3. **Configure the Module** with CI/CD variables:
   - `enable_cicd_trigger = true`
   - `github_repository_url` - Your repository URL
   - `github_token_secret_name` - Name of secret in Secret Manager (default: "github-token")
   - `github_app_installation_id` - GitHub App installation ID from step 1

4. **Deploy the Infrastructure**:
   ```bash
   terraform init
   terraform apply
   ```

5. **Push to GitHub**: The CI/CD pipeline will automatically:
   - Build your Docker container from the repository
   - Push the image to Artifact Registry
   - Deploy the new version to Cloud Run
   - Tag images with commit SHA for traceability

#### CI/CD Pipeline Behavior

When CI/CD is enabled:
- **Initial Deployment**: A placeholder container is deployed to ensure Cloud Run service starts immediately
- **Automated Builds**: Pushes to the configured branch trigger automatic builds
- **Zero-Downtime Deployments**: Cloud Run handles rolling updates automatically
- **Container Tagging**: Images are tagged with version, `latest`, and commit SHA
- **Build Caching**: Kaniko caching (24h TTL) speeds up subsequent builds

#### Accessing CI/CD Information

After deployment, outputs include:
- `cicd_enabled` - Whether CI/CD is active
- `github_repository_url` - Connected repository
- `artifact_registry_repository` - Container registry details
- `cloudbuild_trigger_name` - Trigger name for monitoring
- `cicd_configuration` - Complete CI/CD setup details

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

### CI/CD Configuration

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `enable_cicd_trigger` | bool | false | Enable automated Cloud Build trigger for CI/CD |
| `github_repository_url` | string | null | GitHub repository URL (e.g., "https://github.com/owner/repo") |
| `github_token_secret_name` | string | "github-token" | Name of secret in Secret Manager containing GitHub token |
| `github_app_installation_id` | string | null | GitHub App installation ID from Cloud Build GitHub App |
| `cicd_trigger_config` | object | See below | Cloud Build trigger configuration |

#### CI/CD Trigger Config Object

```hcl
{
  branch_pattern = string (default: "^main$")
  included_files = list(string) (default: [])
  ignored_files  = list(string) (default: [])
  trigger_name   = string (optional, auto-generated)
  description    = string (default: "Automated build and deployment trigger")
  substitutions  = map(string) (default: {})
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
