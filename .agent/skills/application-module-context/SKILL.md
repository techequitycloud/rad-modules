---
name: application-module-context
description: Understand how to work with Application Modules (e.g. Cyclos)
---

# Application Module Context

Application modules (like `Cyclos`, `Wordpress`, `Moodle`) are specialized modules that deploy specific applications using the `CloudRunApp` foundation.

## Pattern and Structure

1.  **Directory**: Located in `modules/<AppName>`.
2.  **Symlinks**: Most Terraform files (`main.tf`, `variables.tf`, `service.tf`, etc.) are symlinks to `../CloudRunApp/`. This means the logic is inherited from the foundation module.
3.  **Specific Configuration**: There is usually one unique `.tf` file (e.g., `cyclos.tf` for Cyclos) that defines the application-specific configuration.

## Example: Cyclos Module

In `modules/Cyclos/cyclos.tf`, you will find a `locals` block defining the module configuration:

```hcl
locals {
  cyclos_module = {
    app_name            = "cyclos"
    container_image     = "cyclos/cyclos"
    container_port      = 8080
    database_type       = "POSTGRES_15"

    # Initialization Jobs
    initialization_jobs = [
      {
        name        = "create-extensions"
        description = "Create required PostgreSQL extensions"
        # ... job definition ...
      }
    ]
    # ... other settings ...
  }
}
```

## How to Create/Modify an Application Module

1.  **Create Directory**: Create `modules/NewApp`.
2.  **Symlink**: Symlink all `.tf` files from `modules/CloudRunApp`.
3.  **Define Configuration**: Create `newapp.tf`. Define a local variable (e.g., `newapp_module`) with the configuration structure expected by `CloudRunApp`.
4.  **Inject Configuration**: In `newapp.tf`, ensure the `application_modules` local includes your new module configuration:
    ```hcl
    locals {
      application_modules = {
        newapp = local.newapp_module
      }
    }
    ```
5.  **Initialization Jobs**: If the app needs database setup (users, schema), define `initialization_jobs` in the configuration. These run as Cloud Run Jobs.
