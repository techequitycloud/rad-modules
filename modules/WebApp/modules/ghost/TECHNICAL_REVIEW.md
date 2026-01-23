# Ghost Module Technical Review

## Executive Summary

The Ghost module implementation is **architecturally sound and secure**, featuring a clever solution for dynamic URL handling on Cloud Run. However, it currently **lacks critical configuration for email delivery** (SMTP), which will render features like user signup and password resets non-functional in a production environment. Additionally, the reliance on GCS FUSE for serving content without an intermediate caching layer (CDN) will likely result in **suboptimal performance** for media-heavy blogs.

## Deep Dive Technical Review

### 1. Feature Completeness
*   **Dynamic URL Handling (Strengths):** The most significant challenge with Ghost on Cloud Run is that it requires a fixed `url` configuration that matches the request URL, which is dynamic in Cloud Run (especially for previews). The module solves this elegantly using a custom `entrypoint.sh` that queries the Cloud Run API via the metadata server to fetch the assigned URL at runtime.
*   **Database (Strengths):** The preset correctly defaults to **MySQL 8.0** on Cloud SQL, which is the recommended database for Ghost (dropping support for MySQL 5.7).
*   **Email (Critical Weakness):** The module sets `mail__from = "noreply@localhost"`, but **does not provide any mechanism to configure SMTP settings** (e.g., Mailgun, SendGrid) via preset variables. Since Cloud Run blocks outbound port 25, Ghost's default direct mail delivery will fail. **Password resets and member subscriptions will not work out-of-the-box.**
*   **Storage (Mixed):** It mounts a GCS bucket to `/var/lib/ghost/content` using GCS FUSE. While this provides infinite storage, it does not replace a CDN.

### 2. Security
*   **IAM Permissions (Excellent):** The module grants `roles/run.viewer` specifically to the Cloud Run service account. This is the "least privilege" required for the `entrypoint.sh` to fetch the service URL.
*   **Non-Root Execution (Excellent):** The container runs as the `node` user (UID 1000). The GCS volume configuration correctly uses `uid=1000,gid=1000` mount options, ensuring the application can write to storage without requiring root privileges.
*   **Secret Management (Excellent):** Database passwords are injected via Google Secret Manager, not plain text environment variables.

### 3. Performance
*   **Resources (Concern):** The default allocation of **1 vCPU and 1 GiB Memory** is the absolute minimum. Ghost can be memory-hungry during image processing (Sharp). 1GB leaves very little headroom for the OS and Node.js heap, potentially leading to OOM kills under load.
*   **Content Delivery (Concern):** Serving themes and uploaded images directly from GCS FUSE (`/var/lib/ghost/content`) is significantly slower than local disk or a CDN. Without a configured CDN (Cloud CDN or Cloudflare) in front of Cloud Run, users will experience high latency for static assets.
*   **Cold Starts (Good):** `min_instance_count = 1` is set by default, which avoids the slow startup time of Ghost (often 10s+), providing a snappy initial response.

### 4. Resiliency
*   **Probes (Good):** The module correctly differentiates between startup and liveness.
    *   **Startup:** Uses **TCP** (Ghost opens the port early).
    *   **Liveness:** Uses **HTTP `/`**.
    *   *Note:* The startup probe delay is 90s, giving ample time for database migrations on first boot.
*   **Database:** The `db-init` job ensures the database and user exist before the main application starts, preventing "database not found" crash loops.

### 5. Maintainability
*   **Modular Design:** The separation of the Ghost preset into `modules/WebApp/modules/ghost` is excellent. It isolates application-specific logic (image, port, probes) from the core infrastructure code.
*   **Custom Build:** The decision to use a custom Docker build (`modules/WebApp/scripts/ghost`) rather than a complex `post_start` script or sidecar for URL detection is the most robust and maintainable approach.

## Prioritised Plan of Action

To address the identified shortcomings, the following plan is recommended:

### Priority 1: Critical Fixes (Functionality)
1.  **Document/Expose SMTP Configuration:**
    *   Update documentation or the module preset to explicitly support standard Ghost email environment variables:
        *   `mail__transport` (e.g., "SMTP")
        *   `mail__options__host` (e.g., "smtp.mailgun.org")
        *   `mail__options__port` (e.g., 587)
        *   `mail__options__auth__user`
        *   `mail__options__auth__pass`
    *   *Why:* Without this, the application is functionally broken for user management.

### Priority 2: Performance & Stability
2.  **Increase Default Memory:**
    *   Bump `memory_limit` from `1Gi` to **`2Gi`**.
    *   *Why:* Prevents random OOM crashes during image uploads/processing.
3.  **Implement/Document CDN Strategy:**
    *   Update the architecture or documentation to recommend placing an external CDN (or enabling Cloud CDN if using an LB) in front of the Ghost service to cache paths under `/content/`.

### Priority 3: Enhancements
4.  **Custom Domain Handling:**
    *   The current dynamic URL fetch logic works great for `*.run.app` URLs. For custom domains, ensure documentation explains that the `url` environment variable **must be manually overridden** to match the custom domain, as the API will still return the `*.run.app` address.
