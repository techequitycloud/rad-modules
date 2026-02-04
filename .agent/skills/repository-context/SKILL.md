---
name: repository-context
description: Understand the overall repository structure, module organization, and common patterns.
---

# Repository Context

This repository contains a collection of Terraform modules for deploying applications on Google Cloud Platform, specifically leveraging Cloud Run.

## Directory Structure

The core of the repository is the `modules/` directory, which is organized into three main types of modules:

1.  **Platform Module**: `modules/GCP_Services`
    *   This module implements the foundational infrastructure shared across the project, such as VPC networks, Cloud SQL instances, Redis instances, and shared Service Accounts.
    *   It acts as the base layer upon which other modules build.

2.  **Foundation Module**: `modules/CloudRunApp`
    *   This module is a comprehensive wrapper that standardizes the deployment of applications on Cloud Run.
    *   It handles the complexity of Cloud Run services, IAM permissions, networking integration (Serverless VPC Access), Secret Manager, and more.
    *   It supports both "custom" applications and "presets".

3.  **Application Modules**: (e.g., `modules/Cyclos`, `modules/Wordpress`, `modules/Moodle`, etc.)
    *   These modules represent specific applications.
    *   They typically rely on `modules/CloudRunApp` to perform the actual deployment.
    *   They often symlink the Terraform files from `modules/CloudRunApp` and provide a specific configuration file (e.g., `cyclos.tf`, `wordpress.tf`) that defines the application parameters, container image, and initialization jobs.

## Common Patterns

*   **Symlinking**: Application modules avoid code duplication by symlinking core Terraform files (`main.tf`, `variables.tf`, etc.) from `modules/CloudRunApp`.
*   **Locals Configuration**: Application specifics are defined in a `locals` block within a dedicated `.tf` file in the application module's directory.
*   **Initialization Jobs**: Many applications require database schema creation or user setup, which are handled via `initialization_jobs` defined in the module configuration and executed as Cloud Run Jobs.

## Module Development Governance

**CRITICAL**: All module development MUST follow the rules defined in **`modules/AGENTS.md`**.

### Global Rules (Apply to All Modules)

*   **Naming Conventions:**
    *   File naming: `snake_case` (e.g., `service_account.tf`, `my_module`)
    *   Module directory naming: `PascalCase` (e.g., `CloudRunApp`, `GCP_Services`, `Cyclos`)
    *   Terraform resource names: `snake_case` (descriptive)
*   **Documentation Requirements:**
    *   All modules MUST have a `README.md` file following the standard format
    *   All input variables in `variables.tf` MUST have a `description` field
    *   Application modules MUST have both `README.md` and `<MODULE_NAME>.md`
*   **Terraform Standards:**
    *   Use `main.tf` for primary logic, `variables.tf` for inputs, `outputs.tf` for outputs
    *   Pin provider versions in `versions.tf`
    *   Format code using `terraform fmt`

### Module-Type Specific Rules

**Platform Modules** (e.g., GCP_Services):
*   Self-contained: No dependencies on other modules via symlinks
*   Granular files: Separate resources logically (`network.tf`, `sql.tf`, `redis.tf`)
*   Explicit outputs: Export all resource IDs and connection details

**Foundation Modules** (e.g., CloudRunApp):
*   Support both custom deployments and presets
*   Shared scripts reside in `scripts/core/`
*   Use `modules.tf` for preset selection logic

**Application Modules** (e.g., Wordpress, Cyclos):
*   Require **18 specific symlinks** to CloudRunApp (see AGENTS.md section 4.1)
*   Specific directory structure with `config/`, `scripts/core/` symlink, and `scripts/<appname>/`
*   Build context path MUST match `scripts/<appname_lowercase>/` directory name
*   Variables MUST mirror CloudRunApp structure with standard ordering (see AGENTS.md section 4.3)

For complete details, see **`modules/AGENTS.md`**.

## Module Creation Workflow

### Automated Module Creation

Use the **`scripts/create_module.sh`** script to create new application modules:

**Approach**: Clone-based creation from existing modules

**Key Features:**
1.  **Source Selection**: Lists available application modules (excludes CloudRunApp, GCP_Services, GCP_Project, Sample)
2.  **Cloning with Symlinks**: Uses `cp -a` to preserve all attributes and symlinks
3.  **Artifact Cleanup**: Automatically removes:
    *   `.terraform` directories
    *   `*.lock.hcl` files
    *   Terraform plan and state files
    *   Log files
4.  **Automated Renaming**:
    *   Main TF file: `oldapp.tf` → `newapp.tf`
    *   Documentation: `OLDAPP.md` → `NEWAPP.md`
    *   Scripts directory: `scripts/oldapp/` → `scripts/newapp/`
5.  **Content Replacement**: Uses `find` + `sed` to replace module names across:
    *   `.tf`, `.tfvars` files
    *   `.sh`, `.md` files
    *   `.json`, `.yaml`, `Dockerfile`
6.  **Validation**: Checks for:
    *   Required files (main.tf, versions.tf, variables.tf)
    *   Valid symlinks (no broken links)
    *   Build context directory exists

**Usage:**
```bash
cd rad-modules/scripts
./create_module.sh
# Follow interactive prompts:
# 1. Select source module to clone
# 2. Enter new module name (PascalCase)
# 3. Script handles all renaming and cleanup
```

**What Gets Excluded from Cloning:**
*   CloudRunApp (foundation module)
*   GCP_Services (platform module)
*   GCP_Project (platform module)
*   Sample (reference module)

## Configuration File Organization

Each application module includes configuration examples in the `config/` directory:

**Configuration Tiers:**

*   **`basic-<app>.tfvars`**: Minimal configuration for quick deployment
    *   Essential variables only
    *   Suitable for development/testing
*   **`advanced-<app>.tfvars`**: Full-featured configuration
    *   Demonstrates all available options
    *   Production-ready settings
*   **`custom-<app>.tfvars`**: Specialized configurations
    *   Custom use cases
    *   Advanced scenarios

**Common Structure:**
```hcl
resource_creator_identity = ""
existing_project_id       = "your-gcp-project-id"
tenant_deployment_id      = "tenant-name"
deployment_region         = "us-central1"

# Module-specific variables
application_version       = "1.0.0"
container_resources = {
  cpu_limit    = "2000m"
  memory_limit = "4Gi"
}
# ... other configuration
```

## Documentation Structure

Each application module follows a standardized documentation pattern:

### Module-Level Documentation

**1. `README.md`** (30-50 lines):
*   Application overview and purpose
*   Architecture summary (base image, services, dependencies)
*   Key features and capabilities
*   Basic usage instructions
*   Dependencies notation (what it requires from GCP_Services)

**2. `<MODULE_NAME>.md`** (85-120 lines):
*   Comprehensive technical analysis
*   Service configurations in detail
*   IAM & security architecture
*   Feature deep-dives and implementation details
*   Known issues and limitations
*   Integration points with other modules

**Example:**
```
modules/Django/
├── README.md           # Quick overview
├── DJANGO.md          # Comprehensive guide
├── config/            # Configuration examples
└── ...
```

### Repository-Level Documentation

*   **`modules/AGENTS.md`**: Module development governance (binding rules)
*   **`SKILLS.md`**: Implementation details for skills/agents
*   **`docs/`**: User-facing documentation (mirrors modules structure)
*   **`CHANGELOG.md`**: Version history and changes
*   **`README.md`**: Repository overview and getting started

## Dependency Flow

Understanding the deployment order and dependency relationships:

```
┌─────────────────────┐
│   GCP_Services      │  Platform Layer
│  (Infrastructure)   │  - VPC Network
└──────────┬──────────┘  - Cloud SQL
           │             - Redis
           │             - Filestore NFS
           ↓
┌─────────────────────┐
│   CloudRunApp       │  Foundation Layer
│  (Deployment Logic) │  - Cloud Run Service
└──────────┬──────────┘  - IAM/Security
           │             - Build System
           │             - Jobs
           ↓
┌─────────────────────┐
│ Application Modules │  Application Layer
│ (Cyclos, Wordpress, │  - App Configuration
│  Django, Moodle...) │  - Custom Logic
└─────────────────────┘  - Init Jobs
```

**Key Output Consumption:**
```hcl
# Application modules consume GCP_Services outputs:
vpc_connector_id = var.vpc_connector_id  # From GCP_Services
sql_instance     = var.sql_instance      # From GCP_Services
redis_host       = var.redis_host        # From GCP_Services
nfs_server       = var.nfs_server        # From GCP_Services
```

This ensures applications connect to the correct infrastructure components.

## Testing New Modules

### Validation Checklist

**1. File Structure Validation:**
```bash
# Navigate to your new module
cd modules/YourApp

# Check all 18 required symlinks exist
ls -la *.tf | grep '\->'
# Should show: buildappcontainer.tf, iam.tf, jobs.tf, main.tf, modules.tf,
#              monitoring.tf, network.tf, nfs.tf, outputs.tf, provider-auth.tf,
#              registry.tf, sa.tf, secrets.tf, service.tf, sql.tf, storage.tf,
#              trigger.tf, versions.tf

# Verify scripts/core symlink
ls -la scripts/core
# Should point to: ../../CloudRunApp/scripts/core

# Confirm build context directory exists
ls scripts/yourapp/Dockerfile
# Should exist if using custom build
```

**2. Terraform Validation:**
```bash
cd modules/YourApp
terraform init
terraform validate
terraform fmt -check -recursive
```

**3. Configuration Testing:**
```bash
# Test with basic configuration
terraform plan -var-file=config/basic-yourapp.tfvars

# Verify no errors in plan
```

**4. Build Testing** (if custom build):
```bash
# Test Dockerfile builds successfully
docker build -t test-yourapp -f scripts/yourapp/Dockerfile scripts/yourapp/

# Verify image size is reasonable
docker images test-yourapp
```

**5. Deployment Testing:**
*   Deploy to a test GCP project
*   Verify Cloud Run service starts successfully
*   Test initialization jobs complete without errors
*   Validate database connectivity
*   Check health endpoints respond
*   Verify environment variables and secrets are injected
*   Test GCS volume mounts (if applicable)
*   Verify NFS mounts (if applicable)

### Common Validation Errors and Fixes

**Missing UIMeta tags in variables:**
```hcl
# Bad - no UIMeta tag
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

# Good - with UIMeta tag
# {{UIMeta group=0 order=100}}
variable "project_id" {
  description = "GCP project ID"
  type        = string
}
```

**Incorrect context_path:**
```hcl
# Bad - doesn't match directory name
container_build_config = {
  context_path = "myapp"  # But directory is scripts/my-app/
}

# Good - matches directory name
container_build_config = {
  context_path = "my-app"  # Matches scripts/my-app/
}
```

**Broken symlinks:**
```bash
# Check for broken symlinks
find . -type l ! -exec test -e {} \; -print

# Fix by recreating symlink
ln -sf ../CloudRunApp/main.tf main.tf
```

**Missing README or detailed .md file:**
```bash
# Both files are required
ls README.md           # Must exist
ls YOURAPP.md          # Must exist (uppercase module name)
```

**Inconsistent naming:**
```bash
# Bad - directory names
modules/my_app/        # Should be PascalCase
modules/myApp/         # Inconsistent

# Good
modules/MyApp/         # Correct PascalCase

# Bad - file names
service-account.tf     # Should be snake_case, not kebab-case
ServiceAccount.tf      # Should be snake_case, not PascalCase

# Good
service_account.tf     # Correct snake_case
```

## Common Troubleshooting

### Build Context Errors

**Problem**: "Error: context_path 'myapp' does not exist"

**Solution**: Ensure `container_build_config.context_path` matches the directory name in `scripts/`:
```bash
# Verify directory exists
ls -la scripts/myapp/

# Check context_path in <app>.tf
grep context_path modules/MyApp/myapp.tf
# Should output: context_path = "myapp"
```

### Symlink Issues

**Problem**: "Error: Failed to read file: main.tf"

**Solution**: Verify all required symlinks exist and are not broken:
```bash
# List all symlinks
ls -la modules/YourApp/*.tf | grep '\->'

# Check for broken symlinks
find modules/YourApp -type l ! -exec test -e {} \; -print

# Recreate broken symlinks
cd modules/YourApp
ln -sf ../CloudRunApp/main.tf main.tf
```

### Service Account Permissions

**Problem**: "Permission denied" when accessing Cloud SQL, GCS, or Secret Manager

**Solution**: Check service account IAM bindings:
1.  Review `sa.tf` for service account creation
2.  Check `iam.tf` for role bindings
3.  Verify the Cloud Run service is using the correct service account
4.  Common required roles:
    *   `roles/secretmanager.secretAccessor` - for secrets
    *   `roles/cloudsql.client` - for Cloud SQL
    *   `roles/storage.objectAdmin` - for GCS buckets

### Database Connection Failures

**Problem**: Application cannot connect to Cloud SQL database

**Solution**:
1.  **Verify VPC connector**: Check that `vpc_connector_id` is set and service is attached
2.  **Check connection method**: Most apps use private IP, not Cloud SQL Proxy
    ```hcl
    enable_cloudsql_volume = false  # Usually false
    ```
3.  **Validate credentials**: Ensure database user/password are in Secret Manager
4.  **Check database exists**: Initialization jobs should create the database
5.  **Test connection**:
    ```bash
    # From Cloud Run service
    gcloud run services describe <service-name> --region <region>

    # Check logs
    gcloud run services logs read <service-name> --region <region>
    ```

### Initialization Job Failures

**Problem**: Initialization jobs timeout or fail

**Solution**:
1.  **Check job logs**:
    ```bash
    gcloud run jobs executions list --job=<job-name> --region=<region>
    gcloud run jobs executions logs <execution-name> --region=<region>
    ```
2.  **Increase timeout**:
    ```hcl
    initialization_jobs = [{
      timeout_seconds = 1800  # Increase from default 600
    }]
    ```
3.  **Verify environment variables and secrets** are accessible
4.  **Ensure mount paths exist**: For NFS and GCS volumes
5.  **Check job execution order**: Jobs run sequentially via `run_ordered_jobs.py`

### GCS Fuse Mount Issues

**Problem**: "Permission denied" when writing to GCS volume

**Solution**: Container must run as UID 2000 for GCS Fuse compatibility:

```dockerfile
# In your Dockerfile
FROM python:3.11-slim

# GCS Fuse requires UID 2000
RUN useradd -m -u 2000 appuser

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN chown -R appuser:appuser /app

USER appuser  # Critical - must run as UID 2000
EXPOSE 8080
CMD ["python", "app.py"]
```

**Problem**: GCS volume not mounting

**Solution**:
1.  Verify bucket exists and has correct permissions
2.  Check `gcs_volumes` configuration in module locals
3.  Ensure service account has `roles/storage.objectAdmin`
4.  Verify mount path doesn't conflict with other volumes

### Variable Mirroring Issues

**Problem**: Terraform plan shows unexpected changes or variables missing

**Solution**: Ensure `variables.tf` mirrors CloudRunApp:
1.  Compare with `modules/CloudRunApp/variables.tf`
2.  Do NOT remove standard variables unless functionally impossible
3.  Maintain UIMeta tags and ordering
4.  Add module-specific variables at the end or use `environment_variables` map
