# Sample Module

Deploys a simple sample application (Flask) to demonstrate module capabilities.

## Architecture
- **Base Image**: `python:3.11-slim`.
- **Framework**: Flask.
- **Database**: PostgreSQL (optional connection).

## Key Features
- **Demonstration**: Serves as a reference implementation for custom application modules.
- **DB Init**: Includes a script to initialize a sample database and user.

## Dependencies
This module relies on:
`CloudRunApp`

## Usage
This module is intended to be used as part of the RAD Modules ecosystem. It is typically deployed via the wrapper configuration in the root of the repository or as a sub-module.

### Terraform
```hcl
module "Sample" {
  source = "./modules/Sample"

  # ... configuration variables
}
```
