---
title: GCP Project
sidebar_label: GCP Project
slug: /applications/gcp-project
---

import AudioPlayer from '@site/src/components/AudioPlayer';

# GCP Project on Google Cloud Platform

<img src="https://storage.googleapis.com/rad-public-2b65/modules/gcpproject_module.png" alt="GCP Project on Google Cloud Platform" style={{marginBottom: '20px'}} />

<AudioPlayer url="https://storage.googleapis.com/rad-public-2b65/modules/gcpproject_module.m4a" title="GCP Project on Google Cloud Platform Audio" />

<video width="100%" controls style={{marginTop: '20px'}}>
  <source src="https://storage.googleapis.com/rad-public-2b65/modules/gcpproject_module.mp4" type="video/mp4" />
  Your browser does not support the video tag.
</video>

## Overview
The **GCP Project** module is the starting point for your cloud journey. It automates the creation and configuration of a new Google Cloud Platform project, ensuring that your environment is set up with best practices from day one. This module handles the administrative overhead of project provisioning, allowing your team to focus on building applications rather than managing cloud settings.

## Key Benefits
- **Automated Setup**: Instantly provision a fully configured GCP project with a single action.
- **Financial Control**: Automatically configure billing accounts and set budget alerts to keep costs in check.
- **Security First**: Establish a secure baseline by assigning trusted users with appropriate permissions, avoiding the risks of overly permissive default roles.
- **Ready for Scale**: Pre-configures project quotas and API limits to support production-grade web applications immediately.

## Functionality
- Creates a new Google Cloud Project with a standardized naming convention.
- Links the project to your organization's billing account.
- Sets up budget alerts to notify stakeholders of spending thresholds.
- Enables a comprehensive suite of Google Cloud APIs required for modern application deployment.
- Assigns "Trusted User" roles to specified team members for safe project administration.

---

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
