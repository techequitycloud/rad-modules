# Odoo on Google Cloud: Best Practices with Terraform

Deploying stateful ERP systems like Odoo on serverless infrastructure (Cloud Run) requires a thoughtful approach to storage, configuration, and security. This guide details the architectural patterns and best practices for implementing Odoo on Google Cloud Platform (GCP) using Terraform, based on a production-grade implementation.

## 1. Architecture Overview

The recommended architecture leverages managed services to minimize operational overhead while maintaining the stateful requirements of Odoo.

*   **Compute:** **Cloud Run** (Gen2) provides a scalable, serverless container environment.
*   **Database:** **Cloud SQL for PostgreSQL** serves as the primary data store.
*   **File Storage:** **Cloud Filestore** (or an NFS server) is mounted to store Odoo's `filestore` (attachments, sessions).
*   **Addons Storage:** **Google Cloud Storage (GCS)** buckets are mounted via FUSE to serve custom addons, allowing for easy updates without rebuilding containers.
*   **Configuration:** **Secret Manager** securely stores sensitive credentials (DB passwords, Master Password).

## 2. Infrastructure as Code (Terraform)

The implementation is modular, separating the application logic (`WebApp`) from the backing infrastructure (`GCP_Services`).

### Module Interface

A robust Terraform module for Odoo should expose configuration for resources, image sources, and storage toggles.

```hcl
# modules/WebApp/modules/odoo/variables.tf

locals {
  odoo_module = {
    app_name        = "odoo"
    container_image = "odoo:18.0"

    # Enable Hybrid Storage
    enable_cloudsql_volume = true
    nfs_enabled            = true
    nfs_mount_path         = "/mnt"

    # Mount Addons from GCS
    gcs_volumes = [
      {
        name       = "odoo-addons-volume"
        mount_path = "/mnt/extra-addons"
      }
    ]

    # Custom Build Configuration
    image_source    = "custom"
    container_build_config = {
      enabled      = true
      context_path = "odoo"
    }
  }
}
```

## 3. Storage Strategy: The Hybrid Approach

Odoo requires a filesystem for session data and attachments (`filestore`). On Cloud Run, the local filesystem is ephemeral. We use a hybrid strategy:

1.  **Database:** Structured business data goes to Cloud SQL.
2.  **Filestore (NFS):** Mounted at `/mnt` for `data_dir`. This ensures attachments persist across container restarts.
3.  **Cloud Storage (GCS):** Mounted at `/mnt/extra-addons` for custom modules.

### Terraform Volume Configuration

In your Cloud Run resource definition, define both NFS and Cloud SQL volumes:

```hcl
# modules/WebApp/main.tf (Simplified)

template {
  containers {
    # ...
    volume_mounts {
      name       = "nfs-volume"
      mount_path = "/mnt"
    }
    volume_mounts {
      name       = "cloudsql"
      mount_path = "/cloudsql"
    }
  }

  volumes {
    name = "nfs-volume"
    nfs {
      server = var.nfs_server_ip
      path   = "/share/odoo"
    }
  }

  volumes {
    name = "cloudsql"
    cloud_sql_instance {
      instances = [var.cloud_sql_connection_name]
    }
  }
}
```

## 4. Secure Configuration Management

Avoid baking secrets into your Docker image. Instead, generate the `odoo.conf` file at runtime using environment variables injected from Secret Manager.

### Dynamic Configuration Script

Use an initialization container or an entrypoint script (`odoo-gen-config.sh`) to generate the config file. This allows you to keep the container image immutable while changing configuration per environment.

```bash
#!/bin/sh
# modules/WebApp/scripts/odoo/odoo-gen-config.sh

CONFIG_FILE="/mnt/odoo.conf"

# Generate configuration with variable substitution
cat > "${CONFIG_FILE}" << EOF
[options]
db_host = ${DB_HOST}
db_port = ${DB_PORT:-5432}
db_user = ${DB_USER}
db_password = ${DB_PASSWORD}
admin_passwd = ${ODOO_MASTER_PASS}
data_dir = /mnt/filestore
addons_path = /usr/lib/python3/dist-packages/odoo/addons,/mnt/extra-addons
EOF

# Secure permissions (Odoo runs as UID 101)
chown 101:101 "${CONFIG_FILE}"
chmod 640 "${CONFIG_FILE}"
```

### Managing the Master Password

The `admin_passwd` (Master Password) allows database creation/restoration. It **must** be strong and managed securely.

1.  Generate a random password in Terraform.
2.  Store it in Secret Manager.
3.  Inject it as an environment variable (`ODOO_MASTER_PASS`).

```hcl
# modules/WebApp/secrets.tf

resource "random_password" "odoo_master_pass" {
  length  = 16
  special = false
}

resource "google_secret_manager_secret_version" "odoo_master_pass" {
  secret      = google_secret_manager_secret.odoo_master_pass.id
  secret_data = random_password.odoo_master_pass.result
}
```

## 5. Container & Security Best Practices

### Custom Docker Build
While the official image is great, a custom build allows you to install system dependencies required by specific addons (e.g., Python libraries).

```dockerfile
# modules/WebApp/scripts/odoo/Dockerfile
FROM odoo:18.0

USER root

# Install dependencies for addons
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pandas \
    && rm -rf /var/lib/apt/lists/*

# Create mount points with correct permissions
RUN mkdir -p /mnt/filestore /mnt/extra-addons \
    && chown -R odoo:odoo /mnt

USER odoo
```

### File Permissions
Avoid the temptation to use `chmod 777`. It creates security vulnerabilities.
*   Ensure the NFS share is owned by the container user (UID 101 for Odoo).
*   Use initialization jobs to fix permissions if necessary, but try to set them correctly at provisioning time.

### Network Security
*   **Private Connectivity:** Run Cloud Run instances with `vpc_access` to connect to Cloud SQL and Filestore via private IP.
*   **No Public DB:** Do not assign public IPs to your Cloud SQL instance.

## 6. Initialization Jobs

Odoo often requires initial setup steps that shouldn't run every time the container starts. Use **Cloud Run Jobs** triggered by Terraform for:

1.  **NFS Setup:** Creating subdirectories on the fresh NFS share.
2.  **DB Initialization:** Creating the database user and extensions.
3.  **Config Generation:** Creating the `odoo.conf` file on the shared volume.

```hcl
# modules/WebApp/jobs.tf

resource "google_cloud_run_v2_job" "odoo_init" {
  # ...
  containers {
    image = "alpine:3.19"
    command = ["/bin/sh", "-c"]
    args = ["mkdir -p /mnt/filestore && chown -R 101:101 /mnt/filestore"]
    # ...
  }
}
```

## Conclusion

By combining **Terraform** for infrastructure definition, **Cloud Run** for compute, and **Secret Manager** for security, you can build a highly scalable and secure Odoo environment. The key is to treat configuration as ephemeral and storage as persistent, bridging the gap with hybrid volume mounts and dynamic initialization scripts.
