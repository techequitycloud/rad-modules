# Medusa Module

Deploys Medusa, an open-source headless commerce engine.

## Architecture
- **Base Image**: Node.js based custom build.
- **Database**: PostgreSQL.
- **Storage**: Uses GCS for file uploads.

## Key Features
- **Automated Migrations**: entrypoint runs `npx medusa migrations run` before starting the server.
- **Strict Builds**: Uses `yarn install --frozen-lockfile` for reproducible builds.
- **Tini**: Implements `tini` for proper signal handling in the container.

## Dependencies
This module relies on:
`CloudRunApp`

## Usage
This module is intended to be used as part of the RAD Modules ecosystem. It is typically deployed via the wrapper configuration in the root of the repository or as a sub-module.

### Terraform
```hcl
module "Medusa" {
  source = "./modules/Medusa"

  # ... configuration variables
}
```
