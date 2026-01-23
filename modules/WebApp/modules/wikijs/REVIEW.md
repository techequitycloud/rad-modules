# Wiki.js Module Deep Dive Review

## Executive Summary
The Wiki.js deployment module provides a functional baseline using the official `requarks/wiki:2` image and PostgreSQL 15. It correctly handles basic security (non-root user, secrets) and resilience (probes, init jobs). However, there are significant opportunities to improve security (permissions), data persistence configuration (storage path), and connectivity optimization (Cloud SQL sockets).

## Detailed Technical Review

### 1. Feature Completeness
*   **Database:** Correctly provisions PostgreSQL 15, which is compatible and performant. The initialization job automates DB and User creation effectively.
*   **Search:** Explicitly enables the `pg_trgm` extension, ensuring native search functionality works out-of-the-box.
*   **Storage:** A GCS bucket (`wikijs-storage`) is created and mounted at `/wiki-storage`. **CRITICAL:** The application is not explicitly configured to use this path by default. Without manual configuration or additional environment variables (e.g., configuring the Local File System module in Wiki.js), user uploads may end up in ephemeral container storage and be lost on restart.
*   **Configuration:** Relies on environment variables. `DB_SSL=false` is set, which is appropriate for internal VPC connections but should be monitored if network topology changes.

### 2. Security
*   **User Privileges:** The container runs as a non-root user (UID 1000), and volume mounts correctly respect this (`uid=1000,gid=1000`). This is a strong security practice.
*   **File Permissions:** The GCS volume is mounted with `file-mode=777` and `dir-mode=777`. This is **excessively permissive**. It allows any user in the container to modify files. It should be restricted to `700` or `770` owned by UID 1000.
*   **Network:** Uses Cloud Run VPC Access. `DB_HOST` is set to the internal IP, keeping traffic private.
*   **Secrets:** `DB_PASS` is correctly injected via Secret Manager, preventing credentials from leaking in plaintext config.

### 3. Performance
*   **Connectivity:** The module mounts the Cloud SQL Unix socket volume (`/var/run/postgresql`) but configures the application to use `DB_HOST=<INTERNAL_IP>`. This creates a mismatch where the overhead of mounting the volume is incurred, but the application uses TCP/IP.
    *   **Recommendation:** Either switch `DB_HOST` to `/var/run/postgresql` to use the socket (lower latency, secure) or disable the `cloudsql` volume mount to save startup time.
*   **Resources:** Limits are set to 1 CPU / 1Gi RAM. This is a reasonable baseline but may need scaling for heavy search or concurrent edits.
*   **Caching:** No external cache (Redis) is configured. Wiki.js performance may degrade with high read volume without it.

### 4. Resiliency
*   **Probes:** HTTP Startup and Liveness probes are configured on `/healthz`. This is superior to TCP checks as it verifies application responsiveness.
*   **Scaling:** `min_instance_count=1` prevents cold starts, improving availability. `max_instance_count=3` allows burst handling.
*   **Session Affinity:** Enabled (`true`), which is beneficial if sticky sessions are required, though Wiki.js is largely stateless (JWT).

### 5. Maintainability
*   **Dependencies:** The init job uses `alpine:3.19`, which is stable.
*   **Structure:** The configuration is split between `wikijs/variables.tf` and the monolithic `main.tf`. The logic for `preset_env_vars` in `main.tf` is getting complex and centralized, making it harder to isolate changes to the Wiki.js module.

## Prioritized Plan of Action

### High Priority (Critical & Security)
1.  **Fix Storage Permissions:** Change `mount_options` in `wikijs/variables.tf` from `777` to `700` or `770`.
2.  **Verify & Fix Storage Config:** Determine if an environment variable (e.g., `CONFIG_FILE` injection or specific storage env vars) can force Wiki.js to use `/wiki-storage` for uploads immediately. Document manual setup if automation is impossible.
3.  **Resolve DB Connection Mismatch:** Update `DB_HOST` to `/var/run/postgresql` in `main.tf` (or module override) to utilize the mounted Cloud SQL socket, or disable the volume mount.

### Medium Priority (Optimization)
4.  **Resource Tuning:** Monitor memory usage during load tests. 1GB might be tight for Node.js + Wiki.js.
5.  **Refactor Env Vars:** Consider moving Wiki.js-specific env var logic (`preset_env_vars`) out of `main.tf` and fully into the module's `variables.tf` if the architecture permits (currently `main.tf` logic seems rigid).

### Low Priority (Enhancements)
6.  **Redis Support:** Add optional Redis configuration for caching.
7.  **Image Mirroring:** Evaluate if `enable_image_mirroring` should be enabled for supply chain security.
