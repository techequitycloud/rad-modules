# N8N Module Technical Features

## Architecture
This module deploys the standard `n8n` container image on **Cloud Run**. It uses **Cloud SQL (PostgreSQL)** as the backend `DB_TYPE` to store workflows, credentials, and execution data, ensuring state is preserved across container restarts.

## Cloud Capabilities

### Compute
- **Resource**: `google_cloud_run_v2_service`
- **Details**: Configured with `cpu_idle = false` (often required for n8n to ensure background triggers/pollers run reliably if not using the separate worker mode).

### Persistence
- **Database**: Connects to the PostgreSQL instance via Cloud SQL Proxy.
- **Encryption**: Uses **Secret Manager** to generate and inject the `N8N_ENCRYPTION_KEY`. This key is critical; if lost, credentials stored in n8n cannot be decrypted. The module ensures this key is generated once and persisted.

### Networking
- **Webhooks**: Exposes the Cloud Run URL. Technical users can configure custom domains via Cloud Run domain mapping for professional webhook URLs.

## Configuration & Enhancement
- **Environment Variables**: The module supports passing standard n8n environment variables (e.g., `N8N_Basic_Auth_Active`, `WEBHOOK_URL`) to customize authentication and behavior.
- **Scaling**: For heavy workloads, this architecture can be enhanced by separating n8n into "Main", "Worker", and "Webhook" services (though this module deploys the monolith mode by default for simplicity).
