# Odoo Module Technical Features

## Architecture
Odoo requires a specific setup to run effectively in a containerized environment. This module deploys Odoo on **Cloud Run** and solves the "multi-process" and "filestore" challenges using a combination of **Cloud SQL** and **NFS**.

## Cloud Capabilities

### Persistence Layer
- **Filestore**: Mounts an NFS volume (from `GCP_Services`) to `/var/lib/odoo`. This is crucial because Odoo stores session files and binary attachments (PDFs, images) on the filesystem, not just the database.
- **Database**: Connects to PostgreSQL. The module handles the initial `odoo -i base` command via a Cloud Run Job to initialize the database schema on first deploy.

### Configuration Management
- **Odoo Config**: Generates the `odoo.conf` file dynamically based on Terraform variables (e.g., `db_host`, `admin_passwd`) and mounts it as a Secret or ConfigMap.
- **Master Password**: Securely manages the `admin_passwd` (Master Password) via **Secret Manager**, preventing it from being exposed in plain text.

### Backup Strategy
- **Automated Backups**: Integrates `configure_backups` logic which sets up a **Cloud Scheduler** job. This job triggers a backup script (running in a temporary container) to dump the database and filestore, compress them, and upload them to a secure **Cloud Storage** bucket.

## Configuration & Enhancement
- **Module Installation**: The `init_db_job` can be customized to pre-install specific Odoo modules (e.g., `-i sale,stock,account`) during the deployment phase.
- **Custom Addons**: Technical users can extend the Docker image or mount an additional NFS volume to `/mnt/extra-addons` to load custom Odoo modules without rebuilding the container.
