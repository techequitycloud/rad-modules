# Technical Review: modules/WebApp

**Date:** October 26, 2023
**Scope:** Core Terraform code in `modules/WebApp`
**Reviewer:** Automated Technical Review Agent

## Executive Summary

The `modules/WebApp` directory implements a sophisticated, "monolithic orchestrator" pattern for deploying various web applications (presets) to Google Cloud Run. It abstracts complexity by providing a unified interface (`main.tf`, `variables.tf`) while delegating specific configurations to sub-modules (`modules/`).

**Key Strengths:**
*   **Modularity:** The preset architecture is scalable and allows adding new apps without breaking the core contract.
*   **Security:** Strong usage of Secret Manager, IAM roles are generally least-privilege scoped, and service accounts are used effectively.
*   **Flexibility:** Supports both prebuilt and custom builds, simple and complex apps (multi-container via sidecars/volumes logic), and varied storage options (NFS, GCS).

**Key Weaknesses:**
*   **Fragile External Dependencies:** Heavy reliance on `external` data sources (`bash` scripts) to query infrastructure state (SQL, NFS, Network) makes the module brittle and dependent on specific environment conditions/script outputs.
*   **Security Gaps:** NFS setup uses permissive permissions (`chmod 777`) which is a security risk.
*   **Resiliency Gaps:** Lack of automated backup *creation* (only import is supported) and potential single points of failure (NFS, non-HA external components).
*   **Performance:** Missing caching layer (Redis) and CDN/WAF integration.

---

## 1. Feature Completeness

### Strengths
*   **Unified Interface:** A single module handles many app types, simplifying consumption.
*   **Storage Options:** Good support for Cloud SQL, GCS FUSE, and NFS.
*   **Lifecycle Management:** Includes initialization jobs for DB migrations, backups import, and cleanup jobs on destroy.
*   **CI/CD:** Integrated Cloud Build support for custom images.

### Gaps
*   **Caching:** No native support for Redis/MemoryStore. Many supported apps (Moodle, Magento, Odoo) require Redis for production performance and session handling.
*   **WAF/CDN:** No integration with Cloud Armor or Cloud CDN. Cloud Run services are exposed directly via their default URLs or custom mapping, but without edge protection.
*   **Database Management:** The module assumes the database instance *exists* and queries it. It does not provision Cloud SQL, meaning users must manage the DB lifecycle separately. This is a "by design" choice but limits self-containment.
*   **Observability:** Basic logging/monitoring is present, but no custom dashboard creation or deep Application Performance Monitoring (APM) integration.

## 2. Security

### Strengths
*   **Secrets Management:** Environment variables containing sensitive data are correctly sourced from Secret Manager.
*   **Identity:** Service Accounts are used for Cloud Run and Cloud Build. `impersonation_service_account` support enables secure Terraform execution.
*   **IAM:** Role bindings are generally specific (`roles/run.invoker`, `roles/secretmanager.secretAccessor`).

### Risks & Vulnerabilities
*   **NFS Permissions:** The `nfs_setup_job` executes `chmod 777` on the target directory. This makes files world-writable/readable on the NFS share, which allows any compromised container on the same NFS share to read/modify others' data if path isolation isn't perfect.
*   **Script Injection:** The `external` data sources execute shell scripts. While some input sanitization exists, relying on `bash` with user-supplied variables (`project_id`, etc.) always carries a risk if inputs aren't strictly validated.
*   **Public Access:** By default, if `ingress_settings` allows, the service is publicly accessible. While `trusted_users` variable exists, the Cloud Run service often defaults to `allUsers` invoker permissions if not restricted.
*   **Image Trust:** Helper jobs use generic images like `alpine:3.19` or `debian:12-slim`. These should ideally be pinned to specific SHA digests to prevent supply chain attacks.

## 3. Performance

### Strengths
*   **Scaling:** `min_instance_count` and `max_instance_count` are exposed.
*   **Startup Boost:** CPU startup boost is enabled, improving cold start times.
*   **Probes:** Startup and Liveness probes are configurable.

### Concerns
*   **NFS Bottleneck:** Using NFS with Cloud Run can be slow due to network latency and throughput limits. For high-traffic apps, this is a bottleneck.
*   **GCS FUSE:** While convenient, GCS FUSE has higher latency than block storage. Heavy I/O apps will suffer.
*   **No Caching:** As mentioned, lack of Redis means apps hit the DB for sessions/cache, reducing throughput.

## 4. Resiliency

### Strengths
*   **Multi-Region Config:** Variables exist for multi-region, though implementation in Cloud Run is inherently regional.
*   **Health Checks:** Probes ensure unhealthy instances are restarted.

### Weaknesses
*   **Backup Strategy:** The module supports *importing* backups but does not appear to configure scheduled *export* jobs. Disaster Recovery (DR) relies on manual or external backup processes.
*   **Single Points of Failure:** If the external NFS server goes down, all attached apps fail. The module doesn't provision HA NFS (e.g., Filestore Enterprise).
*   **Database Failover:** Relying on external Cloud SQL means the module doesn't control failover logic explicitly.

## 5. Cost

### Strengths
*   **Scale to Zero:** `min_instance_count` defaults to 0 (or can be set to 0), allowing huge cost savings for idle apps.
*   **Resource Tuning:** CPU/Memory limits are configurable.

### Concerns
*   **Idle Infrastructure:** If NFS is provisioned externally (e.g., a GCE VM), it costs money even if Cloud Run scales to zero.
*   **Build Costs:** Frequent CI/CD triggers can incur Cloud Build costs.

## 6. Maintainability

### Strengths
*   **Modular Presets:** Adding a new app is relatively clean (add folder in `modules/`, add entry in `modules.tf`).

### Concerns
*   **Monolithic `main.tf`:** The `main.tf` file is becoming very large. The `preset_env_vars` local block is a massive merge map. As apps grow, this file will become unmanageable.
*   **Fragile "External" Data:** `check_network.sh`, `get-sqlserver-info.sh`, etc., are "black boxes" to Terraform. If they fail or return slightly different JSON, the plan fails. Debugging these scripts inside a Terraform apply is difficult.
*   **Implicit Dependencies:** The code relies on specific folder structures (`scripts/`) and file presence.

---

## 7. Prioritized Plan of Action

### Phase 1: Critical Security & Stability (Immediate)
1.  **Harden NFS Permissions:**
    *   Stop using `chmod 777`.
    *   Implement correct UID/GID mapping (e.g., ensure containers run as `uid=33` (www-data) or `uid=1000` and the NFS share is owned by that UID).
    *   Use `setgid` bit on directories if group sharing is needed.
2.  **Pin Helper Images:**
    *   Update `jobs.tf` to use SHA-pinned images for `alpine` and `debian` (e.g., `alpine@sha256:...`) to ensure reproducibility and security.
3.  **Validate External Script Inputs:**
    *   Ensure all inputs passed to `external` data providers are strictly regex-validated in `variables.tf` to prevent injection.

### Phase 2: Operational Excellence (Short Term)
1.  **Automated Backups:**
    *   Add a `google_cloud_scheduler_job` resource that triggers a Cloud Run Job to perform database dumps to GCS.
2.  **Robustness Improvements:**
    *   Add better error handling in the `scripts/*.sh` files.
    *   Consider replacing `external` data sources with `terraform_remote_state` or direct `data` resources if the infrastructure is managed by Terraform elsewhere.

### Phase 3: Performance & Features (Medium Term)
1.  **Redis Support:**
    *   Add a `redis.tf` or external data lookup for MemoryStore.
    *   Update application presets (Moodle, Odoo) to configure Redis env vars if available.
2.  **Cloud Armor / WAF:**
    *   Since Cloud Run is used, consider adding a module for a Global Load Balancer (HTTPS) with Cloud Armor attached, placing Cloud Run behind it as a NEG (Network Endpoint Group).

### Phase 4: Refactoring (Long Term)
1.  **Decompose `main.tf`:**
    *   Move the massive `preset_env_vars` map into a separate file (e.g., `locals_presets.tf`) or have each module output its env vars fully formed, reducing the merge logic in the root module.
2.  **Go-based Providers:**
    *   Consider writing a small custom Terraform provider or using a robust wrapper instead of fragile bash scripts for querying external infrastructure state.
