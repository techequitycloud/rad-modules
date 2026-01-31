---
name: foundation-module-context
description: Understand the CloudRunApp foundation module and its core functionality.
---

# Foundation Module Context (CloudRunApp)

The `modules/CloudRunApp` module is the cornerstone of application deployment in this repository. It serves as a unified wrapper that abstracts the complexities of deploying containerized applications to Cloud Run.

## Core Responsibilities

1.  **Cloud Run Service**: Deploys the Cloud Run service (`service.tf`), configuring container image, ports, resources (CPU/Memory), and environment variables.
2.  **Networking**: Connects the service to the VPC via Serverless VPC Access (`network.tf`), enabling access to private resources like Cloud SQL and Redis.
3.  **Database Integration**: Automatically handles Cloud SQL connection strings and Sidecar (if needed), or private IP connections.
4.  **Secrets Management**: Integrates with Secret Manager (`secrets.tf`) to securely inject sensitive environment variables.
5.  **IAM**: Manages Service Accounts (`sa.tf`) and IAM bindings (`iam.tf`) for the Cloud Run service.
6.  **Presets**: Implements a "preset" system (`modules.tf`) that allows deploying standard applications (like generic web apps) with pre-configured defaults.

## Key Inputs

*   `application_module`: Determines the mode of operation. If set to `"custom"`, it expects manual configuration. If set to a preset name (e.g., `"cloudrunapp"`), it loads defaults.
*   `container_image`: The Docker image to deploy.
*   `container_port`: The port the container listens on.
*   `env_vars`: Map of environment variables to inject.
*   `secret_env_vars`: Map of secrets to inject.

## Architecture

This module is designed to be **reusable**. Application modules (like `Cyclos`, `Wordpress`) rely on it by symlinking its Terraform files. This ensures consistency across all deployed applications and simplifies maintenance.
