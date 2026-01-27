# Medusa Module

This module provides a standalone medusa deployment using shared infrastructure components from the CloudRunApp module.

## Structure
- `modules/medusa/` - medusa-specific Terraform module
- `scripts/medusa/` - medusa-specific deployment scripts
- `config/` - Configuration examples and templates
- `medusa.tf` - Main medusa Terraform configuration (local copy)
- `variables.tf` - Module variables (local copy)
- Other application `.tf` files - Symbolic links to CloudRunApp applications
- Infrastructure `.tf` files - Symbolic links to shared CloudRunApp infrastructure

## Quick Start

### 1. Configure Variables
Copy and customize an example configuration:
```bash
# Copy example configuration
cp config/basic-medusa.tfvars my-config.tfvars

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
- advanced-medusa.tfvars
- basic-medusa.tfvars
- custom-medusa.tfvars

## File Organization

### Local Files (Copied)
- `medusa.tf` - Your application configuration
- `variables.tf` - Module variables
- `modules/medusa/` - Application-specific modules
- `scripts/medusa/` - Application-specific scripts

### Symlinked Files
- Infrastructure files (`main.tf`, `network.tf`, etc.) → `../CloudRunApp/`
- Other application files (`n8n.tf`, `cyclos.tf`, etc.) → `../CloudRunApp/`
- Shared modules (`modules/*/`) → `../../CloudRunApp/modules/`
- Shared scripts (`scripts/core/`, etc.) → `../../CloudRunApp/scripts/`

## Dependencies
This module depends on shared infrastructure files from the CloudRunApp module via symbolic links.
Ensure the CloudRunApp module is present in the parent directory.

## Generated Information
- **Generated:** Tue Jan 27 03:16:39 PM UTC 2026
- **Base Application:** medusa
- **Module Name:** Medusa
- **Script Version:** create_module.sh v3.5 (Fully Fixed and Tested)

## Support
For issues or questions, refer to the main rad-modules documentation or create an issue in the repository.
