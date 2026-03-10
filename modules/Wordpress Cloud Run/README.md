# Wordpress Module

Deploys WordPress, the world's most popular content management system.

## Architecture
- **Base Image**: `php:8.4-apache`.
- **Database**: MySQL/MariaDB.
- **Caching**: Redis (Object Cache).

## Key Features
- **Performance**: Installs `redis` extension and `opcache`.
- **Media**: Installs `ghostscript` and `imagick` for media handling.
- **Cloud Run Ready**: Configures `mod_remoteip` for correct IP logging behind load balancers.
- **WP-CLI**: Includes WP-CLI for command-line management.
- **Security**: Generates unique salts and keys on startup.

## Dependencies
This module relies on:
`CloudRunApp`

## Usage
This module is intended to be used as part of the RAD Modules ecosystem. It is typically deployed via the wrapper configuration in the root of the repository or as a sub-module.

### Terraform
```hcl
module "Wordpress" {
  source = "./modules/Wordpress"

  # ... configuration variables
}
```
