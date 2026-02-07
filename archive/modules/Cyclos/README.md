# Cyclos Module

Deploys Cyclos, a payment and banking software for communities and organizations.

## Architecture
- **Base Image**: `cyclos/cyclos`.
- **Database**: PostgreSQL 15.
- **Connectivity**: Uses TCP connectivity to the database.

## Key Features
- **PostgreSQL Extensions**: Automatically installs required extensions: `pg_trgm`, `uuid-ossp`, `cube`, `earthdistance`, `postgis`, `unaccent`.
- **Initialization**: Includes jobs to create the database, extensions, and the Cyclos user with appropriate permissions.
- **Health Checks**: Configured with TCP startup probes and HTTP liveness probes.

## Dependencies
This module relies on:
`CloudRunApp`

## Usage
This module is intended to be used as part of the RAD Modules ecosystem. It is typically deployed via the wrapper configuration in the root of the repository or as a sub-module.

### Terraform
```hcl
module "Cyclos" {
  source = "./modules/Cyclos"

  # ... configuration variables
}
```
