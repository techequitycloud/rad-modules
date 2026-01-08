# Django Module Technical Features

## Architecture
This module implements a standard 12-Factor App architecture for Django on **Cloud Run**. It handles the "deployment glue" required to make a stateless Django container work with stateful Google Cloud services like **Cloud SQL** and **Secret Manager**.

## Cloud Capabilities

### Compute & Runtime
- **Resource**: `google_cloud_run_v2_service`
- **Capabilities**:
  - Deploys the Django container.
  - **Database Migration**: Includes logic (often via Cloud Run Jobs or Init Containers) to run `python manage.py migrate` during deployment to keep the schema in sync.
  - **Static Files**: configured to serve static assets efficiently or integrate with WhiteNoise.

### Database Integration
- **Connection**: Uses the Cloud SQL Proxy (built-in to Cloud Run Gen2) for secure, encrypted connections to PostgreSQL.
- **Secrets**: Retrieves `DATABASE_URL` and `DJANGO_SECRET_KEY` from **Secret Manager**, ensuring no sensitive data is hardcoded in `settings.py`.

### Observability
- **Monitoring**: Deploys `google_monitoring_service` resources (if `configure_monitoring` is true) to set up Uptime Checks and Alert Policies for high latency or error rates.

## Configuration & Enhancement
- **Superuser Automation**: The module automates the creation of the initial Django superuser (`django_superuser_email`, `django_superuser_username`) using a post-deployment script or job, removing a manual setup step.
- **Dependency Management**: Designed to work with `GCP_Services` for its database and network dependency (`module_dependency`).
- **Secret Rotation**: Updates to secrets in Secret Manager are automatically picked up on the next revision deployment.
