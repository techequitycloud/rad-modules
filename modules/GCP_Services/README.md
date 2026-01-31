# GCP Services Module

A foundational module that provisions core Google Cloud Platform services required by the application ecosystem. It handles networking, storage, and database infrastructure.

## Architecture
- **Networking**: Configures a VPC network, subnets, and Private Service Access for internal connectivity.
- **Storage (NFS)**: Provisions a Google Cloud Filestore instance for shared file storage (mounted as NFS).
- **Database (SQL)**: Provisions Cloud SQL instances (PostgreSQL or MySQL) with private IP connectivity.
- **Cache (Redis)**: Provisions Google Cloud Memorystore for Redis.

## Key Features
- Centralized infrastructure management.
- Private IP connectivity for secure communication between services.
- Configurable enablement of specific services (Redis, SQL, Filestore).

## Dependencies
This module relies on:
None. This is a standalone infrastructure module.

## Usage
This module is intended to be used as part of the RAD Modules ecosystem. It is typically deployed via the wrapper configuration in the root of the repository or as a sub-module.

### Terraform
```hcl
module "GCP_Services" {
  source = "./modules/GCP_Services"

  # ... configuration variables
}
```
