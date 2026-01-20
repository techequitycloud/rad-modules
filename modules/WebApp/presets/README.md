# WebApp Presets

This directory contains ready-to-use Terraform configurations for deploying popular web applications using the generic `WebApp` module. Each preset is configured with application-specific defaults for ports, probes, resource limits, and environment variables.

## Usage

1.  **Select a Preset**: Navigate to the directory of the application you wish to deploy (e.g., `cd modules/WebApp/presets/Wordpress`).
2.  **Configure Variables**: Create a `terraform.tfvars` file in the directory to define your environment-specific variables.
    *   See the `variables_<app>.tf` file in the preset directory for a list of all available variables and their descriptions.
    *   Common required variables include `existing_project_id`, `tenant_deployment_id`, and `deployment_region`.
3.  **Initialize**: Run `terraform init` to download providers and the WebApp module.
4.  **Deploy**: Run `terraform apply` to create the infrastructure.

### Example `terraform.tfvars`

```hcl
existing_project_id      = "my-gcp-project"
tenant_deployment_id     = "prod"
deployment_region        = "us-central1"
network_name             = "my-vpc"
cloudrun_service_account = "my-service-account@my-gcp-project.iam.gserviceaccount.com"
```

## Available Presets

### Cyclos
*   **Description**: Banking and payment software.
*   **Configuration**:
    *   Port: 8080
    *   Database: PostgreSQL
    *   Probes: TCP startup, HTTP liveness (`/api`)
    *   Resources: 2 CPU, 4Gi Memory

### Django
*   **Description**: High-level Python web framework.
*   **Configuration**:
    *   Port: 8080
    *   Database: PostgreSQL
    *   Volume: Cloud SQL mounted at `/cloudsql`
*   **Special Features**:
    *   Includes a post-deployment step to automatically update `CLOUDRUN_SERVICE_URLS` environment variable for CSRF protection.

### Moodle
*   **Description**: Learning Management System (LMS).
*   **Configuration**:
    *   Port: 80
    *   Database: PostgreSQL
    *   Volume: NFS mounted at `/mnt`
    *   Probes: TCP startup, HTTP liveness (`/`)

### N8N
*   **Description**: Workflow automation tool.
*   **Configuration**:
    *   Port: 5678
    *   Database: PostgreSQL
    *   Volume: Cloud SQL mounted at `/cloudsql`
*   **Special Features**:
    *   Automatically creates a dedicated Service Account, HMAC key, and Cloud Storage bucket for S3-compatible file storage.
    *   Injects S3 credentials and encryption keys as environment variables.

### Odoo
*   **Description**: Open Source ERP and CRM.
*   **Configuration**:
    *   Port: 8069
    *   Database: PostgreSQL
    *   Volumes:
        *   NFS mounted at `/mnt`
        *   GCS mounted at `/extra-addons`
*   **Special Features**:
    *   Configures GCS mount with specific options (uid/gid) for Odoo compatibility.

### OpenEMR
*   **Description**: Electronic Medical Record and Medical Practice Management.
*   **Configuration**:
    *   Port: 80
    *   Database: MySQL 8.0
    *   Volume: NFS mounted at `/var/www/localhost/htdocs/openemr/sites`
*   **Special Features**:
    *   Connects to the database root password secret (expected to be named `<instance>-root-password`) for initial setup.

### Wordpress
*   **Description**: Content Management System (CMS).
*   **Configuration**:
    *   Port: 80
    *   Database: MySQL 8.0
    *   Volumes:
        *   GCS mounted at `/var/www/html/wp-content`
        *   Cloud SQL mounted at `/cloudsql`
*   **Special Features**:
    *   Maps generic database variables to Wordpress-specific `WORDPRESS_DB_*` environment variables.
