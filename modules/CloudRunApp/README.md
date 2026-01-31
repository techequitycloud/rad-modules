# CloudRunApp Module

The base wrapper module that implements the core logic for deploying applications to Cloud Run. It standardizes identity, security, networking, and lifecycle management for all application modules.

## Architecture
- **Compute**: Deploys containerized applications to Cloud Run (Gen2).
- **Identity**: Manages Service Accounts for Cloud Run, Cloud Build, and Cloud SQL.
- **Security**: Integrates with Secret Manager for sensitive environment variables.
- **Networking**: Configures Serverless VPC Access Connectors and Load Balancing.

## Key Features
- **Lifecycle Hooks**: Supports initialization jobs (e.g., DB migrations) and cleanup jobs.
- **Storage Abstraction**: Handles NFS mounts (Filestore) and GCS FUSE mounts.
- **Database Management**: Includes scripts for database creation, user management, and safe deletion.
- **NFS Cleanup**: Implements robust logic to clean up NFS directories upon module destruction.

## Dependencies
This module relies on:
`GCP_Services` (for underlying infrastructure).

## Usage
This module is intended to be used as part of the RAD Modules ecosystem. It is typically deployed via the wrapper configuration in the root of the repository or as a sub-module.

### Terraform
```hcl
module "CloudRunApp" {
  source = "./modules/CloudRunApp"

  # ... configuration variables
}
```
