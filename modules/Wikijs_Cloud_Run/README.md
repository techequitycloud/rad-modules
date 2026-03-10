# Wiki.js Module

Deploys Wiki.js, a modern and powerful wiki software.

## Architecture
- **Base Image**: Node.js based.
- **Database**: PostgreSQL.

## Key Features
- **Modern Stack**: Built on Node.js/Vue.js.
- **Storage**: Configurable for various storage backends.

## Dependencies
This module relies on:
`CloudRunApp`

## Usage
This module is intended to be used as part of the RAD Modules ecosystem. It is typically deployed via the wrapper configuration in the root of the repository or as a sub-module.

### Terraform
```hcl
module "Wikijs" {
  source = "./modules/Wikijs"

  # ... configuration variables
}
```
