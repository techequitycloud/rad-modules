# Wordpress Module

This module provides a standalone wordpress deployment using shared infrastructure components from the CloudRunApp module.

## Structure
- `modules/wordpress/` - wordpress-specific Terraform module
- `scripts/wordpress/` - wordpress-specific deployment scripts
- `config/` - Configuration examples and templates
- `wordpress.tf` - Main wordpress Terraform configuration (local copy)
- `variables.tf` - Module variables (local copy)
- Other application `.tf` files - Symbolic links to CloudRunApp applications
- Infrastructure `.tf` files - Symbolic links to shared CloudRunApp infrastructure

## Quick Start

### 1. Configure Variables
Copy and customize an example configuration:
```bash
# Copy example configuration
cp config/basic-wordpress.tfvars my-config.tfvars

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
- advanced-wordpress.tfvars
- custom-wordpress.tfvars
- basic-wordpress.tfvars

## File Organization

### Local Files (Copied)
- `wordpress.tf` - Your application configuration
- `variables.tf` - Module variables
- `modules/wordpress/` - Application-specific modules
- `scripts/wordpress/` - Application-specific scripts

### Symlinked Files
- Infrastructure files (`main.tf`, `network.tf`, etc.) → `../CloudRunApp/`
- Other application files (`n8n.tf`, `cyclos.tf`, etc.) → `../CloudRunApp/`
- Shared modules (`modules/*/`) → `../../CloudRunApp/modules/`
- Shared scripts (`scripts/core/`, etc.) → `../../CloudRunApp/scripts/`

## Dependencies
This module depends on shared infrastructure files from the CloudRunApp module via symbolic links.
Ensure the CloudRunApp module is present in the parent directory.

## Generated Information
- **Generated:** Tue Jan 27 05:30:22 PM UTC 2026
- **Base Application:** wordpress
- **Module Name:** Wordpress
- **Script Version:** create_module.sh v3.5 (Fully Fixed and Tested)

## Support
For issues or questions, refer to the main rad-modules documentation or create an issue in the repository.
