# N8N AI Starter Kit on Google Cloud Platform

This document provides a comprehensive analysis of the `modules/N8N_AI` implementation, detailing its architecture, IAM configuration, services, and AI components.

## 1. Overview

The `modules/N8N_AI` module is a **Wrapper Module** that extends `modules/CloudRunApp` to deploy the [n8n](https://n8n.io/) workflow automation platform alongside AI infrastructure: **Qdrant** (vector database) and **Ollama** (local LLM). Together these form an AI Starter Kit for building RAG pipelines, chatbots, and AI-powered workflows.

## 2. IAM and Access Control

The module relies on a **Service Account (SA)** model to securely access GCP resources. The primary identity is the **Cloud Run Service Account** (`cloudrun-sa`), which is typically provisioned by the dependency module `modules/GCP_Services`.

### Service Accounts
*   **`cloudrun-sa`**: The identity under which n8n, Qdrant, and Ollama run.
*   **`cloudbuild-sa`**: Used for CI/CD and image building operations (if enabled).

### IAM Roles & Permissions
The `cloudrun-sa` is granted the following permissions (via `modules/GCP_Services` and `iam.tf`):

*   **Cloud SQL Client** (`roles/cloudsql.client`): Allows the n8n container to connect to the Cloud SQL PostgreSQL instance via the Unix socket.
*   **Storage Object Admin** (`roles/storage.objectAdmin`): Granted explicitly on the `n8n-data` bucket to allow n8n, Qdrant, and Ollama to read/write data via GCS FUSE.
*   **Secret Manager Accessor** (`roles/secretmanager.secretAccessor`): Allows access to specific secrets:
    *   Database Password (`DB_POSTGRESDB_PASSWORD`)
    *   SMTP Password (`N8N_SMTP_PASS`)
    *   Encryption Key (`N8N_ENCRYPTION_KEY`)
*   **Service Account User** (`roles/iam.serviceAccountUser`): Often required for the build service account to deploy the run service.

### Access Control (Ingress/Egress)
*   **n8n Ingress**: Configurable via `ingress_settings` (default: `all` / public).
*   **Qdrant & Ollama Ingress**: Set to `INGRESS_TRAFFIC_INTERNAL_ONLY` - only accessible from within the VPC.
*   **Egress**: Configurable via `vpc_egress_setting`. Default is typically `PRIVATE_RANGES_ONLY`.

## 3. Services Implemented

### 1. Cloud Run - n8n (Application)
*   **Image**: Custom build from `n8nio/n8n` via `scripts/n8n/Dockerfile`.
*   **Resources**: Configurable CPU/Memory (default: 2 vCPU, 4Gi Memory).
*   **Scaling**: Min instances: 0, Max instances: 3.
*   **Session Affinity**: Enabled.
*   **Probes**:
    *   **Startup Probe**: HTTP GET `/` (120s delay).
    *   **Liveness Probe**: HTTP GET `/` (30s delay).

### 2. Cloud Run - Qdrant (Vector Database)
*   **Image**: `qdrant/qdrant` (version configurable via `qdrant_version`).
*   **Resources**: 1 vCPU, 1Gi Memory, CPU idle enabled.
*   **Port**: 6333
*   **Scaling**: Fixed at 1 instance (min=1, max=1).
*   **Storage**: GCS FUSE mounted at `/mnt/gcs`, data stored in `/mnt/gcs/qdrant`.
*   **Probe**: Startup probe on `/readyz` endpoint.
*   **Ingress**: Internal only.

### 3. Cloud Run - Ollama (LLM Inference)
*   **Image**: `ollama/ollama` (version configurable via `ollama_version`).
*   **Resources**: 2 vCPU, 4Gi Memory, CPU idle disabled (needed for inference).
*   **Port**: 11434
*   **Scaling**: Fixed at 1 instance (min=1, max=1).
*   **Storage**: GCS FUSE mounted at `/mnt/gcs`, models stored in `/mnt/gcs/ollama/models`.
*   **Probe**: Startup probe on `/` endpoint.
*   **Ingress**: Internal only.

### 4. Cloud SQL (Database)
*   **Engine**: PostgreSQL 15.
*   **Connection**: Connected via Unix Socket (`/cloudsql/...`).
*   **Initialization**: A dedicated **Initialization Job** (`db-init`) creates the `n8n_user` and `n8n_db`.

### 5. Cloud Storage (Persistence)
*   **Bucket**: Creates a bucket suffixed with `-n8n-data`.
*   **Shared across services**: n8n mounts to `/home/node/.n8n`, Qdrant to `/mnt/gcs/qdrant`, Ollama to `/mnt/gcs/ollama/models`.

### 6. Secret Manager (Configuration)
*   **`encryption-key`**: Auto-generated 32-char key for n8n credential encryption.
*   **`smtp-password`**: Auto-generated dummy password.
*   **`db-password`**: Database user password.

## 4. Configuration Details

### Environment Variables
Key variables configured in `n8n_ai.tf`:
*   `N8N_PORT`: `5678`
*   `DB_TYPE`: `postgresdb`
*   `N8N_ENCRYPTION_KEY`: Loaded from Secret Manager.
*   `QDRANT_URL`: Auto-populated with internal Qdrant service URI (when enabled).
*   `OLLAMA_HOST`: Auto-populated with internal Ollama service URI (when enabled).
*   `WEBHOOK_URL` / `N8N_EDITOR_BASE_URL`: Auto-populated with the predicted Cloud Run service URL.

### AI Component Controls
*   `enable_ai_components`: Master toggle for all AI services (default: `true`).
*   `enable_qdrant`: Toggle Qdrant independently (default: `true`).
*   `enable_ollama`: Toggle Ollama independently (default: `true`).
*   `ollama_model`: Default model to use (default: `llama3.2`).

## 5. Differences from modules/N8N

| Aspect | N8N | N8N_AI |
|--------|-----|--------|
| Display name | N8N | N8N AI Starter Kit |
| AI services | None | Qdrant + Ollama |
| Additional env vars | None | `QDRANT_URL`, `OLLAMA_HOST` |
| Extra variables | None | 6 AI-specific variables |
| `ai_services.tf` | Not present | Defines Qdrant & Ollama Cloud Run services |

## 6. Potential Enhancements

### A. GPU Support for Ollama
*   **Current State**: Ollama runs on CPU only (2 vCPU, 4Gi).
*   **Enhancement**: When Cloud Run GPU support is available, add GPU resources for faster LLM inference.

### B. Model Pre-loading
*   **Current State**: Ollama starts without a pre-loaded model.
*   **Enhancement**: Add an initialization job that pulls the configured `ollama_model` on first deploy.

### C. Qdrant Authentication
*   **Current State**: Qdrant has no API key authentication configured.
*   **Enhancement**: Add an API key via Secret Manager and configure `QDRANT__SERVICE__API_KEY`.

### D. Scaling
*   **Current State**: Qdrant and Ollama are fixed at 1 instance.
*   **Enhancement**: Make scaling configurable via variables for workloads that need higher throughput.
