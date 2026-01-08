# GCP Project Module Technical Features

## Architecture
This module uses Terraform to bootstrap a Google Cloud Project, serving as the root dependency for all subsequent infrastructure modules. It abstracts the complexity of the `google_project` and `google_project_service` resources.

## Cloud Capabilities

### Project Provisioning
- **Resource**: `google_project`
- **Details**: Creates the project within a specified Folder or Organization. Handles random ID generation for uniqueness.

### API Management
- **Resource**: `google_project_service`
- **Capabilities**: Automatically enables essential APIs including:
  - Compute Engine API
  - Kubernetes Engine API
  - Cloud SQL Admin API
  - Cloud Run API
  - Cloud Build & Artifact Registry APIs
  - Secret Manager API
  - Cloud ResourceManager & IAM APIs

### Quota Management
- **Resource**: `google_service_usage_consumer_quota_override`
- **Capabilities**: Applies pre-defined quota overrides optimized for web application workloads (e.g., increased limits for Load Balancers, SSL Certificates, and Network Endpoint Groups) to prevent early deployment failures.

### Identity & Access Management (IAM)
- **Resource**: `google_project_iam_member`
- **Capabilities**: Defines a `trusted_users` variable to programmatically assign a curated set of roles (e.g., Editor, Secret Accessor) to a list of user emails, centralizing access control code.

## Configuration & Enhancement
- **Custom APIs**: Technical users can extend the `enable_services` logic to include additional APIs required for specific workloads (e.g., AI/ML APIs).
- **Quota Tuning**: The module includes a complex variable `quota_overrides` that allows granular adjustment of specific metric limits (e.g., `SNAPSHOTS`, `IMAGES`, `NETWORKS`) without modifying the core module logic.
