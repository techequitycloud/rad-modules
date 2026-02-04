# Module Development Rules

This file outlines the rules and best practices for developing modules in this repository. Agents and engineers must follow these guidelines.

## 1. Global Rules
These rules apply to all modules in the `modules/` directory.

- **Naming Conventions:**
  - All files and directories must use `snake_case` (e.g., `my_module`, `service_account.tf`), except for module directories which use `PascalCase` (e.g., `CloudRunApp`, `GCP_Services`).
  - Terraform resource names must be descriptive and use `snake_case`.
- **Documentation:**
  - Every module MUST have a `README.md` file explaining its purpose, usage, inputs, and outputs.
  - `README.md` should follow the standard template found in existing modules.
  - All input variables in `variables.tf` MUST have a `description` field.
- **Terraform Structure:**
  - Use `main.tf` for primary logic, `variables.tf` for inputs, and `outputs.tf` for outputs.
  - Pin provider versions in `versions.tf`.
  - Format code using `terraform fmt`.

## 2. Platform Module Rules
Applies to modules providing base infrastructure (e.g., `GCP_Services`).

- **Independence:** Platform modules must be self-contained and NOT depend on other modules via symlinks.
- **Granularity:** Separate resources into logical files (e.g., `network.tf`, `sql.tf`, `redis.tf`).
- **Outputs:** Explicitly export all resource IDs, links, and connection details required by dependent modules.

## 3. Foundation Module Rules
Applies to the base wrapper module (e.g., `CloudRunApp`).

- **Role:** Serves as the foundation for Application Modules.
- **Flexibility:** Must support both custom deployments (via `application_module = "custom"`) and presets.
- **Presets Logic:** Use `modules.tf` (or similar) to handle preset selection logic based on `local.application_modules`.
- **Shared Scripts:** Core maintenance and deployment scripts must reside in `scripts/core/`.

## 4. Application Module Rules
Applies to specific application deployments (e.g., `Wordpress`, `Cyclos`, `Strapi`). These modules function as wrappers around `CloudRunApp`, injecting specific configuration and logic.

### 4.1. File System Structure
Each application module MUST adhere to the following directory and file structure:

- **`config/`**: Directory for configuration examples (e.g., `terraform.tfvars.example`).
- **`scripts/`**:
  - **`core`**: A symlink to `../../CloudRunApp/scripts/core`.
  - **`<module_name_lowercase>/`**: A directory containing the Dockerfile, entrypoint scripts, and local assets (e.g., `scripts/wordpress/Dockerfile`).
- **`README.md`**: Standard documentation file.
- **`<MODULE_NAME>.md`**: Detailed documentation file (e.g., `WORDPRESS.md`).
- **`variables.tf`**: A local file defining all input variables (must match CloudRunApp standard).
- **`<module_name_lowercase>.tf`**: The main configuration file for the module (e.g., `wordpress.tf`).
- **Symlinked Files**: The following files MUST be symlinks to `../CloudRunApp/<filename>`:
  - `buildappcontainer.tf`
  - `iam.tf`
  - `jobs.tf`
  - `main.tf`
  - `modules.tf`
  - `monitoring.tf`
  - `network.tf`
  - `nfs.tf`
  - `outputs.tf`
  - `provider-auth.tf`
  - `registry.tf`
  - `sa.tf`
  - `secrets.tf`
  - `service.tf`
  - `sql.tf`
  - `storage.tf`
  - `trigger.tf`
  - `versions.tf`

### 4.2. Module Configuration (`<module_name>.tf`)
The specific logic for the application resides in a single local `.tf` file (e.g., `wordpress.tf`). This file MUST define the following local variables:

- **`local.application_modules`**: A map defining the application preset. It must include:
  - `app_name`, `description`, `container_port`.
  - `container_build_config`: An object with:
    - `enabled = true`
    - `dockerfile_path = "Dockerfile"`
    - `context_path = "<module_name_lowercase>"` (This MUST match the directory name in `scripts/`).
  - `environment_variables`: Map of default env vars.
  - `initialization_jobs`: List of jobs (if any).
- **`local.module_env_vars`**: Map connecting Terraform variables to environment variables (e.g., `{ DB_HOST = local.db_host }`).
- **`local.module_secret_env_vars`**: Map connecting Secret Manager secrets to env vars.
- **`local.module_storage_buckets`**: List of GCS buckets to create.

### 4.3. Variables (`variables.tf`)
The `variables.tf` file MUST mirror the structure and content of `modules/CloudRunApp/variables.tf`.

**Variable Visibility & Ordering:**
- **Visibility:** The module creator and publisher dictate which variables are visible to end users.
- **Ordering:** Variables MUST be ordered using the `order` field within the `UIMeta` tag (e.g., `{{UIMeta order=100}}`).

**Standard Order:**
To maintain consistency across modules, utilize the following standard order sequence (in increments of 100):

- **Order 100: Basic Configuration**: `project_id`, `region`, `service_name`, `application_version`.
- **Order 200: CI/CD**: `github_repository_url`, `enable_cicd_trigger`.
- **Order 300: Container Resources**: `cpu`, `memory`, `min_instances`, `max_instances`.
- **Order 400: Storage & Data**: `nfs_server`, `gcs_volumes`, `enable_cloudsql_volume`.
- **Order 500: Environment Variables**: `environment_variables`, `secret_environment_variables`.
- **Order 600: Health Check**: `startup_probe_config`, `health_check_config`.
- **Order 700: Monitoring**: `alert_policies`, `trusted_users`.
- **Order 800: Initialization Jobs**: `initialization_jobs`.
- **Order 900: Network & Security**: `vpc_egress_setting`, `ingress_settings`.
- **Order 1000: Database Extensions & Backup**: `backup_source`, `enable_backup_import`, `postgres_extensions`.

You MUST NOT remove standard variables unless functionally impossible to support. You MAY add module-specific variables, but try to use the `environment_variables` map instead where possible.

### 4.4. Build Context
- The Docker build context is located in `scripts/<module_name_lowercase>/`.
- The `Dockerfile` MUST be present in this directory.
- `local.application_modules.<app>.container_build_config.context_path` MUST be set to `"<module_name_lowercase>"` to correctly reference this directory during the build process (handled by `buildappcontainer.tf`).
