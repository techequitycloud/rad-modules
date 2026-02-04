---
name: terraform-module-implementation
description: Guide for implementing Terraform Application Modules using the CloudRunApp wrapper pattern.
---

# Terraform Module Implementation Skill

This skill details how to implement new Application Modules in this repository. These modules act as wrappers around the foundational `CloudRunApp` module, reusing its core logic while defining application-specific configurations.

## 1. Overview & The Wrapper Pattern

The repository uses a "Wrapper Pattern" for Application Modules.
- **Foundation**: `modules/CloudRunApp` contains the core Terraform logic (services, IAM, networking, storage, etc.).
- **Wrapper**: Each Application Module (e.g., `modules/Odoo`, `modules/Wordpress`) symlinks to the core files in `CloudRunApp`.
- **Configuration**: The wrapper defines its specific logic in a local `.tf` file (e.g., `odoo.tf`) by setting `local.application_modules`.

**Benefits:**
- Consistent infrastructure across all apps.
- Single point of maintenance for core logic.
- Rapid creation of new modules.

## 2. Directory Structure

A standard Application Module should look like this:

```
modules/MyModule/
├── main.tf -> ../CloudRunApp/main.tf
├── variables.tf                 # Module-specific variables (Copy from template)
├── mymodule.tf                  # MAIN CONFIGURATION FILE (Local logic)
├── scripts/
│   └── mymodule/
│       ├── Dockerfile           # If building a custom image
│       └── ...                  # Other helper scripts
├── config/                      # Configuration templates (e.g., nginx.conf, php.ini)
│   └── ...
├── .gitignore
├── README.md
├── MYMODULE.md                  # Detailed documentation
└── [Symlinks to CloudRunApp]    # See list below
```

**Required Symlinks:**
Ensure these point to `../CloudRunApp/`:
- `buildappcontainer.tf`, `iam.tf`, `jobs.tf`, `main.tf`, `modules.tf`, `monitoring.tf`, `network.tf`, `nfs.tf`, `outputs.tf`, `provider-auth.tf`, `registry.tf`, `sa.tf`, `secrets.tf`, `service.tf`, `sql.tf`, `storage.tf`, `trigger.tf`, `versions.tf`

**Note:** `variables.tf` is **NOT** a symlink. It must be a local file.

## 3. Module Configuration (`<module_name>.tf`)

This file is the heart of the module. It must define a `locals` block with specific keys that `CloudRunApp` expects.

### Required Locals

```hcl
locals {
  # 1. Define the module configuration
  mymodule_module = {
    app_name                = "mymodule"
    application_version     = var.application_version
    display_name            = "My Module Display Name"
    description             = "Description of what this module does"

    # Container Image Config
    container_image         = "repo/image"  # Base image name
    image_source            = "custom"      # "custom" (build local) or "prebuilt" (pull public)

    # Build Config (if image_source = "custom")
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "mymodule"       # Maps to scripts/mymodule/
      build_args         = {
         SOME_ARG = "value"
      }
    }

    container_port          = 8080

    # Database Config
    database_type           = "POSTGRES_15" # NONE, MYSQL_8_0, POSTGRES_15, SQLSERVER_2019_STANDARD
    db_name                 = "mydb"
    db_user                 = "myuser"
    enable_cloudsql_volume  = true          # Mount Cloud SQL via Unix socket
    cloudsql_volume_mount_path = "/cloudsql"

    # Storage Config
    nfs_enabled             = true
    nfs_mount_path          = "/mnt"

    gcs_volumes = [
      {
        name          = "my-data"
        mount_path    = "/data"
        read_only     = false
      }
    ]

    # Resources
    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "512Mi"
    }

    # Initialization Jobs (Cloud Run Jobs)
    initialization_jobs = [
      {
        name        = "init-db"
        description = "Initialize database"
        command     = ["/bin/sh", "-c"]
        args        = ["./init.sh"]
        mount_nfs   = true
        execute_on_apply = true
      }
    ]
  }

  # 2. Register the module
  application_modules = {
    mymodule = local.mymodule_module
  }

  # 3. Define Environment Variables (Static + Secrets)
  module_env_vars = {
    DB_HOST = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/..." : local.db_internal_ip
  }

  module_secret_env_vars = {
    ADMIN_PASS = try(google_secret_manager_secret.admin_pass.secret_id, "")
  }

  # 4. Define Storage Buckets
  module_storage_buckets = []
}
```

## 4. Variables & UIMeta (Standard Order)

Variables in `variables.tf` must follow the "Standard Order" and include `UIMeta` annotations for the platform UI.

| Group ID | Name | Description |
| :--- | :--- | :--- |
| **0** | Metadata | Module description, documentation links |
| **100** | Basic | Enable flags, public access, basic settings |
| **200** | Project | Project ID, Region, Tenant ID |
| **300** | Application | Version, specific app settings |
| **400** | CI/CD | GitHub repo, triggers |
| **500** | Env Vars | Custom environment variables |
| **600** | Health | Probes (startup, liveness) |
| **700** | Monitoring | Alerts, trusted users |
| **800** | Init Jobs | Custom job configs |
| **900** | Network | VPC, Ingress settings |
| **1000** | DB/Backup | Passwords, Backup config |

**Example:**
```hcl
variable "module_description" {
  description = "The description of the module. {{UIMeta group=0 order=100 }}"
  type        = string
  default     = "This module deploys MyModule"
}
```

## 5. Scripts & Docker

- Place Dockerfiles and scripts in `scripts/<module_name>/`.
- In `<module_name>.tf`, set `context_path = "<module_name>"` in `container_build_config`.
- This ensures Kaniko builds relative to `scripts/<module_name>/` but can access the root if needed (though typically restricted).

## 6. Creation Process

**Recommended:** Use the helper script to verify prerequisites and clone a base module.

1.  Run `./scripts/create_module.sh`.
2.  Select a similar existing module to clone (e.g., `Odoo` if you need DB + NFS).
3.  Enter the new module name.
4.  The script will:
    -   Clone the directory.
    -   Rename files (`Old.tf` -> `New.tf`).
    -   Replace internal strings.
    -   Setup symlinks.
5.  Edit `modules/NewModule/newmodule.tf` to customize logic.
6.  Edit `modules/NewModule/variables.tf` to update metadata.
