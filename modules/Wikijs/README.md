# Wikijs Module

This module provides a standalone wikijs deployment using shared infrastructure components from the CloudRunApp module.

## Structure
- `modules/wikijs/` - wikijs-specific Terraform module
- `scripts/wikijs/` - wikijs-specific deployment scripts
- `config/` - Configuration examples and templates
- `wikijs.tf` - Main wikijs Terraform configuration (local copy)
- `variables.tf` - Module variables (local copy)
- Other application `.tf` files - Symbolic links to CloudRunApp applications
- Infrastructure `.tf` files - Symbolic links to shared CloudRunApp infrastructure

## Quick Start

### 1. Configure Variables
Copy and customize an example configuration:
```bash
# Copy example configuration
cp config/basic-wikijs.tfvars my-config.tfvars

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
- advanced-wikijs.tfvars
- custom-wikijs.tfvars
- basic-wikijs.tfvars

## File Organization

### Local Files (Copied)
- `wikijs.tf` - Your application configuration
- `variables.tf` - Module variables
- `modules/wikijs/` - Application-specific modules
- `scripts/wikijs/` - Application-specific scripts

### Symlinked Files
- Infrastructure files (`main.tf`, `network.tf`, etc.) → `../CloudRunApp/`
- Other application files (`n8n.tf`, `cyclos.tf`, etc.) → `../CloudRunApp/`
- Shared modules (`modules/*/`) → `../../CloudRunApp/modules/`
- Shared scripts (`scripts/core/`, etc.) → `../../CloudRunApp/scripts/`

## Dependencies
This module depends on shared infrastructure files from the CloudRunApp module via symbolic links.
Ensure the CloudRunApp module is present in the parent directory.

## Generated Information
- **Generated:** Tue Jan 27 05:29:50 PM UTC 2026
- **Base Application:** wikijs
- **Module Name:** Wikijs
- **Script Version:** create_module.sh v3.5 (Fully Fixed and Tested)

## Support
For issues or questions, refer to the main rad-modules documentation or create an issue in the repository.
