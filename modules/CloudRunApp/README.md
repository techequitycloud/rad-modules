# CloudRunApp Terraform Module

A unified Terraform module for deploying web applications on Google Cloud Platform using Cloud Run. This module acts as a wrapper that can deploy generic applications or pre-configured "presets".

## Overview

The CloudRunApp module simplifies deployment by providing a single interface for various application types. You can deploy a custom application by providing your own configuration, or use a "preset" to get sensible defaults for specific applications.

## Usage

### 1. Custom Application (Default)

To deploy a custom application, simply use the module without specifying a preset (or explicitly set `application_module = "custom"`).

```hcl
module "cloudrunapp" {
  source = "./modules/CloudRunApp"

  application_module = "custom"

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

To deploy a supported application, set `application_module` to the desired application name. This will automatically configure defaults for:
- Database type (MySQL/PostgreSQL)
- Container ports and resources
- Health checks and startup probes
- Volume mounts (Cloud SQL, NFS, etc.)

**Supported Presets:**
- `cloudrunapp`

## Presets Configuration

Each preset applies specific configurations. You can override any of these by passing the corresponding variable explicitly.

| Preset | Database | Port | Probes | Notes |
|--------|----------|------|--------|-------|
| `cloudrunapp` | PostgreSQL | 8080 | TCP / HTTP | |

## Inputs

See `variables.tf` for the full list of inputs.

- `application_module`: (Optional) The preset to use. Default: `custom`.
- `impersonation_service_account`: (Optional) Service account to impersonate for gcloud commands.

## Outputs

See `outputs.tf` for the full list of outputs. The module passes through all outputs from the underlying Core module.
