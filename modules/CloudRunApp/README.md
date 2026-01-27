# CloudRunApp Terraform Module

A unified Terraform module for deploying web applications on Google Cloud Platform using Cloud Run. This module acts as a wrapper that can deploy generic applications or pre-configured "presets" for popular applications like Django, Wordpress, Odoo, and more.

## Overview

The CloudRunApp module simplifies deployment by providing a single interface for various application types. You can deploy a custom application by providing your own configuration, or use a "preset" to get sensible defaults for specific applications.

## Usage

### 1. Custom Application (Default)

To deploy a custom application, simply use the module without specifying a preset (or explicitly set `deploy_app_preset = "custom"`).

```hcl
module "cloudrunapp" {
  source = "./modules/CloudRunApp"

  deploy_app_preset = "custom"

  existing_project_id      = "my-project"
  tenant_deployment_id     = "prod"
  application_name         = "myapp"
  application_database_name = "myapp_db"
  application_database_user = "myapp_user"

  container_image = "nginx:latest"
  container_port  = 80
}
```

### 2. Using Presets

To deploy a supported application, set `deploy_app_preset` to the desired application name. This will automatically configure defaults for:
- Database type (MySQL/PostgreSQL)
- Container ports and resources
- Health checks and startup probes
- Volume mounts (Cloud SQL, NFS, etc.)

**Supported Presets:**
- `cyclos`
- `directus`
- `django`
- `ghost`
- `medusa`
- `moodle`
- `n8n`
- `odoo`
- `openemr`
- `strapi`
- `wikijs`
- `wordpress`

**Example: Deploying Wordpress**

```hcl
module "wordpress" {
  source = "./modules/CloudRunApp"

  deploy_app_preset = "wordpress"

  existing_project_id  = "my-project"
  tenant_deployment_id = "prod"

  # Optional: Override defaults
  container_resources = {
    cpu_limit    = "2000m"
    memory_limit = "4Gi"
  }
}
```

**Example: Deploying Django**

```hcl
module "django" {
  source = "./modules/CloudRunApp"

  deploy_app_preset = "django"

  existing_project_id  = "my-project"
  tenant_deployment_id = "prod"

  # Django-specific: Impersonation service account for post-deploy updates
  impersonation_service_account = "terraform-sa@my-project.iam.gserviceaccount.com"
}
```

## Presets Configuration

Each preset applies specific configurations. You can override any of these by passing the corresponding variable explicitly.

| Preset | Database | Port | Probes | Notes |
|--------|----------|------|--------|-------|
| `cyclos` | Postgres | 8080 | TCP / HTTP | |
| `directus` | Postgres | 8055 | TCP / HTTP | Requires `KEY`, `SECRET`, `ADMIN_PASSWORD` secrets |
| `django` | Postgres | 8080 | Default | Mounts `/cloudsql`. Includes CSRF origin update job. |
| `ghost` | MySQL | 2368 | TCP / HTTP | |
| `invoiceninja` | MySQL | 80 | TCP / HTTP | Requires `APP_KEY`, `IN_PASSWORD` secrets |
| `medusa` | Postgres | 9000 | TCP / HTTP | Requires `JWT_SECRET`, `COOKIE_SECRET` secrets |
| `moodle` | Postgres | 80 | TCP / HTTP | Mounts NFS at `/mnt`. |
| `n8n` | Postgres | 5678 | HTTP | Mounts `/cloudsql`. |
| `odoo` | Postgres | 8069 | TCP / HTTP | Mounts NFS at `/mnt`. |
| `openemr` | MySQL | 80 | TCP / HTTP | Mounts NFS at `/var/www/localhost/htdocs/openemr/sites`. |
| `strapi` | Postgres | 1337 | TCP / HTTP | Requires multiple JWT/API secrets |
| `wikijs` | Postgres | 3000 | TCP / HTTP | |
| `wordpress` | MySQL | 80 | TCP / HTTP | |

## Inputs

See `variables.tf` for the full list of inputs.

- `deploy_app_preset`: (Optional) The preset to use. Default: `custom`.
- `impersonation_service_account`: (Optional) Service account to impersonate for gcloud commands (used by Django preset).

## Outputs

See `outputs.tf` for the full list of outputs. The module passes through all outputs from the underlying Core module.
