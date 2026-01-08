# Moodle Module Technical Features

## Architecture
Moodle is a stateful application that is traditionally hard to containerize. This module solves that by using **Cloud Run (Gen2)** with **NFS volume mounts** for the `moodledata` directory. This hybrid approach offers serverless compute benefits while maintaining compatibility with Moodle's file-based storage architecture.

## Cloud Capabilities

### Storage Strategy
- **Moodledata**: Uses **NFS** (provided by `GCP_Services`) mounted to `/bitnami/moodle` or `/var/www/moodledata`. This is critical because Moodle requires a shared file system for sessions, cache, and user uploads across multiple container instances.
- **Database**: Connects to Cloud SQL (PostgreSQL/MySQL) for the metadata store.

### Background Processing
- **Cron Jobs**: Moodle relies heavily on a cron task running every minute. This module implements this via **Cloud Scheduler** triggering a dedicated **Cloud Run Job**, ensuring reliable background processing without keeping a container running 24/7.

### Application Lifecycle
- **Initialization**: Includes a bootstrapping process (often a Cloud Run Job) that runs the Moodle installation script (`admin/cli/install.php`) on the first deploy to populate the database and creating the `config.php`.

## Configuration & Enhancement
- **Backup & Restore**: The module includes specific variables (`application_backup_fileid`) and logic to download a Moodle backup from Google Drive and restore it during the init phase, enabling "Clone" or "Disaster Recovery" scenarios.
- **Performance Tuning**: Technical users can adjust PHP memory limits and execution times via environment variables (`configure_environment`) to handle large courses or heavy grading workloads.
