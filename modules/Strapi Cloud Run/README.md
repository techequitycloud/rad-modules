# Strapi Module

Deploys Strapi, the leading open-source headless CMS.

## Architecture
- **Base Image**: Node.js (Alpine).
- **Database**: PostgreSQL.

## Key Features
- **Image Processing**: Installs `vips-dev` and `sharp` for image optimization.
- **Signal Handling**: Uses `tini` as the entrypoint.
- **Email Config**: Conditionally configures email provider based on environment variables.

## Dependencies
This module relies on:
`CloudRunApp`

## Usage
This module is intended to be used as part of the RAD Modules ecosystem. It is typically deployed via the wrapper configuration in the root of the repository or as a sub-module.

### Terraform
```hcl
module "Strapi" {
  source = "./modules/Strapi"

  # ... configuration variables
}
```
