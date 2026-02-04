---
title: OpenEMR
sidebar_label: OpenEMR
slug: /applications/openemr
---

import AudioPlayer from '@site/src/components/AudioPlayer';

# OpenEMR on Google Cloud Platform

<img src="https://storage.googleapis.com/rad-public-2b65/modules/openemr_module.png" alt="OpenEMR on Google Cloud Platform" style={{marginBottom: '20px'}} />

<AudioPlayer url="https://storage.googleapis.com/rad-public-2b65/modules/openemr_module.m4a" title="OpenEMR on Google Cloud Platform Audio" />

<video width="100%" controls style={{marginTop: '20px'}}>
  <source src="https://storage.googleapis.com/rad-public-2b65/modules/openemr_module.mp4" type="video/mp4" />
  Your browser does not support the video tag.
</video>

## Overview
The **OpenEMR** module deploys a leading open-source electronic health records (EHR) and medical practice management solution. It is designed for healthcare providers who need a secure, HIPAA-compliant-ready environment to manage patient data, scheduling, and billing.

## Key Benefits
- **Patient Data Sovereignty**: Keep full control and ownership of your patient records by hosting them on your own cloud instance.
- **Secure & Compliant**: Built on Google Cloud's secure foundation, with encrypted databases and private networking to help meet compliance requirements.
- **High Availability**: Ensures patient records are always accessible when needed by clinicians.
- **Disaster Recovery**: Integrated backup solutions to protect against data loss.

## Functionality
- Deploys OpenEMR application.
- Configures a secure MySQL/MariaDB database.
- Sets up encrypted storage for patient documents and certificates.
- Automates certificate management (SSL) for secure web access.

---

This document provides an analysis of the `OpenEMR` module. It details the architecture, IAM configurations, service specifications, and available features, along with recommendations for enhancement.



The OpenEMR module deploys a scalable, containerized instance of OpenEMR on Google Cloud Run. It utilizes a wrapper architecture (`CloudRunApp`) to provision standard infrastructure components while defining OpenEMR-specific configurations. Key architectural decisions include using Cloud SQL for the database, an external NFS server (GCE instance) for shared file storage (sites directory), and Redis for session management (hosted on the same NFS infrastructure).

## 2. Architecture Overview

The deployment follows a standard 3-tier web application architecture adapted for serverless containers:

*   **Compute:** Google Cloud Run (Gen 2) hosting the OpenEMR PHP application (Apache/PHP-FPM).
*   **Database:** Google Cloud SQL (MySQL 8.0) connected via Private IP or Unix Socket.
*   **Storage:**
    *   **Application Code:** Immutable container image.
    *   **Patient Documents/Sites:** NFS Volume mounted to `/var/www/localhost/htdocs/openemr/sites`. This is provided by a GCE instance running an NFS server.
*   **Caching/Sessions:** Redis, accessed via the internal IP of the NFS infrastructure.
*   **Networking:** Private VPC connectivity via Direct VPC Egress. Public or Internal Ingress.

## 3. IAM & Access Control

The module implements the Principle of Least Privilege through dedicated Service Accounts (SA).

### Service Accounts
1.  **Cloud Run Service Account (`cloudrun-sa`)**:
    *   **Identity:** Used by the OpenEMR container at runtime.
    *   **Permissions:**
        *   `roles/secretmanager.secretAccessor`: To retrieve `OE_PASS` (Admin Password) and `DB_PASSWORD`.
        *   `roles/storage.objectAdmin`: Full control over creating/managing GCS buckets (if `create_cloud_storage` is true).
        *   `roles/storage.legacyBucketReader`: For listing bucket metadata.
2.  **Cloud Build Service Account (`cloudbuild-sa`)** (If CI/CD is enabled):
    *   **Identity:** Used by Cloud Build triggers.
    *   **Permissions:**
        *   `roles/run.developer`: To deploy revisions to Cloud Run.
        *   `roles/iam.serviceAccountUser`: To act as the Cloud Run SA during deployment.
        *   `roles/secretmanager.secretAccessor`: To access the GitHub token.

### Network Access
*   **Cloud Run Invoker:** By default, `roles/run.invoker` is granted to `allUsers`, making the service publicly accessible. This is controlled by the `public_access` variable but the implementation in `service.tf` currently defaults to `allUsers` if `configure_environment` is true.

## 4. Service Configuration

### Compute: Cloud Run
*   **Image Source:** Custom build based on `alpine:3.20` with PHP 8.3 and Apache.
*   **Resources:**
    *   CPU: `2000m` (2 vCPU) default.
    *   Memory: `4Gi` default.
*   **Scaling:**
    *   Min Instances: `1` (Ensures warm start, prevents cold boot latency).
    *   Max Instances: `1` (Restricted to 1 by default in `openemr.tf`, likely due to legacy concurrency concerns or session stickiness, though Redis is configured).
*   **Probes:**
    *   **Startup Probe:** TCP check on port 80. Initial delay 240s.
    *   **Liveness Probe:** HTTP GET on `/interface/login/login.php`. Initial delay 300s.

### Database: Cloud SQL
*   **Engine:** MySQL 8.0.
*   **Connection:**
    *   Primary: Unix Socket (mounted at `/cloudsql`).
    *   Secondary: Internal IP (`DB_HOST` env var).
    *   **Credentials:** Rotated automatically via Secret Manager (`google_secret_manager_secret`).

### Storage: NFS & Volumes
*   **Mount Point:** `/var/www/localhost/htdocs/openemr/sites`.
*   **Source:** External GCE Instance (identified via `get-nfsserver-info.sh` script).
*   **Permissions:** The startup script (`openemr.sh`) intentionally skips recursive `chown` on this directory to prevent Cloud Run startup timeouts, relying on the `nfs-init` job instead.

### Configuration Options (Variables)

| Variable | Default | Description |
| :--- | :--- | :--- |
| `nfs_enabled` | `true` | Critical for OpenEMR. Enables the NFS volume mount. |
| `database_type` | `MYSQL_8_0` | Required version for OpenEMR compatibility. |
| `environment_variables` | Map | Includes `PHP_MEMORY_LIMIT` (512M), `SMTP_*` settings. |
| `ingress_settings` | `all` | Controls visibility (`all`, `internal`, `internal-and-cloud-load-balancing`). |
| `vpc_egress_setting` | `PRIVATE_RANGES_ONLY` | Routes private traffic to VPC, public to internet. |
| `backup_source` | `gcs` | Source for automated backup restoration during init (`gcs` or `gdrive`). |

## 5. Application Implementation

### Docker Container (`scripts/openemr/Dockerfile`)
*   **Base:** `alpine:3.20`.
*   **Software:** Apache2, PHP 8.3 (with FPM), Node.js (for build assets).
*   **Build Process:** Clones OpenEMR `rel-704` from GitHub, runs `composer` and `npm` builds, and compiles assets.
*   **Security:** Runs Apache/PHP as user `apache` (UID 1000).
*   **Logging:** Redirects Apache/PHP logs to `/dev/stderr` and `/dev/stdout` for Cloud Logging compatibility.

### Startup Logic (`scripts/openemr/openemr.sh`)
*   **Auto-Configuration:** Runs `auto_configure.php` to set up `sqlconf.php` if missing.
*   **Resiliency:** Detects "Cloud Run mode" to skip slow filesystem permission checks (`find/chown`) on the NFS mount.
*   **Session Handling:** Configures `session.save_handler = redis` if `REDIS_SERVER` is present.
*   **Port Binding:** Dynamically updates Apache's `Listen` port based on the `$PORT` environment variable.

### Initialization Jobs (`nfs-init`)
*   **Purpose:** Prepares the shared storage before the app starts.
*   **Actions:**
    1.  Sets ownership of the `sites` directory to UID 1000.
    2.  Downloads a backup file (if `BACKUP_FILEID` is provided) from GCS or GDrive.
    3.  Unzips and restores the backup to the NFS volume.
    4.  Regenerates `sqlconf.php` with the current DB credentials.

## 6. Potential Enhancements

### Infrastructure & Architecture
1.  **Separate Redis Service:** Migrating to **Cloud Memorystore for Redis** would improve reliability, manageability, and scalability.
2.  **Managed NFS (Filestore):** Replacing the GCE-based NFS server with **Cloud Filestore** (Basic Tier) would remove the burden of managing the storage VM and improve availability.
3.  **WAF / Cloud Armor:** If `ingress_settings` is `all`, the service is exposed directly. Implementing a Global Load Balancer with **Cloud Armor** is recommended to protect against OWASP Top 10 attacks.

### Security
1.  **IAP Integration:** Restrict public access by enabling **Identity-Aware Proxy (IAP)** on the Load Balancer, ensuring only authorized users can reach the login screen.
2.  **Secret Rotation:** Implement a dedicated job or function to rotate the `OE_PASS` and `DB_PASSWORD` periodically and update the OpenEMR config, as currently they are static after creation.
3.  **Least Privilege Refinement:** Review `roles/storage.objectAdmin`. If the app only needs to write documents, `roles/storage.objectCreator` and `roles/storage.objectViewer` might be sufficient.

### Observability & Operations
1.  **Structured Logging:** Ensure `openemr.conf` LogFormat explicitly uses JSON or GCP-compatible text formats for easier parsing in Cloud Logging.
2.  **Automated Backups:** The current solution supports restore-on-init. A `CronJob` (Cloud Scheduler + Cloud Run Job) should be added to periodically dump the MySQL database and `sites` directory to GCS.
3.  **Health Check Tuning:** The `startup_probe` delay (240s) is quite long. Optimizing the PHP-FPM startup or `auto_configure` process could reduce deployment roll-out times.
