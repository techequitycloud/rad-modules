# Cyclos Module Technical Features

## Architecture
This module deploys the Cyclos application as a stateless service on **Google Cloud Run**, backed by **Cloud SQL (PostgreSQL)**. It leverages **NFS** for shared persistent storage requirements of the application (e.g., for generated reports or uploaded user documents).

## Cloud Capabilities

### Compute
- **Resource**: `google_cloud_run_v2_service`
- **Capabilities**:
  - Deploys the Cyclos container image (version controllable via `application_version`).
  - Configures resource limits (CPU/Memory) optimized for Java-based banking workloads.
  - Integration with **Secret Manager** to securely inject sensitive database credentials at runtime.

### Data Persistence
- **Database**: Connects to the PostgreSQL instance provisioned by the `GCP_Services` module.
- **File Storage**: Mounts an NFS volume (from `GCP_Services`) to the Cloud Run container to provide persistent, shared storage for application artifacts that must survive container restarts.

### Security
- **Identity**: Runs with a dedicated Service Account (`sa.tf`) with least-privilege access.
- **Traffic**: Ingress controls can restrict access to internal VPC traffic or allow public internet access based on the `public_access` variable.

## Configuration & Enhancement
- **Version Control**: The `application_version` variable allows seamless upgrades of the Cyclos software by simply changing the tag and re-applying Terraform.
- **Environment Tuning**: The module supports passing environment variables (`configure_environment`) to customize Cyclos runtime behavior (e.g., memory limits, timezone settings).
- **Monitoring**: Includes standard Cloud Run monitoring integration for latency, request count, and container instance count.
