# WebApp Module Gap Analysis

This document analyzes whether the following modules can be deployed using the generic `modules/WebApp` module and identifies specific features or configurations that are currently unsupported or missing in `WebApp`.

## Summary

| Module | Deployment Status | Key Missing Features / Gaps in `WebApp` |
| :--- | :--- | :--- |
| **Cyclos** | ✅ **Supported** | Requires porting the custom backup restoration logic to an initialization job. |
| **Django** | ❌ **Not Fully Supported** | **1.** Missing post-deployment CSRF origin update logic. <br> **2.** Missing explicit Cloud SQL Unix socket mount support. |
| **Moodle** | ⚠️ **Partially Supported** | Built-in NFS setup (`chmod 777`) is too permissive/rigid. Specific user ownership (33:33) requires a custom replacement job. |
| **N8N** | ❌ **Not Fully Supported** | **1.** **Critical:** `WebApp` does not support overriding `command`/`args` for the main service container. <br> **2.** Missing explicit Cloud SQL Unix socket mount support. |
| **N8N_AI** | ❌ **Not Supported** | **Critical:** Requires deploying multiple distinct Cloud Run services (N8N, Qdrant, Ollama) and orchestrating them. `WebApp` only deploys a single service. |
| **Odoo** | ✅ **Supported** | Fully supported. GCS/NFS mount options are compatible. |
| **OpenEMR** | ✅ **Supported** | Requires porting the complex NFS initialization and config patching script to a custom initialization job. |
| **Wordpress** | ✅ **Supported** | Fully supported. |

---

## Detailed Analysis

### 1. Cyclos
*   **Status:** Supported.
*   **Analysis:**
    *   Cyclos uses a standard container setup with environment variables and secrets, which `WebApp` supports.
    *   **Gap:** The specific "Import DB" job in Cyclos includes logic to download a backup from Google Drive (`gdown`) and restore it.
    *   **Workaround:** This logic can be implemented in `WebApp` by defining a custom `initialization_job` with the same `alpine` image and script commands.

### 2. Django
*   **Status:** Not Fully Supported.
*   **Analysis:**
    *   **Gap 1 (Post-Deployment Logic):** The Django module includes a `null_resource` `update_csrf_origin` that runs *after* the Cloud Run service is created. It fetches the service URL and updates the service's `CLOUDRUN_SERVICE_URLS` environment variable. `WebApp` does not support this circular dependency resolution or post-deployment updates.
    *   **Gap 2 (Cloud SQL Socket):** Django often defaults to connecting via Unix socket (`/cloudsql/...`). `WebApp` defaults to TCP/IP (`DB_HOST` = IP). While Django *can* use TCP, `WebApp` does not expose the `cloud_sql_instance` volume mount in the main service definition, forcing TCP usage.

### 3. Moodle
*   **Status:** Partially Supported.
*   **Analysis:**
    *   **Gap (NFS Permissions):** Moodle requires specific directory ownership on the NFS share (User 33:33). `WebApp`'s built-in NFS setup job hardcodes `chmod 777` and does not allow configuring specific user/group ownership.
    *   **Workaround:** The built-in NFS setup in `WebApp` would need to be disabled, and a custom `initialization_job` would need to be configured to handle the specific permissions.

### 4. N8N
*   **Status:** Not Fully Supported.
*   **Analysis:**
    *   **Gap 1 (Command Override):** The N8N module overrides the container command: `command = ["/bin/sh"]`, `args = ["-c", "sleep 5; n8n start"]`. `WebApp` **does not** expose `command` or `args` variables for the main application container (only for initialization jobs). This is a blocker if the custom entrypoint is strictly required.
    *   **Gap 2 (Cloud SQL Socket):** N8N module configures `DB_POSTGRESDB_HOST` to point to the Unix socket `/cloudsql/...`. `WebApp` does not mount this volume by default.

### 5. N8N_AI
*   **Status:** Not Supported.
*   **Analysis:**
    *   **Gap (Multi-Service Architecture):** The `N8N_AI` module deploys **three** separate Cloud Run services: `n8n` (Application), `qdrant` (Vector DB), and `ollama` (LLM).
    *   `WebApp` is designed to deploy a **single** Cloud Run service per instantiation. Deploying `N8N_AI` would require instantiating `WebApp` three separate times and manually wiring them together (shared network, storage, env vars), effectively losing the cohesion of the original module.

### 6. Odoo
*   **Status:** Supported.
*   **Analysis:**
    *   Odoo requires specific mount options for GCS (UID/GID), which `WebApp` supports via the `gcs_volumes` `mount_options` parameter.
    *   Initialization jobs (DB init) are compatible with `WebApp`'s `initialization_jobs` feature.

### 7. OpenEMR
*   **Status:** Supported.
*   **Analysis:**
    *   **Gap (Complex NFS Init):** OpenEMR's `nfs_setup_job` performs complex tasks: creating directories, downloading backups to the NFS share, and *modifying* a PHP configuration file (`sqlconf.php`) in that share.
    *   **Workaround:** This is not supported by `WebApp`'s *built-in* NFS setup, but it is fully supported by defining a **custom** `initialization_job` that mounts the NFS share and runs the specific script.

### 8. Wordpress
*   **Status:** Supported.
*   **Analysis:**
    *   Wordpress uses standard GCS/Cloud SQL integration which matches `WebApp`'s core capabilities. No complex custom logic or unsupported features were identified.
