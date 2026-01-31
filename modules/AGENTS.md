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
Applies to specific application deployments (e.g., `Wordpress`, `Cyclos`).

- **Inheritance:** MUST symlink shared infrastructure files (e.g., `main.tf`, `network.tf`, `variables.tf`) from the Foundation Module (`CloudRunApp`).
- **Configuration:**
  - MUST include a specific `.tf` file named after the application (e.g., `wordpress.tf`).
  - This file MUST define `locals { application_modules = { <App> = { ... } } }` containing the preset configuration.
- **Directory Structure:**
  - `scripts/<App>/`: specific scripts and Dockerfiles.
  - `config/`: example `tfvars` files.
- **No Redundancy:** Do not duplicate infrastructure code; rely on the Foundation Module.
