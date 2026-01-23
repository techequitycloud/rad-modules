# OpenEMR Application Module Technical Review

## Executive Summary
The OpenEMR deployment configuration within the `modules/WebApp` Terraform module provides a functional foundation for deploying OpenEMR 7.0.3 on Google Cloud Run. It correctly handles essential requirements such as database initialization, secret management, and persistent storage via NFS. However, it currently lacks features required for high availability, scalability, and robust disaster recovery. The reliance on an unmanaged external NFS server represents a significant operational risk.

## Deep Dive Technical Review

### 1. Feature Completeness
*   **Database Integration:** The module correctly provisions a MySQL 8.0 database and includes a `db-init` job to create the database and user. It handles the initial connection logic well using `nc` to wait for the database.
*   **Storage:** The use of NFS for `/var/www/localhost/htdocs/openemr/sites` is the correct approach for OpenEMR's architecture to persist configuration and documents.
*   **Backup/Restore:** The module supports *importing* backups from Google Drive or GCS during initialization. However, it lacks a native mechanism to *export* backups (both database dumps and NFS file synchronization) on a schedule.
*   **Session Management:** There is no explicit configuration for external session handling (e.g., Redis). OpenEMR defaults to file-based sessions. Without sticky sessions (which Cloud Run supports but aren't guaranteed during scaling events) or external storage, users may be logged out if the container restarts or if the service scales (though `max_instance_count` is currently pinned to 1).

### 2. Security
*   **Least Privilege:** The container runs as a non-root user (UID 1000), and the `nfs-setup` script correctly adjusts permissions (`chown 1000:1000`) and restricts `sqlconf.php` access (`chmod 600`).
*   **Secrets Management:** Sensitive data (DB passwords, Admin passwords) are correctly handled via Google Secret Manager and injected as environment variables.
*   **Network Security:** The configuration disables the Cloud SQL Proxy sidecar (`enable_cloudsql_volume = false`) and relies on Private IP connectivity (`DB_HOST = local.db_internal_ip`). This requires a properly configured VPC connector or Direct VPC Egress, which is supported by the module.
*   **Probes:** The startup probe uses TCP, which confirms the port is open but not that the application is ready. The liveness probe correctly uses HTTP, but communicates over HTTP. Since Cloud Run terminates TLS, this is acceptable for internal container traffic.

### 3. Performance
*   **Storage Latency:** OpenEMR is a PHP application with many small files. While code is in the container, the `sites` directory contains configuration and generated documents. NFS latency can impact performance for document retrieval.
*   **Resources:** The default allocation of 2 vCPU and 4GB RAM is a reasonable baseline for OpenEMR.
*   **Caching:** There is no evidence of specific PHP OpCache or APCu tuning in the environment variables. The default `openemr/openemr` image settings apply.

### 4. Resiliency
*   **Single Point of Failure (SPOF):**
    *   **Application:** `max_instance_count = 1` creates a SPOF. Updates or crashes will result in downtime.
    *   **Storage:** The module checks for an existing NFS server but does not provision one. If the external NFS server fails, the application will fail.
*   **Scalability:** Horizontal scaling is currently prevented by the instance count limit and the lack of shared session storage.
*   **Disaster Recovery:** While backup *import* is supported, the lack of automated backup *export* puts data at risk.

### 5. Cost
*   **Efficiency:** Cloud Run allows scaling to zero (if `min_instance_count` is 0), which is cost-effective. However, the OpenEMR module sets `min_instance_count = 1`, ensuring baseline costs.
*   **Dependencies:** The cost of the required NFS infrastructure (e.g., Filestore or GCE VM) is likely the dominant cost factor, potentially exceeding the compute costs.

### 6. Maintainability
*   **Versioning:** The container image `openemr/openemr:7.0.3` is hardcoded. Upgrades require code changes.
*   **Code Structure:** The `db-init` script is embedded inline in `variables.tf`. This makes it difficult to lint, test, or modify without touching the Terraform definition.
*   **Configuration:** PHP settings (`php.ini`) are not exposed for easy customization via Terraform variables.

---

## Prioritised Plan of Action

### Phase 1: Critical Reliability & Safety (Immediate)
1.  **Implement Automated Backup Exports:**
    *   Create a Cloud Run Job (cron) that dumps the MySQL database and synchronizes the NFS `sites` directory to a GCS bucket.
2.  **Externalize Session Storage:**
    *   Configure OpenEMR to use a database or Redis for session storage. This is a prerequisite for scaling beyond one instance and ensuring user session persistence across deployments.
    *   *Action:* Update `sqlconf.php` or `php.ini` injection to set `session.save_handler`.

### Phase 2: Scalability & High Availability (Short Term)
3.  **Enable Horizontal Scaling:**
    *   Once sessions are externalized, increase `max_instance_count` to allow Cloud Run to scale based on load.
4.  **Enforce Storage Availability:**
    *   Add a strict validation step (Terraform `precondition` or fail-fast script) that prevents deployment if the NFS server is reachable but not writable, or if the mount fails.

### Phase 3: Maintainability & Optimization (Medium Term)
5.  **Refactor Inline Scripts:**
    *   Move the `db-init` inline script from `variables.tf` to a dedicated file in `scripts/`.
6.  **Expose PHP Configuration:**
    *   Add a Terraform variable to pass custom PHP configuration (e.g., `upload_max_filesize`, `memory_limit`) via environment variables that the OpenEMR image understands (e.g., `PHP_INI_...`).
7.  **Cloud SQL Proxy Fallback:**
    *   Re-evaluate `enable_cloudsql_volume = false`. Enabling the proxy provides a more robust connection method that is less dependent on specific VPC routing configurations.
