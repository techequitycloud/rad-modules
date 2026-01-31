---
name: repository-context
description: Understand the overall repository structure, module organization, and common patterns.
---

# Repository Context

This repository contains a collection of Terraform modules for deploying applications on Google Cloud Platform, specifically leveraging Cloud Run.

## Directory Structure

The core of the repository is the `modules/` directory, which is organized into three main types of modules:

1.  **Platform Module**: `modules/GCP_Services`
    *   This module implements the foundational infrastructure shared across the project, such as VPC networks, Cloud SQL instances, Redis instances, and shared Service Accounts.
    *   It acts as the base layer upon which other modules build.

2.  **Foundation Module**: `modules/CloudRunApp`
    *   This module is a comprehensive wrapper that standardizes the deployment of applications on Cloud Run.
    *   It handles the complexity of Cloud Run services, IAM permissions, networking integration (Serverless VPC Access), Secret Manager, and more.
    *   It supports both "custom" applications and "presets".

3.  **Application Modules**: (e.g., `modules/Cyclos`, `modules/Wordpress`, `modules/Moodle`, etc.)
    *   These modules represent specific applications.
    *   They typically rely on `modules/CloudRunApp` to perform the actual deployment.
    *   They often symlink the Terraform files from `modules/CloudRunApp` and provide a specific configuration file (e.g., `cyclos.tf`, `wordpress.tf`) that defines the application parameters, container image, and initialization jobs.

## Common Patterns

*   **Symlinking**: Application modules avoid code duplication by symlinking core Terraform files (`main.tf`, `variables.tf`, etc.) from `modules/CloudRunApp`.
*   **Locals Configuration**: Application specifics are defined in a `locals` block within a dedicated `.tf` file in the application module's directory.
*   **Initialization Jobs**: Many applications require database schema creation or user setup, which are handled via `initialization_jobs` defined in the module configuration and executed as Cloud Run Jobs.
