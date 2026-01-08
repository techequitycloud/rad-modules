# OpenEMR Module Technical Features

## Architecture
This module deploys OpenEMR on **Cloud Run**, backed by **Cloud SQL (MySQL)**. It addresses the specific requirements of OpenEMR, such as its reliance on a filesystem for configuration (`sqlconf.php`) and document storage, using **NFS**.

## Cloud Capabilities

### Infrastructure Components
- **App Engine**: Cloud Run Service (Gen2).
- **Database**: Cloud SQL for MySQL. OpenEMR is heavily dependent on MySQL features.
- **Storage**: NFS volume mount for the `sites` directory. This is critical as OpenEMR writes configuration files and stores patient documents/images in the `sites/default/documents` folder.

### Initialization & Upgrades
- **Database Load**: Includes a specialized Cloud Run Job (`import_db_job`) that downloads the correct `database.sql` schema for the specific `application_version` and populates the database.
- **Configuration**: Dynamically generates `sqlconf.php` with database credentials and writes it to the NFS volume during the init phase.

### Security
- **PHP Hardening**: The container configuration typically includes PHP settings (like `memory_limit`, `max_execution_time`) tuned for EMR workloads.
- **Network Isolation**: Database connections are strictly internal. The NFS share is accessible only within the VPC.

## Configuration & Enhancement
- **Backup Restoration**: The module features a `restore_job` capability. By providing a `application_backup_fileid`, the system can download a backup archive (e.g., from Drive/GCS) and restore the entire practice state during deployment.
- **Scaling**: Configurable CPU/RAM limits allow the instance to be sized for small clinics or larger hospitals.
