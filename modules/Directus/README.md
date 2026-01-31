# Directus Module

Deploys Directus, an open-source headless CMS and Backend-as-a-Service.

## Architecture
- **Base Image**: `directus/directus`.
- **Database**: PostgreSQL (Cloud SQL).
- **Storage**: Uses Google Cloud Storage (GCS) driver for file uploads.

## Key Features
- **Custom Build**: Installs `@directus/storage-driver-gcs` to support stateless file storage.
- **Auto-Migration**: Supports automatic database migrations (`AUTO_MIGRATE`) and bootstrapping (`BOOTSTRAP`) on startup.
- **Fail-Fast**: Entrypoint script implements retry logic for DB connection and fail-fast mechanisms for critical errors.

## Dependencies
This module relies on:
`CloudRunApp`

## Usage
This module is intended to be used as part of the RAD Modules ecosystem. It is typically deployed via the wrapper configuration in the root of the repository or as a sub-module.

### Terraform
```hcl
module "Directus" {
  source = "./modules/Directus"

  # ... configuration variables
}
```
