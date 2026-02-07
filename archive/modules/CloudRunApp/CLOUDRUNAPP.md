# CloudRunApp on Google Cloud Platform

This document provides a comprehensive analysis of the `modules/CloudRunApp` Terraform module on Google Cloud Platform. It details the architecture, IAM configuration, service integrations, and potential enhancements.

---

## 1. Module Overview

The `modules/CloudRunApp` module is a foundational building block for deploying containerized applications on Google Cloud Run (v2). It is designed to be highly configurable and orchestrates not just the compute layer, but also the surrounding ecosystem of networking, storage, databases, and observability.

**Key Capabilities:**
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

