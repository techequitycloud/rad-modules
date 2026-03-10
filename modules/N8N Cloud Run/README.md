# N8N Module

Deploys n8n, a workflow automation tool.

## Architecture
- **Base Image**: `n8nio/n8n`.
- **Database**: PostgreSQL.

## Key Features
- **Custom Entrypoint**: Handles initialization and configuration.
- **Persistence**: Configured to persist workflow data to the database.

## Dependencies
This module relies on:
`CloudRunApp`

## Usage
This module is intended to be used as part of the RAD Modules ecosystem. It is typically deployed via the wrapper configuration in the root of the repository or as a sub-module.

### Terraform
```hcl
module "N8N" {
  source = "./modules/N8N"

  # ... configuration variables
}
```
