---
title: CloudRunApp on Google Cloud Platform
sidebar_label: Cloud Run App
slug: /applications/cloud-run-app
---


import AudioPlayer from '@site/src/components/AudioPlayer';

# CloudRunApp on Google Cloud Platform

<img src="https://storage.googleapis.com/rad-public-2b65/modules/cloudrunapp_module.png" alt="CloudRunApp on Google Cloud Platform" style={{marginBottom: '20px'}} />

<AudioPlayer url="https://storage.googleapis.com/rad-public-2b65/modules/cloudrunapp_module.m4a" title="CloudRunApp on Google Cloud Platform Audio" />

<video width="100%" controls style={{marginTop: '20px'}}>
  <source src="https://storage.googleapis.com/rad-public-2b65/modules/cloudrunapp_module.mp4" type="video/mp4" />
  Your browser does not support the video tag.
</video>

This document provides a comprehensive analysis of the `CloudRunApp` module on Google Cloud Platform. It details the architecture, IAM configuration, service integrations, and potential enhancements.

---

## Overview

The `CloudRunApp` module is a foundational building block for deploying containerized applications on Google Cloud Run (v2). It is designed to be highly configurable and orchestrates not just the compute layer, but also the surrounding ecosystem of networking, storage, databases, and observability.

## Key Benefits
*   **Accelerated Deployment**: Reduces weeks of infrastructure boilerplate work into a single module instantiation.
*   **Security by Design**: Implements least-privilege IAM, VPC egress controls, and Secret Manager integration out of the box.
*   **Serverless Scalability**: Leverages Cloud Run to automatically scale from zero to N instances based on demand, optimizing costs.
*   **Production Ready**: Includes built-in support for observability (logging/monitoring), database connectivity (Cloud SQL Auth Proxy), and persistent storage (NFS/GCS).

## Functionality
*   **Compute**: Deploys Cloud Run v2 Services (Gen2 execution environment).
*   **Data Persistence**: Integrates with Cloud SQL, NFS, and GCS (including GCS Fuse).
*   **Lifecycle Management**: Supports initialization jobs (DB migrations, backups, setup).
*   **CI/CD**: Built-in support for Cloud Build triggers and image mirroring.

---

## 2. IAM & Access Control

The module implements a specific IAM strategy using dedicated Service Accounts (SA) to ensure least-privilege access where possible.

### Service Accounts
1.  **Cloud Run Service Account** (`cloud_run_sa`):
    *   **Identity**: This is the identity under which the application container runs.
    *   **Role**: `roles/secretmanager.secretAccessor`
        *   **Purpose**: Allows the app to read database passwords and other sensitive environment variables defined in Secret Manager.
    *   **Role**: `roles/storage.objectAdmin`
        *   **Purpose**: Grants full control over the storage buckets created by the module (e.g., for user uploads).
    *   **Role**: `roles/storage.legacyBucketReader`
        *   **Purpose**: Grants read access to bucket metadata, often required by legacy libraries or frameworks (like Django `django-storages`).

2.  **Cloud Build Service Account** (`cloud_build_sa`):
    *   **Identity**: Used by Cloud Build triggers for CI/CD.
    *   **Role**: `roles/run.developer`
        *   **Purpose**: Allows the build process to deploy new revisions to the Cloud Run service.
    *   **Role**: `roles/iam.serviceAccountUser`
        *   **Purpose**: Allows Cloud Build to act as the Cloud Run Service Account during deployment.

### Public Access
*   **Current State**: The module grants `roles/run.invoker` to `allUsers` (public internet) by default if the environment is configured.
*   **Finding**: The variable `public_access` (default: `true`) exists in `variables.tf`, but the implementation in `iam.tf` currently does not condition the `allUsers` binding on this variable. This means deployed services are public by default unless manually restricted post-deployment.

---

## 3. Service Configuration & Features

### A. Compute (Cloud Run)
*   **Resource Management**: Configurable CPU and Memory limits. Supports "Startup CPU Boost" to improve cold start times.
*   **Scaling**: Supports auto-scaling from `min_instance_count` (can be 0 for scale-to-zero) to `max_instance_count`.
*   **Protocols**: Supports `http1` (default) and `h2c` (HTTP/2 Cleartext).

### B. Database (Cloud SQL)
*   **Discovery**: The module does *not* provision Cloud SQL instances. It uses a dynamic script (`scripts/core/get-sqlserver-info.sh`) to discover existing instances in the project.
*   **Connectivity**:
    *   **Unix Socket**: Mounts the Cloud SQL instance as a volume (e.g., `/cloudsql/...`), enabling low-latency, secure connections without exposing TCP ports.
    *   **TCP/IP**: Falls back to injecting the `DB_HOST` IP address if needed.
*   **Credentials**: Automatically retrieves or generates DB passwords and stores them in Secret Manager.

### C. Storage
1.  **NFS (Network File System)**:
    *   **Discovery**: Automatically detects an existing NFS server in the region via `scripts/core/get-nfsserver-info.sh`.
    *   **Mounting**: Mounts the NFS share (e.g., `/mnt/nfs`) as a volume in the container, providing shared persistent storage across instances.
2.  **GCS (Object Storage)**:
    *   **Standard**: Creates buckets with configurable lifecycles and versioning.
    *   **GCS Fuse**: Supports mounting GCS buckets as file systems, allowing legacy apps to write to "files" that are actually objects in GCS.

### D. Networking
*   **VPC Access**: Uses **Direct VPC Egress** (via `network_interfaces`), removing the need for a separate Serverless VPC Access Connector component in supported regions. This improves performance and reduces cost.
*   **Validation**: Includes a script (`scripts/core/check_network.sh`) to validate the existence of the target VPC and Subnet before deployment to prevent runtime failures.

### E. Initialization Jobs (Cloud Run Jobs)
The module leverages Cloud Run Jobs to perform complex setup tasks that cannot be done during container startup:
*   **`nfs-setup`**: Prepares directory structures and permissions on the NFS server.
*   **`db-init` / `db-cleanup`**: Runs custom SQL or scripts for schema migration.
*   **`backup-import`**: Can automatically import a database dump from GCS or Google Drive during initial deployment.

---

## 4. Potential Enhancements

To improve the platform's security, flexibility, and observability, the following enhancements are recommended:

### 1. Security & Access Control
*   **Enforce `public_access` Variable**: Update `iam.tf` to strictly respect the `var.public_access` setting. If `false`, the `allUsers` binding should be removed.
*   **Cloud Armor Integration**: Add support for attaching Cloud Armor security policies (WAF, DDoS protection) directly to the Cloud Run service or via a Load Balancer integration.
*   **Granular Invokers**: Add a variable to accept a list of specific emails/groups (e.g., `allowed_invokers`) for internal-only applications, replacing the binary "Public vs Private" model.

### 2. Resilience & Deployment
*   **Traffic Splitting**: Currently, 100% of traffic is routed to the `latest` revision. Adding a `traffic_split` variable would allow for Canary or Blue/Green deployments (e.g., 10% to new, 90% to old).
*   **Multi-Region Support**: While `deployment_regions` is a variable, full active-active multi-region logic (with global load balancing) could be solidified.

### 3. Performance & Services
*   **Native Redis Support**: Currently, Redis support relies on external provisioning or wrappers. Adding a native option to provision or discover a **Cloud Memorystore (Redis)** instance would benefit caching-heavy apps (like Django/Magento).
*   **CDN Integration**: For public apps, integrating with **Cloud CDN** (via Load Balancer) would significantly improve static asset delivery speed.

### 4. Developer Experience
*   **Buildpacks**: The module supports custom Dockerfiles. Adding support for **Google Cloud Buildpacks** would allow deploying source code directly without needing to write/maintain a `Dockerfile`.

---
