# Odoo Module

Deploys Odoo, a comprehensive suite of business applications (ERP, CRM, eCommerce).

## Architecture
- **Base Image**: `ubuntu:noble` (Custom build installing Odoo 19.0).
- **Database**: PostgreSQL.
- **Storage**: Uses NFS for `filestore` and `sessions`.

## Key Features
- **Dynamic Config**: Entrypoint dynamically updates `odoo.conf` with the correct DB name and settings.
- **Dependencies**: Installs `wkhtmltopdf` for PDF report generation and `postgresql-client-16`.
- **Permissions**: Sets up correct user permissions (uid 101) for NFS mounts.

## Dependencies
This module relies on:
`CloudRunApp`

## Usage
This module is intended to be used as part of the RAD Modules ecosystem. It is typically deployed via the wrapper configuration in the root of the repository or as a sub-module.

### Terraform
```hcl
module "Odoo" {
  source = "./modules/Odoo"

  # ... configuration variables
}
```
