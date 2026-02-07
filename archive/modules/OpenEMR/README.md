# OpenEMR Module

Deploys OpenEMR, an open-source electronic health records and medical practice management solution.

## Architecture
- **Base Image**: `openemr/openemr`.
- **Database**: MySQL/MariaDB.
- **Session Storage**: Uses Redis for session management to allow stateless scaling.

## Key Features
- **Stateless Design**: Configures `session.save_handler = redis`.
- **Port Configuration**: Dynamically updates Apache listening port based on Cloud Run's `$PORT`.
- **Logging**: Configures `mod_remoteip` and custom log formats to handle Cloud Run load balancer IPs.

## Dependencies
This module relies on:
`CloudRunApp`

## Usage
This module is intended to be used as part of the RAD Modules ecosystem. It is typically deployed via the wrapper configuration in the root of the repository or as a sub-module.

### Terraform
```hcl
module "OpenEMR" {
  source = "./modules/OpenEMR"

  # ... configuration variables
}
```
