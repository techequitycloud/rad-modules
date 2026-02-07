# Moodle on Google Cloud Platform

## 1. Executive Summary
The Moodle module is a containerized deployment leveraging **Google Cloud Run** for serverless compute, **Cloud SQL (PostgreSQL)** for the database, and **Google Cloud Storage (GCS) FUSE** for the shared data directory (`moodledata`). It is wrapped by the `CloudRunApp` foundation module, inheriting standardized networking, IAM, and secret management patterns.

## 2. Architecture & Services

### Compute: Cloud Run
- **Runtime:** `gen2` execution environment.
- **Scaling:** Configurable min/max instances (Default: 0-5).
- **Base Image:** Custom build based on `ubuntu:24.04` with PHP 8.3 and Apache.
- **Entrypoint:** Uses `tini` as process 1, wrapping a custom `cloudrun-entrypoint.sh` and Apache foreground script.

### Database: Cloud SQL
- **Engine:** PostgreSQL 15.
- **Connection:** Uses Unix Socket connection via Cloud Run Cloud SQL integration (`/var/run/postgresql`).
- **Extensions:** Automatically enables `pg_trgm` (trigram) for improved Moodle search performance.

### Storage Strategy (Critical Architecture Note)
The module provisions *two* storage types, but the application is configured to primarily use one:
1.  **GCS FUSE (Primary):**
    -   **Mount Path:** `/gcs/moodle-data`
    -   **Configuration:** The `moodle-config.php` explicitly sets `$CFG->dataroot = '/gcs/moodle-data'`.
    -   **Mechanism:** Uses Cloud Run's native GCS volume mount feature.
    -   **Permissions:** Runtime Service Account has `storage.objectAdmin`.
2.  **Filestore NFS (Secondary/Legacy):**
    -   **Mount Path:** `/mnt`
    -   **Status:** While `moodle.tf` provisions and mounts NFS, the `cloudrun-entrypoint.sh` and `moodle-config.php` focus on the GCS path. The NFS mount may be available for specific plugins or legacy reasons but is not the active `dataroot` in the current default configuration.

### Networking
- **Ingress:** Supports `internal`, `internal-and-cloud-load-balancing`, or `all`.
- **Egress:** Configured to route private ranges through the VPC (Serverless VPC Access) to reach Cloud SQL and Filestore.

## 3. IAM & Access Control

### Service Accounts
1.  **Cloud Run Service Account (Runtime Identity):**
    -   **Role:** `roles/secretmanager.secretAccessor` - Access to DB password, SMTP password, Cron password.
    -   **Role:** `roles/storage.objectAdmin` - Full control over the Moodle Data GCS bucket.
    -   **Role:** `roles/storage.legacyBucketReader` - Metadata access (required for some storage libraries).
2.  **Cloud Build Service Account (CI/CD):**
    -   **Role:** `roles/run.developer` - Ability to deploy new revisions.
    -   **Role:** `roles/iam.serviceAccountUser` - Ability to impersonate the Runtime SA during deployment.

### Secrets Management
-   **Storage:** Google Secret Manager.
-   **Secrets Created:**
    -   `MOODLE_DB_PASSWORD`
    -   `MOODLE_CRON_PASSWORD` (Randomly generated 32-char string)
    -   `MOODLE_SMTP_PASSWORD`

## 4. Configuration Details

### Terraform Configuration (`moodle.tf`)
-   **Environment Variables:**
    -   `MOODLE_DB_TYPE`: Hardcoded to `pgsql`.
    -   `MOODLE_REVERSE_PROXY`: Set to `true` (Essential for correct URL generation behind Cloud Run/LB).
    -   `MOODLE_WWWROOT`: Predicable URL generation based on Project ID and Region.
-   **Initialization Jobs:**
    -   `db-init`: A Cloud Run Job using `postgres:15-alpine` to wait for the DB, create the `moodle` user/db, and install extensions.
    -   `moodle-install`: Runs `admin/cli/install_database.php` if Moodle is not detected.

### Docker & Runtime Configuration
-   **PHP Extensions:** `gd`, `pgsql`, `intl`, `soap`, `xmlrpc`, `zip`, `mbstring`, `redis`.
-   **Apache:** Configured with `foreground.sh` to run as the main process.
-   **Moodle Config (`moodle-config.php`):**
    -   **Dynamic DB Host:** Detects if `DB_HOST` starts with `/` to toggle Socket vs TCP mode.
    -   **Health Check Bypass:** Explicitly returns "ok" for `GoogleHC` User-Agent to prevent health check logic from triggering heavy Moodle bootstrapping.
    -   **Permissions:** Sets `directorypermissions` to `02777` (required for GCS FUSE compatibility).
    -   **Redis Support:** If `redis_enabled` is true, configures `$CFG->session_handler_class` to use Redis, offloading session I/O from GCS.

## 5. Existing Features
-   **Automated Cron:** A Cloud Scheduler job hits `/admin/cron.php?password=...` every minute.
-   **Auto-Installation:** The system attempts to self-install on first boot via the `moodle-install` job.
-   **PDF Annotation:** `ghostscript` is installed to support Moodle's PDF annotation features.
-   **Redis Session Handling:** Optional configuration to use an external Redis instance for PHP sessions, reducing latency and storage I/O.

## 6. Potential Enhancements

### Performance
-   **CDN:** Implementing Cloud CDN for static assets (`/theme/`, `/lib/javascript/`) would significantly reduce container load and latency.

### Security
-   **Cloud Armor:** Attach a security policy to the Load Balancer to protect against common web attacks (WAF).
-   **Identity-Aware Proxy (IAP):** Could be enabled for the admin path or non-public deployments.

### Reliability
-   **Read Replicas:** Configure Cloud SQL Read Replicas for reporting-heavy Moodle instances.
-   **Backup Strategy:** While Cloud SQL has backups, ensuring the GCS bucket (`moodle-data`) has Object Versioning or separate backup routines is critical.
