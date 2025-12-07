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

### UI Metadata Tags

Variable descriptions often contain a special tag format: `{{UIMeta group=<int> order=<int> updatesafe }}`.

*   `group`: Grouping identifier for the UI.
    *   **Group 0**: Variables in group 0 are **not exposed** to the end user.
    *   **Group > 0**: Variables in any other group are displayed to the end user during the creation of a deployment, organized by the group number.
*   `order`: Sort order within the group.
*   `updatesafe`: Indicates the variable can be safely modified after initial deployment.

**Do not remove these tags** when modifying variable descriptions.

### Guidelines

*   **Minimize Exposed Variables**: The number of variables exposed to users (Groups > 0) should be minimized to keep the UI clean and simple.

### Mandatory Variables

The following variables **must** be included in the `variables.tf` file of every module. The default values below are examples and should be replaced with appropriate values for the specific module.

```hcl
variable "module_description" {
  description = "The description of the module. {{UIMeta group=0 order=100 }}"
  type        = string
  default     = "This module deploys a Django application on Google Cloud Run. Django is a high-level Python web framework that encourages rapid development and clean, pragmatic design."
}

variable "module_dependency" {
  description = "The list of dependent modules, listed in the order in which they should be deployed. {{UIMeta group=0 order=101 }}"
  type        = list(string)
  default     = ["GCP Project","GCP Services"]
}

variable "module_services" {
  description = "The list of module services. {{UIMeta group=0 order=102 }}"
  type = list(string)
  default = ["GCP", "Cloud Run", "Cloud SQL", "Secret Manager", "Cloud IAM"]
}

variable "credit_cost" {
  description = "The credits needed to deploy the module {{UIMeta group=0 order=103 }}"
  type        = number
  default     = 100
}

variable "require_credit_purchases" {
  description = "Set to true to require credit purchases to deploy this module. {{UIMeta group=0 order=104 }}"
  type        = bool
  default     = false
}

variable "enable_purge" {
  description = "Set to true to grant users the ability to purge the configuration of the module without deleting cloud resources. {{UIMeta group=0 order=105 }}"
  type        = bool
  default     = true
}

variable "public_access" {
  description = "Set to true to enable the module to accessible to all platform users. {{UIMeta group=0 order=106 }}"
  type = bool
  default = true
}

variable "deployment_id" {
  description = "Unique ID suffix for resources. Leave blank to enable the platform to generate a random ID."
  type        = string
  default     = null
}

variable "resource_creator_identity" {
  description = "The terraform Service Account used to create resources in the destination project. This Service Account must be assigned roles/owner IAM role in the destination project. {{UIMeta group=1 order=200 updatesafe }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "trusted_users" {
  description = "List of email addresses of trusted users permitted to receive deployment notifications. {{UIMeta group=1 order=201 updatesafe }}"
  type        = list(string)
  default     = []
}
```

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
