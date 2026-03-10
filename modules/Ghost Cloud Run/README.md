# Ghost Module

Deploys Ghost, a professional publishing platform for newsletters and blogs.

## Architecture
- **Base Image**: `ghost`.
- **Database**: MySQL.
- **Storage**: Uses GCS for content storage (configured via bucket mounts).

## Key Features
- **Service URL Detection**: Custom entrypoint automatically detects the Cloud Run Service URL to configure Ghost's `url` parameter correctly.
- **Database Validation**: Validates MySQL connection before starting.
- **Custom Entrypoint**: Wraps the standard Ghost entrypoint to inject dynamic configuration.

## Dependencies
This module relies on:
`CloudRunApp`

## Usage
This module is intended to be used as part of the RAD Modules ecosystem. It is typically deployed via the wrapper configuration in the root of the repository or as a sub-module.

### Terraform
```hcl
module "Ghost" {
  source = "./modules/Ghost"

  # ... configuration variables
}
```
