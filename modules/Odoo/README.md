# Odoo Module

This module provides a standalone odoo deployment using shared infrastructure components from the CloudRunApp module.

## Structure
- `modules/odoo/` - odoo-specific Terraform module
- `scripts/odoo/` - odoo-specific deployment scripts
- `examples/` - Configuration examples and templates
- `odoo.tf` - Main odoo Terraform configuration
- `variables.tf` - Module variables
- Other `.tf` files - Symbolic links to shared CloudRunApp infrastructure

## Quick Start

### 1. Configure Variables
Copy and customize an example configuration:
```bash
# Copy example configuration
cp examples/basic-odoo.tfvars my-config.tfvars

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

The `examples/` directory contains various configuration templates:
- nodejs-app.tfvars
- simple-cloudrunapp.tfvars
- advanced-cloudrunapp.tfvars

## Dependencies
This module depends on shared infrastructure files from the CloudRunApp module via symbolic links.
Ensure the CloudRunApp module is present in the parent directory.

## Generated Information
- **Generated:** Sun 25 Jan 2026 20:42:21 GMT
- **Base Application:** odoo
- **Module Name:** Odoo
- **Script Version:** create_module.sh v3.2 (macOS Bash 3.2 Compatible)

## Support
For issues or questions, refer to the main rad-modules documentation or create an issue in the repository.
