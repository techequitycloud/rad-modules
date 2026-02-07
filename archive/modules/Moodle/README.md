# Moodle Module

Deploys Moodle, the world's most popular learning management system (LMS).

## Architecture
- **Base Image**: `php:8.3-apache`.
- **Database**: PostgreSQL/MySQL (supports both, usually configured with Cloud SQL).
- **Storage**: Uses NFS (Filestore) for `MOODLE_DATA_DIR` to support shared access across instances.

## Key Features
- **Performance**: Configures PHP OPcache and Apache `remoteip` for Cloud Run compatibility.
- **Auto-Install**: Entrypoint detects empty database and triggers installation.
- **Cron**: Runs a local cron service for Moodle's background tasks.
- **PDF Support**: Installs Ghostscript for PDF annotation.

## Dependencies
This module relies on:
`CloudRunApp`

## Usage
This module is intended to be used as part of the RAD Modules ecosystem. It is typically deployed via the wrapper configuration in the root of the repository or as a sub-module.

### Terraform
```hcl
module "Moodle" {
  source = "./modules/Moodle"

  # ... configuration variables
}
```
