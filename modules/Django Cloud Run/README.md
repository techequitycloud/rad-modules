# Django Module

Deploys a Django-based Python web application platform.

## Architecture
- **Base Image**: `python:3.11-slim` (Multi-stage build).
- **Database**: PostgreSQL.
- **Server**: Gunicorn.

## Key Features
- **GCS Media**: Mounts a GCS bucket to `/app/media` for persistent media storage.
- **Initialization**: Includes jobs for database initialization (`db-init`) and migrations (`migrate`).
- **Postgres Extensions**: Enables `pg_trgm`, `unaccent`, `hstore`, `citext`.
- **Superuser Creation**: Automatically creates a Django superuser if credentials are provided.

## Dependencies
This module relies on:
`CloudRunApp`

## Usage
This module is intended to be used as part of the RAD Modules ecosystem. It is typically deployed via the wrapper configuration in the root of the repository or as a sub-module.

### Terraform
```hcl
module "Django" {
  source = "./modules/Django"

  # ... configuration variables
}
```
