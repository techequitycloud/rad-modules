---
name: platform-module-context
description: Understand the GCP_Services module and how it configures Google Cloud services.
---

# Platform Module Context (GCP_Services)

The `modules/GCP_Services` module is responsible for setting up the shared foundational infrastructure on Google Cloud Platform. It does not deploy applications itself but prepares the environment for them.

## Key Resources

*   **Networking**: Configures the VPC network (`network.tf`), subnets, and Serverless VPC Access connectors required for Cloud Run services to communicate with internal resources (like Cloud SQL and Redis).
*   **Databases**:
    *   **Cloud SQL**: Deploys managed MySQL (`mysql.tf`) and PostgreSQL (`pgsql.tf`) instances. It handles user creation and database provisioning.
    *   **Redis**: Deploys Memorystore for Redis (`redis.tf`) for caching and session management.
*   **Storage**: Configures Filestore (NFS) instances (`filestore.tf`) for shared file storage if needed.
*   **IAM**: Sets up shared Service Accounts (`sa.tf`) and permissions.

## Usage

This module is typically applied *before* any application modules. Its outputs (e.g., VPC connector ID, Database connection names, Redis IP) are consumed by the `CloudRunApp` module and application modules to ensure they connect to the correct infrastructure.

## Outputs

Key outputs usually include:
*   `vpc_connector_id`: The ID of the Serverless VPC Access connector.
*   `sql_instance_connection_name`: The connection name for Cloud SQL instances.
*   `redis_host`: The IP address of the Redis instance.
*   `network_name`: The name of the VPC network.
