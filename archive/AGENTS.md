# AGENTS.md

## Repository Overview

This repository contains Terraform modules and associated scripts for deploying various applications and infrastructure on Google Cloud Platform (GCP). The core logic resides in the `modules/` directory, which is organized by application or infrastructure service (e.g., `Django`, `Moodle`, `GCP_Project`).

The repository uses **OpenTofu** (`tofu`) as the Infrastructure as Code (IaC) tool.

## Directory Structure

*   `modules/`: Contains independent Terraform modules.
    *   `modules/<ModuleName>/`: The root directory for a specific module.
        *   `variables.tf`: Input variables for the module.
        *   `main.tf`: Core resource definitions (often entry points or general configurations).
        *   `outputs.tf`: Output values returned by the module.
        *   `versions.tf`: Provider and Terraform/OpenTofu version constraints.
        *   `service.tf`: (Common pattern) Cloud Run Service definitions.
        *   `jobs.tf`: (Common pattern) Cloud Run Job definitions (e.g., migrations, backups).
        *   `database.tf`, `sql.tf`: Database resources (Cloud SQL).
        *   `scripts/`: Shell scripts used by the module (often via `local-exec` or containerized jobs).
*   `rad-launcher/`: Scripts for initializing and launching the environment (e.g., OpenTofu installer).
*   `rad-ui/`: Configuration or resources related to the UI layer.

## Input Variables & Conventions

Variables in `variables.tf` follow specific conventions to support both the Terraform logic and a UI layer.

### Common Variable Groups

Most application modules share a set of standard variables:

*   **Deployment Meta**:
    *   `module_description`: A description of what the module does.
    *   `module_dependency`: List of modules that must be deployed before this one.
    *   `resource_creator_identity`: The Service Account email used to create resources.
    *   `trusted_users`: List of user emails with elevated privileges.
*   **Application Config**:
    *   `application_name`: Base name for the application (used in resource naming).
    *   `tenant_deployment_id`: A suffix or ID to uniqueness across deployments.
    *   `existing_project_id`: The GCP Project ID where resources will be deployed.
    *   `region`: GCP region (default often `us-central1`).
*   **Environment Flags**:
    *   `configure_development_environment`: Boolean to enable Dev resources.
    *   `configure_nonproduction_environment`: Boolean to enable QA/Staging resources.
    *   `configure_production_environment`: Boolean to enable Prod resources.
*   **CI/CD**:
    *   `configure_continuous_integration`: Enable CI pipelines (often GitHub Actions).
    *   `configure_continuous_deployment`: Enable CD pipelines (Cloud Deploy).
    *   `application_git_token`: (Sensitive) GitHub token for repo management.

### UI Metadata Tags

Variable descriptions often contain a special tag format: `{{UIMeta group=<int> order=<int> updatesafe }}`.
*   `group`: Grouping identifier for the UI.
*   `order`: Sort order within the group.
*   `updatesafe`: Indicates the variable can be safely modified after initial deployment.

**Do not remove these tags** when modifying variable descriptions.

## Resource Patterns

### Cloud Run Services & Jobs
*   **Services**: Defined in `service.tf`. Often deployed per environment (Dev, QA, Prod) based on the `configure_*_environment` flags.
*   **Jobs**: Defined in `jobs.tf`. Used for one-off tasks like database migrations (`migrate`), backups, or initial setup.
*   **Service Accounts**: Application modules typically use a dedicated Service Account (e.g., `cloud-run-sa`) for runtime identity.

### Database (Cloud SQL)
*   Managed in `sql.tf` or `database.tf`.
*   Modules often check for existing SQL instances or create new ones based on configuration.
*   Connection info is typically passed to Cloud Run services via Secret Manager or environment variables.

### CI/CD
*   `cicd.tf`, `clouddeploy.tf`: Define Cloud Build triggers and Cloud Deploy delivery pipelines.
*   Repo management often involves `local-exec` scripts or specific providers to configure GitHub repositories.

## Interaction & Workflow

1.  **Exploration**: Use `ls` and `read_file` to understand the specific module structure. `modules/Django` and `modules/Moodle` are good reference examples for complex application modules.
2.  **Modification**:
    *   When adding resources, look for existing files that logically group similar resources (e.g., put new jobs in `jobs.tf`).
    *   Maintain variable conventions (`variables.tf`).
    *   Update `outputs.tf` if new useful information is generated.
3.  **Verification**:
    *   Run `tofu init` and `tofu validate` within the module directory to ensure syntax correctness.
    *   Use `terraform-docs` (if available) to update `README.md` if documentation is required.

## Tools

*   **OpenTofu (`tofu`)**: The primary IaC tool. Compatible with Terraform.
*   **Bash**: The shell environment. Scripts in `scripts/` are bash scripts.
*   **GCP CLI (`gcloud`)**: Used within scripts and sometimes `local-exec` provisioners.
*   **Python**: Used for some helper scripts (e.g., in `rad-launcher/`).
