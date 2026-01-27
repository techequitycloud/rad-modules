# Sample Module

This module provides a standalone sample deployment using shared infrastructure components from the CloudRunApp module.

## Structure
- `modules/sample/` - sample-specific Terraform module
- `scripts/sample/` - sample-specific deployment scripts
- `config/` - Configuration examples and templates
- `sample.tf` - Main sample Terraform configuration (local copy)
- `variables.tf` - Module variables (local copy)
- Other application `.tf` files - Symbolic links to CloudRunApp applications
- Infrastructure `.tf` files - Symbolic links to shared CloudRunApp infrastructure

## Quick Start

### 1. Configure Variables
Copy and customize an example configuration:
```bash
# Copy example configuration
cp config/basic-sample.tfvars my-config.tfvars

# Edit with your settings
nano my-config.tfvars
```

### 2. Deploy
```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="my-config.tfvars"

# Deploy
terraform apply -var-file="my-config.tfvars"
```

## Example Configurations

The `config/` directory contains various configuration templates:
- advanced-sample.tfvars
- basic-sample.tfvars
- custom-sample.tfvars

## File Organization

### Local Files (Copied)
- `sample.tf` - Your application configuration
- `variables.tf` - Module variables
- `modules/sample/` - Application-specific modules
- `scripts/sample/` - Application-specific scripts

### Symlinked Files
- Infrastructure files (`main.tf`, `network.tf`, etc.) → `../CloudRunApp/`
- Other application files (`n8n.tf`, `cyclos.tf`, etc.) → `../CloudRunApp/`
- Shared modules (`modules/*/`) → `../../CloudRunApp/modules/`
- Shared scripts (`scripts/core/`, etc.) → `../../CloudRunApp/scripts/`

## Dependencies
This module depends on shared infrastructure files from the CloudRunApp module via symbolic links.
Ensure the CloudRunApp module is present in the parent directory.

## Generated Information
- **Generated:** Tue Jan 27 05:27:02 PM UTC 2026
- **Base Application:** sample
- **Module Name:** Sample
- **Script Version:** create_module.sh v3.5 (Fully Fixed and Tested)

## Support
For issues or questions, refer to the main rad-modules documentation or create an issue in the repository.
