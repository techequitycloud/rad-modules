# Creating New Modules

This guide outlines how to create a new application module based on the `CloudRunApp` module architecture.

## Overview

The `CloudRunApp` module serves as a central hub for shared infrastructure components (networking, storage, IAM, Cloud Run services, etc.). Individual application modules (e.g., `Strapi`, `Wordpress`, `N8N`) act as wrappers that:

1.  **Symlink Shared Infrastructure**: Reuse core Terraform files from `CloudRunApp` to maintain consistency and reduce duplication.
2.  **Define Application Logic**: Provide a specific configuration file (`<app>.tf`) that defines the application's container image, environment variables, database requirements, and initialization jobs.
3.  **Local Variables**: Override standard variables using a local `variables.tf`.

## Method 1: Automated Creation (Recommended for Existing Apps)

If the application you want to deploy is already defined within `modules/CloudRunApp` (i.e., it has a corresponding `<app>.tf` file in `modules/CloudRunApp/`), you can use the automated script.

1.  **Run the Script**:
    ```bash
    ./scripts/create_module.sh
    ```

2.  **Follow the Prompts**:
    - Enter a name for your new module (e.g., `MyCompanyBlog`).
    - Select the base application from the list (e.g., `wordpress`).

3.  **Verify**:
    - The script will create the directory structure, symlinks, and configuration files automatically.
    - Check the `modules/<NewModule>/README.md` for specific instructions.

## Method 2: Manual Creation (For New Applications)

If you are adding a completely new application that does not exist in `CloudRunApp`, follow these steps to create a new module wrapper.

### 1. Create Directory Structure

Create the module directory and necessary subdirectories:

```bash
# Replace MyNewApp with your module name
export MODULE_NAME="MyNewApp"
export APP_NAME="mynewapp" # Lowercase, no spaces

mkdir -p modules/$MODULE_NAME/{config,modules,scripts}
mkdir -p modules/$MODULE_NAME/scripts/$APP_NAME
```

### 2. Symlink Shared Infrastructure

Run the following commands to create symbolic links to the shared `CloudRunApp` infrastructure files. Run this from the root of the repo:

```bash
cd modules/$MODULE_NAME

# Infrastructure files
ln -sf ../CloudRunApp/buildappcontainer.tf buildappcontainer.tf
ln -sf ../CloudRunApp/iam.tf iam.tf
ln -sf ../CloudRunApp/jobs.tf jobs.tf
ln -sf ../CloudRunApp/main.tf main.tf
ln -sf ../CloudRunApp/modules.tf modules.tf
ln -sf ../CloudRunApp/monitoring.tf monitoring.tf
ln -sf ../CloudRunApp/network.tf network.tf
ln -sf ../CloudRunApp/nfs.tf nfs.tf
ln -sf ../CloudRunApp/outputs.tf outputs.tf
ln -sf ../CloudRunApp/provider-auth.tf provider-auth.tf
ln -sf ../CloudRunApp/registry.tf registry.tf
ln -sf ../CloudRunApp/sa.tf sa.tf
ln -sf ../CloudRunApp/secrets.tf secrets.tf
ln -sf ../CloudRunApp/service.tf service.tf
ln -sf ../CloudRunApp/sql.tf sql.tf
ln -sf ../CloudRunApp/storage.tf storage.tf
ln -sf ../CloudRunApp/trigger.tf trigger.tf
ln -sf ../CloudRunApp/versions.tf versions.tf

# Core scripts
cd scripts
ln -sf ../../CloudRunApp/scripts/core core
cd ../..
```

### 3. Create Application Configuration

Create a file named `${APP_NAME}.tf` in `modules/${MODULE_NAME}/`. This file defines your application's specific settings.

**Template (`modules/${MODULE_NAME}/${APP_NAME}.tf`):**

```hcl
locals {
  # Define the module configuration
  my_app_module = {
    app_name            = "mynewapp"
    display_name        = "My New Application"
    description         = "A custom application deployed on Cloud Run"

    # Container Image
    container_image     = "gcr.io/my-project/my-image:latest"
    # OR for custom build:
    # image_source        = "custom"
    # container_build_config = {
    #   enabled         = true
    #   dockerfile_path = "Dockerfile"
    #   context_path    = "."
    # }

    container_port      = 8080

    # Database Configuration (Optional)
    database_type       = "POSTGRES_15" # or MYSQL_8_0, NONE
    db_name             = "myappdb"
    db_user             = "myappuser"

    # Resources
    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "512Mi"
    }

    min_instance_count = 0
    max_instance_count = 5

    # Environment Variables
    environment_variables = {
      ENV_VAR_1 = "value1"
    }

    # Probes
    startup_probe = {
      enabled = true
      path    = "/health"
    }
    liveness_probe = {
      enabled = true
      path    = "/health"
    }

    # Initialization Jobs (Optional)
    initialization_jobs = []
  }

  # Register the module
  application_modules = {
    mynewapp = local.my_app_module
  }

  # Map infrastructure values to App Environment Variables
  module_env_vars = {
    DB_HOST = local.enable_cloudsql_volume ? "/cloudsql/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip
  }

  # Map Secrets
  module_secret_env_vars = {}

  # Define Storage Buckets
  module_storage_buckets = []
}
```

### 4. Create Variables File

Copy `variables.tf` from `CloudRunApp` or another module, or create a new one.

**Template (`modules/${MODULE_NAME}/variables.tf`):**

```hcl
variable "module_description" {
  description = "The description of the module."
  type        = string
  default     = "This module deploys MyNewApp on Cloud Run."
}

variable "module_dependency" {
  description = "Modules this module depends on."
  type        = list(string)
  default     = ["GCP_Services"]
}

# ... Add standard variables from CloudRunApp/variables.tf ...
# It is recommended to copy the full variables.tf from modules/CloudRunApp/variables.tf
# and adjust defaults as needed.
```

### 5. Create README

Create a `README.md` file in `modules/${MODULE_NAME}/` describing the module and how to use it.

## Verification

1.  **Initialize Terraform**:
    ```bash
    cd modules/$MODULE_NAME
    terraform init
    ```

2.  **Validate Configuration**:
    ```bash
    terraform validate
    ```

3.  **Plan Deployment**:
    Create a `terraform.tfvars` or use defaults.
    ```bash
    terraform plan
    ```

If the plan succeeds without errors, your new module is ready!
