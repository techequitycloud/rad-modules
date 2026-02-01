# Deep Dive Analysis: modules/Medusa

This document provides a comprehensive technical analysis of the `modules/Medusa` implementation on Google Cloud Platform. It details the architecture, IAM configuration, service integrations, and operational logic, along with recommendations for enhancements.

## 1. Architecture Overview

The `modules/Medusa` module is implemented as a **wrapper module** around the shared `modules/CloudRunApp` infrastructure. It utilizes a symlink-based architecture where core Terraform files (`main.tf`, `iam.tf`, `service.tf`, etc.) are shared with the base Cloud Run application module, while specific configuration is injected via `medusa.tf`.

**Deployment Architecture:**
*   **Compute:** Cloud Run (Gen 2) hosting the Medusa backend.
*   **Database:** Cloud SQL (PostgreSQL 15).
*   **Storage:** Google Cloud Storage (GCS) mounted via GCS Fuse for file uploads.
*   **Secrets:** Secret Manager for sensitive credentials (JWT, Cookie secrets, DB passwords).
*   **Networking:** Private IP connection to Cloud SQL (implied via VPC access or Auth Proxy sidecar).

## 2. IAM and Access Control

The module adheres to the principle of least privilege but relies on a pre-existing Service Account structure.

### Service Accounts

*   **Cloud Run Service Account (`cloudrun-sa`):**
    *   **Default:** The module expects a service account named `cloudrun-sa` (or defined via `var.cloudrun_service_account`) to exist. **It does not create this account itself.**
    *   **Usage:** Used as the identity for the Cloud Run revision and for accessing backing services.

### IAM Roles & Permissions

The `iam.tf` configuration explicitly binds the following roles to the Cloud Run Service Account:

| Resource Type | Role | Scope | Purpose |
| :--- | :--- | :--- | :--- |
| **Secret Manager** | `roles/secretmanager.secretAccessor` | Specific Secrets | Allows access to `DB_PASSWORD`, `JWT_SECRET`, `COOKIE_SECRET`. |
| **Cloud Storage** | `roles/storage.objectAdmin` | Specific Bucket | Full control over the `*-medusa-uploads` bucket for storing product images/files. |
| **Cloud Storage** | `roles/storage.legacyBucketReader` | Specific Bucket | Metadata access (often required for certain storage libraries). |

### Optional Configuration
*   **CI/CD Identity:** If `enable_cicd_trigger` is true, a Cloud Build Service Account (`cloudbuild-sa`) is granted `roles/run.developer` and `roles/iam.serviceAccountUser` to deploy revisions.

## 3. Services Implemented

### 3.1. Cloud Run (Compute)
*   **Runtime:** Custom Node.js 20 container (Alpine Linux based).
*   **Scaling:** Defaults to Min 0 / Max 3 instances (`min_instance_count` / `max_instance_count`).
*   **Resources:** Defaults to 1 CPU, 2Gi Memory.
*   **Probes:**
    *   **Startup Probe:** HTTP GET `/health` (120s delay).
    *   **Liveness Probe:** HTTP GET `/health`.

### 3.2. Cloud SQL (Database)
*   **Engine:** PostgreSQL 15.
*   **Configuration:** Configured via `modules/CloudRunApp` presets.
*   **Connection:**
    *   The application supports connection via **Unix Socket** (`/var/run/postgresql`) or **TCP/IP**.
    *   `medusa-config.js` contains logic to detect the socket path and construct the `DATABASE_URL` accordingly.
    *   `ssl` is explicitly disabled in the application config (`ssl: false`), appropriate for Auth Proxy or Private IP connections.

### 3.3. Cloud Storage (Assets)
*   **Bucket:** Creates a dedicated bucket with suffix `medusa-uploads`.
*   **Mounting:** Uses **GCS Fuse** to mount this bucket to `/app/medusa/uploads` inside the container.
*   **Application Logic:**
    *   The `medusa-plugin-file-cloud-storage` plugin is effectively **disabled** by configuration (`MEDUSA_FILE_GOOGLE_BUCKET = ""`).
    *   Instead, Medusa uses the `file-local` strategy, pointing to the mounted directory (`/app/medusa/uploads`). This provides filesystem-like access to GCS without requiring plugin configuration handling.

### 3.4. Secret Manager
*   **Generated Secrets:**
    *   `jwt-secret`: Random 32-char string.
    *   `cookie-secret`: Random 32-char string.
*   **Injection:** These are injected as environment variables `JWT_SECRET` and `COOKIE_SECRET`.

## 4. Configuration & Build Analysis

### Build Process (`scripts/medusa/Dockerfile`)
*   **Base Image:** `node:20-alpine`.
*   **Dependencies:** Installs `python3`, `make`, `g++`, `git` for building native Node modules.
*   **Flow:** Copies `package.json` -> `yarn install` -> Copies source -> `yarn build`.
*   **Critical Finding (Current State):** The Dockerfile sets `CMD ["node", "debug-start.js"]`. Analysis of `debug-start.js` suggests it runs diagnostics and migrations but **does not start the actual server**. This appears to be a debug configuration that needs to be switched to `medusa start` for production use.

### Initialization Jobs
The module defines two key initialization jobs that run on Terraform apply:
1.  **`db-init`:** A robust shell script running in `alpine:3.19` that waits for the DB, checks for the `medusa_user`, creates it if missing, and creates the `medusa_db`.
2.  **`medusa-migrations`:** Runs `npx medusa migrations run` to apply schema changes.

## 5. Potential Enhancements & Recommendations

### 5.1. Fix Startup Command (Critical)
The current `CMD` in the Dockerfile points to a debug script that exits.
*   **Recommendation:** Change `CMD` in `scripts/medusa/Dockerfile` to `["medusa", "start"]` or `["npm", "start"]` to ensure the application serves traffic.

### 5.2. Redis Integration
While `REDIS_URL` is read by the config, the module currently explicitly configures the Event Bus and Cache Service to use **local/in-memory** providers:
```javascript
modules: {
  eventBus: { resolve: "@medusajs/event-bus-local" },
  cacheService: { resolve: "@medusajs/cache-inmemory" }
}
```
*   **Recommendation:** For production resilience, enable Memorystore (Redis).
    *   Update `medusa.tf` to provision a Redis instance (supported by `CloudRunApp` module via variables).
    *   Update `medusa-config.js` to switch `resolve` to `@medusajs/event-bus-redis` and `@medusajs/cache-redis` when `REDIS_URL` is present.

### 5.3. Search Integration (Meilisearch)
Medusa typically requires a search engine for storefron functionality.
*   **Recommendation:** Add a `modules/Meilisearch` component or configure an external search provider, as the current setup has no search plugin enabled.

### 5.4. Worker Separation
For high-traffic stores, the Medusa backend should be split into "server" and "worker" services.
*   **Recommendation:** Create a secondary Cloud Run service (worker) that consumes the same Redis events but does not serve HTTP traffic, strictly for background processing.

### 5.5. Content Delivery Network (CDN)
*   **Recommendation:** Enable Cloud CDN on the Load Balancer (if used) or configure the GCS bucket as a backend for a separate Load Balancer to serve static assets directly, reducing load on the GCS Fuse mount and Cloud Run container.

### 5.6. Admin User Bootstrap
The current initialization jobs create the DB and run migrations, but there is no automated step to create the initial **Admin User**.
*   **Recommendation:** Add a `medusa-seed` job or an entrypoint check that uses `medusa user -e <email> -p <password>` if no users exist, potentially reading credentials from Secret Manager.

## 6. Summary

The `modules/Medusa` implementation provides a solid, containerized foundation for Headless Commerce on GCP. It leverages the robust `CloudRunApp` shared infrastructure for security and storage. However, the current Docker configuration (startup command) requires immediate attention to be production-ready, and the architecture would significantly benefit from enabling Redis for caching/events and adding a search provider.
