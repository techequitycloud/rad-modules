# Deploying Odoo ERP on Google Cloud Platform with Terraform: A Comprehensive Guide

## Introduction

Odoo is a powerful, open-source ERP system that encompasses CRM, e-commerce, billing, accounting, manufacturing, warehouse management, and project management capabilities. Deploying Odoo at scale on Google Cloud Platform (GCP) requires careful consideration of infrastructure design, security, scalability, and operational efficiency.

This guide presents a production-ready architecture for deploying Odoo 18 on GCP using Terraform, based on a battle-tested modular infrastructure approach. We'll explore the complete implementation from infrastructure provisioning to application deployment, with practical code examples you can adapt for your own projects.

## Architecture Overview

### High-Level Architecture

The deployment architecture consists of three primary layers:

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │   Cloud Run Service (Odoo 18.0 Container)            │  │
│  │   - Auto-scaling (0-3 instances)                     │  │
│  │   - 2 vCPU / 4GB RAM per instance                    │  │
│  │   - Session affinity enabled                         │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼────────────────────┐
        │                   │                    │
        ▼                   ▼                    ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────────┐
│   NFS Server │   │  Cloud SQL   │   │  Cloud Storage   │
│  (GCE VM)    │   │ PostgreSQL   │   │  (GCS Buckets)   │
│              │   │   15.0       │   │                  │
│  Filestore   │   │              │   │  Custom Addons   │
│  Sessions    │   │  Private IP  │   │  Backups         │
│  Backups     │   │  Auto-backup │   │                  │
└──────────────┘   └──────────────┘   └──────────────────┘
        │                   │                    │
        └───────────────────┼────────────────────┘
                            │
                ┌───────────▼──────────┐
                │   VPC Network        │
                │  - Private subnet    │
                │  - Firewall rules    │
                │  - Service accounts  │
                └──────────────────────┘
```

### Key Components

1. **Cloud Run**: Serverless container platform for running Odoo with automatic scaling
2. **Cloud SQL PostgreSQL**: Managed database with automated backups and high availability
3. **Compute Engine NFS**: Network file system for persistent storage (filestore, sessions)
4. **Cloud Storage**: Object storage for custom addons and backups
5. **VPC Network**: Private networking with secure connectivity between components
6. **Secret Manager**: Secure storage for database credentials and API keys

## Module Structure

The implementation uses a hierarchical Terraform module structure:

```
rad-modules/
├── modules/
│   ├── GCP_Project/          # Creates GCP projects
│   ├── GCP_Services/         # Core infrastructure layer
│   │   ├── network.tf        # VPC, subnets, firewall
│   │   ├── pgsql.tf         # Cloud SQL PostgreSQL
│   │   ├── nfs.tf           # NFS server on GCE
│   │   ├── redis.tf         # Redis cache
│   │   └── sa.tf            # Service accounts
│   │
│   └── CloudRunApp/              # Application deployment layer
│       ├── modules/
│       │   └── odoo/        # Odoo preset configuration
│       │       └── variables.tf
│       ├── service.tf       # Cloud Run service
│       ├── jobs.tf          # Initialization jobs
│       ├── iam.tf           # IAM and permissions
│       └── scripts/
│           └── odoo/        # Odoo-specific scripts
│               ├── Dockerfile
│               ├── entrypoint.sh
│               └── odoo-gen-config.sh
```

## Infrastructure Layer: GCP_Services Module

### PostgreSQL Cloud SQL Configuration

The foundation starts with a highly available PostgreSQL instance with optimized settings for Odoo:

```hcl
resource "google_sql_database_instance" "postgres_instance" {
  count                = var.create_postgres ? 1 : 0
  name                 = format("cloud-sql-postgres-%s", local.random_id)
  region               = local.region
  database_version     = "POSTGRES_15"
  deletion_protection  = false
  root_password        = random_password.root_password.result

  settings {
    activation_policy  = "ALWAYS"
    availability_type  = "REGIONAL"  # For high availability
    tier               = "db-custom-2-8192"  # 2 vCPU, 8GB RAM
    edition            = "ENTERPRISE"
    disk_autoresize    = true
    disk_type          = "PD_SSD"

    ip_configuration {
      ipv4_enabled    = false  # Private IP only for security
      private_network = "projects/${var.project_id}/global/networks/${var.network_name}"
      ssl_mode        = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
    }

    backup_configuration {
      enabled                        = true
      location                       = local.region
      point_in_time_recovery_enabled = true
      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
      start_time                     = "04:00"
      transaction_log_retention_days = 7
    }

    # Optimized for Odoo's connection pooling
    database_flags {
      name  = "max_connections"
      value = "30000"
    }
  }

  timeouts {
    create = "60m"
    update = "60m"
    delete = "30m"
  }
}
```

**Best Practices:**
- Use **private IP only** to prevent public internet exposure
- Enable **point-in-time recovery** for disaster recovery
- Set `max_connections` high enough for Odoo's worker processes
- Use **REGIONAL** availability for production workloads
- Configure **automated backups** with appropriate retention

### NFS Server on Compute Engine

Odoo requires persistent storage for filestore (uploaded files) and sessions. While Cloud Filestore is an option, a cost-effective approach uses a Compute Engine instance with an attached SSD:

```hcl
resource "google_compute_instance_template" "nfs_server" {
  count        = var.create_network_filesystem ? 1 : 0
  name         = "nfsserver-tpl-${random_string.nfs_suffix[0].result}"
  machine_type = "e2-medium"  # 2 vCPU, 4GB RAM
  region       = local.region

  # Boot disk - Ubuntu 22.04
  disk {
    boot         = true
    source_image = "ubuntu-os-cloud/ubuntu-2204-jammy-v20240927"
    disk_type    = "pd-standard"
    disk_size_gb = 10
  }

  # Data disk - SSD for better I/O performance
  disk {
    boot         = false
    disk_type    = "pd-ssd"
    disk_size_gb = var.network_filesystem_capacity  # Configurable size
    device_name  = "data-disk"
    auto_delete  = false
    resource_policies = [google_compute_resource_policy.daily_snapshot[0].id]
  }

  network_interface {
    subnetwork = "projects/${var.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
    network_ip = google_compute_address.static_internal_ip[0].address
  }

  service_account {
    email  = local.nfsserver_sa_email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = file("${path.module}/scripts/create_nfs.sh")
}

# Managed instance group for auto-healing
resource "google_compute_instance_group_manager" "nfs_server" {
  count              = var.create_network_filesystem ? 1 : 0
  name               = "nfsserver-mig"
  zone               = data.google_compute_zones.available_zones.names[0]
  base_instance_name = "nfsserver"
  target_size        = 1

  version {
    instance_template = google_compute_instance_template.nfs_server[0].id
  }

  stateful_disk {
    device_name = "data-disk"
    delete_rule = "ON_PERMANENT_INSTANCE_DELETION"
  }

  # Health check for auto-healing
  auto_healing_policies {
    health_check      = google_compute_health_check.nfs_server_health_check[0].id
    initial_delay_sec = 300
  }
}
```

**Best Practices:**
- Use **static internal IP** for consistent NFS server address
- Implement **daily snapshots** for the data disk
- Use **managed instance groups** with health checks for auto-healing
- Configure **stateful disks** to persist data across instance recreation
- Use **SSD persistent disks** for better I/O performance

### VPC and Networking

```hcl
# VPC Network
resource "google_compute_network" "vpc_network" {
  name                    = "vpc-network"
  auto_create_subnetworks = false
  project                 = local.project.project_id
}

# Subnet per region
resource "google_compute_subnetwork" "gce_subnet" {
  for_each = toset(var.regions)

  name          = "gce-vpc-subnet-${each.value}"
  ip_cidr_range = cidrsubnet(var.vpc_cidr, 8, index(var.regions, each.value))
  region        = each.value
  network       = google_compute_network.vpc_network.id
  project       = local.project.project_id

  private_ip_google_access = true
}

# Firewall rule for NFS
resource "google_compute_firewall" "allow_nfs" {
  name    = "allow-nfs"
  network = google_compute_network.vpc_network.name
  project = local.project.project_id

  allow {
    protocol = "tcp"
    ports    = ["2049", "111"]  # NFS and rpcbind
  }

  source_tags = ["nfsserver"]
  target_tags = ["nfsserver"]
}
```

## Application Layer: Odoo Deployment

### Odoo Application Preset

The CloudRunApp module uses a preset configuration system. Here's the complete Odoo preset from `modules/CloudRunApp/modules/odoo/variables.tf`:

```hcl
locals {
  odoo_module = {
    app_name        = "odoo"
    description     = "Odoo ERP System - CRM, e-commerce, billing, accounting, manufacturing, warehouse, project management"
    container_image = "odoo:18.0"
    container_port  = 8069
    database_type   = "POSTGRES_15"
    db_name         = "odoo"
    db_user         = "odoo"

    # Custom container build configuration
    image_source = "custom"
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "odoo"
      build_args         = {}
      artifact_repo_name = "erp-repo"
    }

    # Cloud SQL Unix socket connectivity
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"

    # NFS for filestore and sessions
    nfs_enabled    = true
    nfs_mount_path = "/mnt"

    # GCS volume for custom addons
    gcs_volumes = [{
      name          = "odoo-addons-volume"
      mount_path    = "/mnt/extra-addons"
      read_only     = false
      mount_options = ["implicit-dirs", "metadata-cache-ttl-secs=60"]
    }]

    # Resource allocation
    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 0  # Scale to zero when idle
    max_instance_count = 3

    # Container startup validation
    container_command = ["/bin/bash", "-c"]
    container_args = [
      <<-EOT
        set -e
        echo "=========================================="
        echo "Starting Odoo Server"
        echo "=========================================="

        # Verify configuration file exists
        if [ ! -f /mnt/odoo.conf ]; then
            echo "ERROR: /mnt/odoo.conf not found"
            exit 1
        fi

        # Verify filestore directory exists
        if [ ! -d /mnt/filestore ]; then
            echo "ERROR: /mnt/filestore not found"
            exit 1
        fi

        # Test filestore write access
        if ! touch /mnt/filestore/.test 2>/dev/null; then
            echo "ERROR: Cannot write to /mnt/filestore"
            ls -la /mnt/filestore/
            exit 1
        fi
        rm -f /mnt/filestore/.test

        echo "All checks passed"
        echo "Starting Odoo server..."
        exec odoo -c /mnt/odoo.conf
      EOT
    ]

    environment_variables = {
      SMTP_HOST     = ""
      SMTP_PORT     = "25"
      SMTP_USER     = ""
      SMTP_PASSWORD = ""
      SMTP_SSL      = "false"
      EMAIL_FROM    = "odoo@example.com"
    }

    # Health checks
    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 180
      timeout_seconds       = 60
      period_seconds        = 120
      failure_threshold     = 3
    }

    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/web/health"
      initial_delay_seconds = 120
      timeout_seconds       = 60
      period_seconds        = 120
      failure_threshold     = 3
    }
  }
}
```

### Initialization Jobs

Odoo deployment requires four sequential initialization jobs:

#### Job 1: NFS Directory Initialization

```hcl
{
  name        = "nfs-init"
  description = "Initialize NFS directories for Odoo"
  image       = "alpine:3.19"
  command     = ["/bin/sh", "-c"]
  args = [
    <<-EOT
      set -e
      echo "=========================================="
      echo "NFS Initialization"
      echo "=========================================="

      echo "Creating directories..."
      mkdir -p /mnt/filestore /mnt/sessions /mnt/backups

      echo "Setting ownership and permissions..."
      # Odoo runs as UID 101
      if chown -R 101:101 /mnt/filestore /mnt/sessions /mnt/backups 2>/dev/null; then
        echo "Ownership set to 101:101"
        chmod -R 775 /mnt/filestore /mnt/sessions /mnt/backups
      else
        echo "chown failed, using 777 permissions"
        chmod -R 777 /mnt/filestore /mnt/sessions /mnt/backups
      fi

      # Verify write access
      if touch /mnt/filestore/.test 2>/dev/null; then
        echo "Write test successful"
        rm -f /mnt/filestore/.test
      else
        echo "Write test failed"
        exit 1
      fi

      echo "NFS initialization complete"
    EOT
  ]
  mount_nfs         = true
  depends_on_jobs   = []
  execute_on_apply  = true
}
```

**Best Practices:**
- Create all required directories upfront
- Set correct ownership (Odoo container runs as UID 101)
- Verify write access before proceeding
- Use graceful fallback for permission errors

#### Job 2: Database Initialization

```hcl
{
  name        = "db-init"
  description = "Create Odoo Database and User"
  image       = "alpine:3.19"
  command     = ["/bin/sh", "-c"]
  args = [
    <<-EOT
      set -e
      echo "Installing PostgreSQL client..."
      apk update && apk add --no-cache postgresql-client netcat-openbsd

      # Test connectivity
      echo "Testing connectivity to ${DB_HOST}:5432..."
      if timeout 5 nc -zv ${DB_HOST} 5432 2>&1; then
        echo "Port 5432 is reachable"
      else
        echo "ERROR: Cannot reach ${DB_HOST}:5432"
        exit 1
      fi

      # Connect to database with retry logic
      export PGPASSWORD=${ROOT_PASSWORD}
      export PGCONNECT_TIMEOUT=5

      MAX_RETRIES=60
      RETRY_COUNT=0

      while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if psql -h ${DB_HOST} -p 5432 -U postgres -d postgres -c '\l' > /dev/null 2>&1; then
          echo "Database connected after $RETRY_COUNT attempts"
          break
        fi
        RETRY_COUNT=`expr $RETRY_COUNT + 1`
        echo "Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
        sleep 2
      done

      if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "ERROR: Failed to connect after $MAX_RETRIES attempts"
        exit 1
      fi

      # Create database role
      echo "Creating database role..."
      psql -h ${DB_HOST} -p 5432 -U postgres -d postgres <<EOF
      DO \$\$
      BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
          CREATE ROLE "${DB_USER}" WITH LOGIN PASSWORD '${DB_PASSWORD}';
        ELSE
          ALTER ROLE "${DB_USER}" WITH PASSWORD '${DB_PASSWORD}';
        END IF;
      END
      \$\$;
      ALTER ROLE "${DB_USER}" CREATEDB;
      GRANT ALL PRIVILEGES ON DATABASE postgres TO "${DB_USER}";
      EOF

      # Create database if not exists
      echo "Creating database..."
      if ! psql -h ${DB_HOST} -p 5432 -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
        export PGPASSWORD=${DB_PASSWORD}
        psql -h ${DB_HOST} -p 5432 -U ${DB_USER} -d postgres -c "CREATE DATABASE \"${DB_NAME}\" OWNER \"${DB_USER}\";"
        echo "Database created"
      else
        echo "Database already exists"
      fi

      echo "Database initialization complete"
    EOT
  ]
  mount_nfs       = false
  depends_on_jobs = []
  execute_on_apply = true
}
```

**Best Practices:**
- Implement retry logic for database connectivity
- Use idempotent SQL commands (IF NOT EXISTS)
- Grant CREATEDB privilege for Odoo's module installation
- Validate connectivity before attempting operations
- Use environment variables for credentials

#### Job 3: Configuration File Generation

```hcl
{
  name        = "odoo-config"
  description = "Generate Odoo configuration file"
  image       = "alpine:3.19"
  command     = ["/bin/sh", "-c"]
  args = [
    <<-EOT
      set -e
      CONFIG_FILE="/mnt/odoo.conf"

      # Verify NFS mount is writable
      if ! touch /mnt/.test 2>/dev/null; then
        echo "ERROR: Cannot write to /mnt"
        exit 1
      fi
      rm -f /mnt/.test

      # Generate configuration file
      cat > "${CONFIG_FILE}" << EOF
[options]
#########################################################################
# Database Configuration
#########################################################################
db_host = ${DB_HOST}
db_port = ${DB_PORT:-5432}
db_user = ${DB_USER}
db_password = ${DB_PASSWORD}
db_name = ${DB_NAME}
db_maxconn = 64
db_template = template0

#########################################################################
# Admin Password
#########################################################################
admin_passwd = ${ODOO_MASTER_PASS}

#########################################################################
# Paths
#########################################################################
data_dir = /mnt/filestore
addons_path = /usr/lib/python3/dist-packages/odoo/addons,/mnt/extra-addons

#########################################################################
# Server Configuration
#########################################################################
xmlrpc_port = 8069
longpolling_port = 8072
proxy_mode = True
logfile = /var/log/odoo/odoo.log
log_level = info
log_handler = :INFO
log_db = False

#########################################################################
# Worker Configuration
#########################################################################
workers = 4
max_cron_threads = 2

#########################################################################
# Resource Limits
#########################################################################
limit_memory_hard = 1610612736
limit_memory_soft = 671088640
limit_request = 8192

#########################################################################
# Time Limits
#########################################################################
limit_time_cpu = 600
limit_time_real = 1200
limit_time_real_cron = -1

#########################################################################
# Security
#########################################################################
list_db = False

#########################################################################
# Performance
#########################################################################
server_wide_modules = base,web
unaccent = True
EOF

      # Append SMTP configuration if provided
      if [ -n "${SMTP_HOST}" ]; then
        cat >> "${CONFIG_FILE}" << EOF

#########################################################################
# SMTP Configuration
#########################################################################
smtp_server = ${SMTP_HOST}
smtp_port = ${SMTP_PORT:-25}
smtp_user = ${SMTP_USER}
smtp_password = ${SMTP_PASSWORD}
smtp_ssl = ${SMTP_SSL}
email_from = ${EMAIL_FROM}
EOF
      fi

      # Set permissions (Odoo runs as UID 101)
      chown 101:101 "${CONFIG_FILE}" 2>/dev/null || true
      chmod 640 "${CONFIG_FILE}"

      echo "Configuration file created at ${CONFIG_FILE}"
    EOT
  ]
  mount_nfs       = true
  depends_on_jobs = ["nfs-init"]
  execute_on_apply = true
}
```

**Odoo Configuration Best Practices:**

1. **Worker Configuration**: Set `workers = 4` for a 2-CPU container
   - Formula: (2 * CPU_cores) + 1 = recommended workers
   - Enables parallel request processing

2. **Resource Limits**:
   - `limit_memory_hard`: Maximum memory per worker (1.5 GB)
   - `limit_memory_soft`: Soft limit before warning (640 MB)
   - Prevents memory exhaustion

3. **Time Limits**:
   - `limit_time_cpu`: CPU time limit per request (600s)
   - `limit_time_real`: Wall clock time limit (1200s)
   - `limit_time_real_cron`: Unlimited for cron jobs (-1)

4. **Security**:
   - `list_db = False`: Hide database list from public
   - `proxy_mode = True`: Trust X-Forwarded-* headers from Cloud Run
   - Store `admin_passwd` securely (used for database management operations)

5. **Performance**:
   - `db_maxconn = 64`: Match PostgreSQL's connection pool
   - `unaccent = True`: Enable accent-insensitive search
   - `server_wide_modules`: Load only essential modules

#### Job 4: Database Initialization with Odoo

```hcl
{
  name        = "odoo-init"
  description = "Initialize Odoo database"
  image       = null  # Uses the same image as the main container
  command     = ["/bin/bash", "-c"]
  args = [
    <<-EOT
      set -e
      echo "=========================================="
      echo "Odoo Database Initialization"
      echo "=========================================="

      # Verify all mounts
      if [ ! -d /mnt ]; then
        echo "ERROR: /mnt not found"
        exit 1
      fi

      if [ ! -d /mnt/extra-addons ]; then
        echo "ERROR: /mnt/extra-addons not found"
        exit 1
      fi

      # Wait for config file
      MAX_RETRIES=30
      RETRY_COUNT=0
      while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if [ -f /mnt/odoo.conf ]; then
          echo "Config file found"
          break
        fi
        RETRY_COUNT=`expr $RETRY_COUNT + 1`
        echo "Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
        sleep 2
      done

      if [ ! -f /mnt/odoo.conf ]; then
        echo "ERROR: /mnt/odoo.conf not found"
        exit 1
      fi

      # Test filestore write access
      if ! touch /mnt/filestore/.test 2>/dev/null; then
        echo "ERROR: Cannot write to /mnt/filestore"
        exit 1
      fi
      rm -f /mnt/filestore/.test

      # Check if database already initialized
      if psql "postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:5432/${DB_NAME}" \
           -c "SELECT 1 FROM information_schema.tables WHERE table_name='ir_module_module';" 2>/dev/null | grep -q 1; then
        echo "Database already initialized"
        exit 0
      fi

      echo "Initializing Odoo database with base modules..."
      odoo -c /mnt/odoo.conf -i base --stop-after-init --log-level=info

      echo "Odoo initialization complete"
    EOT
  ]
  mount_nfs         = true
  mount_gcs_volumes = ["odoo-addons-volume"]
  depends_on_jobs   = ["nfs-init", "db-init", "odoo-config"]
  execute_on_apply  = true
}
```

**Best Practices:**
- Verify all mounts before proceeding
- Implement idempotency checks (skip if already initialized)
- Use `--stop-after-init` flag to exit after database setup
- Install only base modules initially; additional modules can be installed via UI

### Cloud Run Service Configuration

The Cloud Run service is defined in `modules/CloudRunApp/service.tf`:

```hcl
resource "google_cloud_run_v2_service" "app_service" {
  project             = local.project.project_id
  name                = local.service_name
  location            = local.region
  deletion_protection = false
  description         = local.application_description
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account       = local.cloud_run_sa_email
    session_affinity      = true  # Important for Odoo's stateful sessions
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout               = "300s"

    labels = {
      app     = "odoo"
      version = "18-0"
    }

    # Auto-scaling configuration
    scaling {
      min_instance_count = 0  # Scale to zero when idle
      max_instance_count = 3
    }

    containers {
      image   = local.container_image
      command = local.final_container_command
      args    = local.final_container_args

      ports {
        name           = "http1"
        container_port = 8069
      }

      resources {
        startup_cpu_boost = true  # Faster cold starts
        cpu_idle          = true  # Allow CPU throttling when idle
        limits = {
          cpu    = "2000m"
          memory = "4Gi"
        }
      }

      # Startup probe - TCP check during initialization
      startup_probe {
        initial_delay_seconds = 180  # Odoo takes time to start
        timeout_seconds       = 60
        period_seconds        = 120
        failure_threshold     = 3

        tcp_socket {
          port = 8069
        }
      }

      # Liveness probe - HTTP health check
      liveness_probe {
        initial_delay_seconds = 120
        timeout_seconds       = 60
        period_seconds        = 120
        failure_threshold     = 3

        http_get {
          path = "/web/health"
          port = 8069
        }
      }

      # Environment variables
      env {
        name  = "DB_HOST"
        value = local.db_internal_ip
      }

      env {
        name  = "DB_PORT"
        value = "5432"
      }

      env {
        name  = "DB_NAME"
        value = "odoo"
      }

      env {
        name  = "DB_USER"
        value = "odoo"
      }

      # Database password from Secret Manager
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }

      # NFS volume mount
      volume_mounts {
        name       = "nfs-volume"
        mount_path = "/mnt"
      }

      # GCS volume mount for custom addons
      volume_mounts {
        name       = "odoo-addons-volume"
        mount_path = "/mnt/extra-addons"
      }

      # Cloud SQL Unix socket mount
      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
    }

    # NFS volume definition
    volumes {
      name = "nfs-volume"
      nfs {
        server = local.nfs_internal_ip
        path   = "/data/nfs"
      }
    }

    # GCS volume definition
    volumes {
      name = "odoo-addons-volume"
      gcs {
        bucket        = google_storage_bucket.addons_bucket.name
        read_only     = false
        mount_options = ["implicit-dirs", "metadata-cache-ttl-secs=60"]
      }
    }

    # Cloud SQL volume
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = ["${local.project.project_id}:${local.region}:${local.db_instance_name}"]
      }
    }

    # VPC connector for private networking
    vpc_access {
      network_interfaces {
        network    = "projects/${local.project.project_id}/global/networks/${local.network_name}"
        subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/${local.subnet_name}"
      }
      egress = "PRIVATE_RANGES_ONLY"  # Route only private traffic through VPC
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [
    null_resource.execute_nfs_setup_job,
    null_resource.execute_initialization_jobs,
  ]
}
```

**Cloud Run Best Practices:**

1. **Session Affinity**: Enable `session_affinity = true` for Odoo
   - Ensures users stick to the same instance
   - Required for proper session management

2. **Startup CPU Boost**: Enable for faster cold starts
   - Temporarily allocates extra CPU during startup
   - Reduces initialization time

3. **Scale to Zero**: Set `min_instance_count = 0`
   - Reduces costs for development/staging environments
   - Set to 1+ for production to avoid cold starts

4. **Health Checks**: Use appropriate probe types
   - **Startup probe**: TCP check (Odoo may not respond to HTTP during init)
   - **Liveness probe**: HTTP GET `/web/health` (Odoo provides this endpoint)

5. **VPC Egress**: Use `PRIVATE_RANGES_ONLY`
   - Routes only private IP traffic through VPC connector
   - Public internet traffic uses faster default route

### Custom Docker Image

The custom Dockerfile (`modules/CloudRunApp/scripts/odoo/Dockerfile`) extends the base Odoo image with GCP-specific optimizations:

```dockerfile
FROM ubuntu:jammy
MAINTAINER Odoo S.A. <info@odoo.com>

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ENV LANG en_US.UTF-8

ARG TARGETARCH
ARG APP_VERSION=18.0
ARG APP_RELEASE=20260119
ARG APP_SHA=798dfc952eed08e0d976364c26dc47a45535be70

# Install dependencies
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        fonts-noto-cjk \
        gnupg \
        node-less \
        npm \
        python3-pip \
        python3-phonenumbers \
        python3-qrcode \
        python3-setuptools \
        xz-utils \
        wkhtmltopdf

# Install PostgreSQL 16 client
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ jammy-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    && apt-get update \
    && apt-get install -y postgresql-client-16 \
    && rm -rf /var/lib/apt/lists/*

# Install rtlcss for RTL language support
RUN npm install -g rtlcss

# Install GCP libraries for potential integrations
RUN pip3 install --upgrade \
    google-cloud-storage \
    google-cloud-secret-manager \
    google-api-python-client

# Install helper utilities
RUN apt-get update -y && apt-get install -y \
    tini \
    nfs-common \
    procps \
    net-tools \
    && apt-get clean

# Install Odoo
RUN curl -o odoo.deb -sSL http://nightly.odoo.com/${APP_VERSION}/nightly/deb/odoo_${APP_VERSION}.${APP_RELEASE}_all.deb \
    && echo "${APP_SHA} odoo.deb" | sha1sum -c - \
    && apt-get update \
    && apt-get -y install --no-install-recommends ./odoo.deb \
    && rm -rf /var/lib/apt/lists/* odoo.deb

# Copy custom entrypoint
COPY ./entrypoint.sh /
RUN chmod +x /entrypoint.sh
COPY ./odoo.conf /etc/odoo/

# Create required directories with correct permissions
RUN chown -R odoo:odoo /etc/odoo \
    && mkdir -p /mnt/filestore /mnt/sessions /var/lib/odoo \
    && chown -R odoo:odoo /mnt /var/lib/odoo \
    && chmod 755 /mnt/filestore /mnt/sessions

# Create addon directory
RUN mkdir /extra-addons \
    && chmod -R 755 /extra-addons \
    && chown -R odoo /extra-addons

EXPOSE 8069 8071 8072

ENV ODOO_RC /etc/odoo/odoo.conf

# Run as odoo user (UID 101)
USER odoo

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
CMD ["odoo", "--http-port=8069"]
```

**Dockerfile Best Practices:**

1. **Use tini**: Proper signal handling for graceful shutdown
2. **NFS common**: Required for mounting NFS volumes
3. **Non-root user**: Run as `odoo` user (UID 101) for security
4. **GCP libraries**: Pre-install for potential integrations
5. **Multi-architecture**: Support for AMD64 and ARM64
6. **Layer optimization**: Combine RUN commands to reduce image size

## Complete Deployment Example

Here's a complete example of deploying Odoo using the modules:

### Step 1: Project Setup

```hcl
# main.tf

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Optional: Create a new GCP project
module "gcp_project" {
  source = "./modules/GCP_Project"

  project_name    = "odoo-production"
  billing_account = var.billing_account_id
  org_id          = var.organization_id
  folder_id       = var.folder_id
}
```

### Step 2: Infrastructure Layer

```hcl
# infrastructure.tf

module "gcp_services" {
  source = "./modules/GCP_Services"

  # Project configuration
  existing_project_id = module.gcp_project.project_id
  region              = "us-central1"
  regions             = ["us-central1", "us-east1"]  # Multi-region support

  # Networking
  create_network              = true
  network_name                = "vpc-network"
  vpc_cidr                    = "10.0.0.0/16"

  # PostgreSQL
  create_postgres             = true
  postgres_database_version   = "POSTGRES_15"
  postgres_tier               = "db-custom-2-8192"  # 2 vCPU, 8GB RAM
  postgres_database_availability_type = "REGIONAL"

  # NFS Server
  create_network_filesystem   = true
  network_filesystem_machine  = "e2-medium"
  network_filesystem_capacity = 100  # GB

  # Redis (optional, for caching)
  create_redis                = true
  redis_memory_size_gb        = 1
  redis_tier                  = "BASIC"

  # Labels
  labels = {
    environment = "production"
    application = "odoo"
    managed_by  = "terraform"
  }
}
```

### Step 3: Odoo Application Deployment

```hcl
# odoo.tf

module "odoo_app" {
  source = "./modules/CloudRunApp"

  # Application selection
  app_name = "odoo"

  # Project and region
  existing_project_id = module.gcp_project.project_id
  region              = "us-central1"

  # Use infrastructure from GCP_Services module
  existing_sql_server_name    = module.gcp_services.postgres_instance_name
  sql_server_database_version = "POSTGRES_15"
  existing_nfs_server_ip      = module.gcp_services.nfs_server_ip
  existing_nfs_share_path     = module.gcp_services.nfs_share_path
  existing_network_name       = module.gcp_services.network_name
  existing_subnet_map         = module.gcp_services.subnet_map

  # Container configuration
  container_image        = "odoo:18.0"
  enable_custom_build    = true  # Build custom Docker image

  # Scaling
  min_instance_count = 1  # Production: always-on
  max_instance_count = 5

  # Resources
  container_cpu_limit    = "2000m"
  container_memory_limit = "4Gi"

  # Storage
  nfs_enabled    = true
  nfs_mount_path = "/mnt"

  # GCS bucket for custom addons
  gcs_volumes = [{
    name          = "odoo-addons-volume"
    mount_path    = "/mnt/extra-addons"
    read_only     = false
    bucket_name   = "odoo-custom-addons-${var.project_id}"
  }]

  # Database
  db_name = "odoo_production"
  db_user = "odoo"

  # Environment-specific variables
  environment_variables = {
    SMTP_HOST     = "smtp.gmail.com"
    SMTP_PORT     = "587"
    SMTP_USER     = var.smtp_user
    SMTP_PASSWORD = var.smtp_password
    SMTP_SSL      = "true"
    EMAIL_FROM    = "noreply@yourcompany.com"
  }

  # Secrets (stored in Secret Manager)
  secret_env_vars = {
    ODOO_MASTER_PASS = google_secret_manager_secret_version.odoo_master_password.id
  }

  # Monitoring
  enable_monitoring = true
  enable_alerting   = true

  # Labels
  labels = {
    environment = "production"
    application = "odoo"
    version     = "18-0"
  }

  depends_on = [
    module.gcp_services
  ]
}
```

### Step 4: Variables

```hcl
# variables.tf

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "billing_account_id" {
  description = "Billing account ID"
  type        = string
}

variable "organization_id" {
  description = "GCP Organization ID"
  type        = string
}

variable "smtp_user" {
  description = "SMTP username for email"
  type        = string
  sensitive   = true
}

variable "smtp_password" {
  description = "SMTP password for email"
  type        = string
  sensitive   = true
}
```

### Step 5: Outputs

```hcl
# outputs.tf

output "odoo_url" {
  description = "Odoo application URL"
  value       = module.odoo_app.service_url
}

output "database_instance" {
  description = "Cloud SQL instance name"
  value       = module.gcp_services.postgres_instance_name
}

output "nfs_server_ip" {
  description = "NFS server internal IP"
  value       = module.gcp_services.nfs_server_ip
}

output "project_id" {
  description = "GCP Project ID"
  value       = module.gcp_project.project_id
}
```

### Step 6: Deployment Commands

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan -out=tfplan

# Apply the configuration
terraform apply tfplan

# Get the Odoo URL
terraform output odoo_url
```

## Advanced Configuration

### Multi-Region Deployment

For high availability across regions:

```hcl
module "odoo_us_central" {
  source = "./modules/CloudRunApp"

  app_name = "odoo"
  region   = "us-central1"

  # Shared database (primary region)
  existing_sql_server_name = module.gcp_services.postgres_instance_name

  # Regional NFS
  existing_nfs_server_ip = module.gcp_services_us_central.nfs_server_ip

  min_instance_count = 1
  max_instance_count = 5
}

module "odoo_us_east" {
  source = "./modules/CloudRunApp"

  app_name = "odoo"
  region   = "us-east1"

  # Shared database (read replica or same instance)
  existing_sql_server_name = module.gcp_services.postgres_instance_name

  # Regional NFS (with replication)
  existing_nfs_server_ip = module.gcp_services_us_east.nfs_server_ip

  min_instance_count = 1
  max_instance_count = 5
}

# Load balancer to distribute traffic
resource "google_compute_global_address" "odoo_lb_ip" {
  name = "odoo-lb-ip"
}

resource "google_compute_global_forwarding_rule" "odoo_lb" {
  name       = "odoo-lb"
  target     = google_compute_target_https_proxy.odoo_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.odoo_lb_ip.address
}
```

### Custom Addon Management

Upload custom Odoo addons to the GCS bucket:

```bash
# Create a bucket for addons
gsutil mb gs://odoo-custom-addons-${PROJECT_ID}

# Upload your custom addons
gsutil -m cp -r ./my_custom_addons/* gs://odoo-custom-addons-${PROJECT_ID}/

# Set permissions
gsutil iam ch serviceAccount:${SERVICE_ACCOUNT}:objectViewer \
  gs://odoo-custom-addons-${PROJECT_ID}
```

In Odoo configuration, the addons path is automatically configured:
```ini
addons_path = /usr/lib/python3/dist-packages/odoo/addons,/mnt/extra-addons
```

### Database Backup and Restore

#### Automated Backups

Cloud SQL automatically handles backups, but you can also export to GCS:

```bash
# Export database to GCS
gcloud sql export sql ${DATABASE_INSTANCE} \
  gs://${BACKUP_BUCKET}/odoo-backup-$(date +%Y%m%d).sql \
  --database=odoo_production

# Schedule via Cloud Scheduler
gcloud scheduler jobs create http odoo-daily-backup \
  --schedule="0 2 * * *" \
  --uri="https://sqladmin.googleapis.com/v1/projects/${PROJECT_ID}/instances/${INSTANCE}/export" \
  --http-method=POST \
  --message-body="{
    \"exportContext\": {
      \"fileType\": \"SQL\",
      \"uri\": \"gs://${BACKUP_BUCKET}/odoo-backup-$(date +%Y%m%d).sql\",
      \"databases\": [\"odoo_production\"]
    }
  }"
```

#### Restore from Backup

```bash
# Import from GCS backup
gcloud sql import sql ${DATABASE_INSTANCE} \
  gs://${BACKUP_BUCKET}/odoo-backup-20260124.sql \
  --database=odoo_production
```

### Performance Tuning

#### PostgreSQL Optimization

Add these database flags to `pgsql.tf`:

```hcl
settings {
  database_flags {
    name  = "max_connections"
    value = "30000"
  }

  database_flags {
    name  = "shared_buffers"
    value = "2048MB"  # 25% of RAM for 8GB instance
  }

  database_flags {
    name  = "effective_cache_size"
    value = "6GB"  # 75% of RAM
  }

  database_flags {
    name  = "work_mem"
    value = "16MB"
  }

  database_flags {
    name  = "maintenance_work_mem"
    value = "512MB"
  }

  database_flags {
    name  = "random_page_cost"
    value = "1.1"  # SSD optimization
  }

  database_flags {
    name  = "checkpoint_completion_target"
    value = "0.9"
  }
}
```

#### Odoo Worker Tuning

Adjust workers based on container resources:

```ini
# For 2 vCPU container
workers = 5  # (2 * 2) + 1
max_cron_threads = 1

# For 4 vCPU container
workers = 9  # (2 * 4) + 1
max_cron_threads = 2
```

#### Redis Integration

Add Redis for session storage:

```hcl
# In CloudRunApp module
environment_variables = {
  REDIS_HOST = module.gcp_services.redis_host
  REDIS_PORT = "6379"
}
```

Configure Odoo to use Redis (requires custom addon or configuration):

```python
# In custom addon or server configuration
import redis
SESSION_REDIS = redis.StrictRedis(
    host=os.environ.get('REDIS_HOST'),
    port=6379,
    db=1
)
```

### Monitoring and Observability

#### Cloud Monitoring Metrics

The CloudRunApp module automatically creates monitoring dashboards. Key metrics to watch:

```hcl
# modules/CloudRunApp/monitoring.tf includes:

# 1. Container CPU utilization
# 2. Container memory utilization
# 3. Request count
# 4. Request latency (p50, p95, p99)
# 5. Error rate (5xx responses)
# 6. Instance count
# 7. Database connections
```

#### Custom Alerts

```hcl
resource "google_monitoring_alert_policy" "high_response_time" {
  display_name = "Odoo High Response Time"
  combiner     = "OR"

  conditions {
    display_name = "Response time > 5s"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_latencies\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5000  # milliseconds

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_DELTA"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}
```

#### Logging

Access logs via Cloud Logging:

```bash
# View application logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=odoo" \
  --limit 50 \
  --format json

# Filter for errors
gcloud logging read "resource.type=cloud_run_revision AND severity>=ERROR" \
  --limit 50
```

### Security Best Practices

#### 1. Network Security

```hcl
# Restrict Cloud Run ingress
ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"  # Only via load balancer

# VPC egress control
vpc_access {
  egress = "PRIVATE_RANGES_ONLY"  # Block direct internet access
}

# Firewall rules
resource "google_compute_firewall" "deny_all_ingress" {
  name    = "deny-all-ingress"
  network = google_compute_network.vpc_network.name

  deny {
    protocol = "all"
  }

  direction = "INGRESS"
  priority  = 65534
}

resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
  }

  source_ranges = ["10.0.0.0/16"]  # VPC CIDR
  priority      = 1000
}
```

#### 2. IAM and Service Accounts

```hcl
# Dedicated service account with minimal permissions
resource "google_service_account" "odoo_sa" {
  account_id   = "odoo-cloudrun-sa"
  display_name = "Odoo Cloud Run Service Account"
}

# Grant only necessary roles
resource "google_project_iam_member" "odoo_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.odoo_sa.email}"
}

resource "google_project_iam_member" "odoo_storage" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.odoo_sa.email}"
}

resource "google_project_iam_member" "odoo_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.odoo_sa.email}"
}
```

#### 3. Secrets Management

```hcl
# Store sensitive data in Secret Manager
resource "google_secret_manager_secret" "odoo_master_password" {
  secret_id = "odoo-master-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "odoo_master_password" {
  secret      = google_secret_manager_secret.odoo_master_password.id
  secret_data = var.odoo_master_password  # From terraform.tfvars (gitignored)
}

# Never commit secrets to version control
# Use terraform.tfvars (add to .gitignore):
# odoo_master_password = "super-secure-password-from-password-manager"
```

#### 4. SSL/TLS Configuration

```hcl
# Use Google-managed SSL certificates
resource "google_compute_managed_ssl_certificate" "odoo_cert" {
  name = "odoo-cert"

  managed {
    domains = ["erp.yourcompany.com"]
  }
}

resource "google_compute_target_https_proxy" "odoo_proxy" {
  name             = "odoo-https-proxy"
  url_map          = google_compute_url_map.odoo_lb.id
  ssl_certificates = [google_compute_managed_ssl_certificate.odoo_cert.id]
}
```

#### 5. Database Security

```hcl
settings {
  ip_configuration {
    ipv4_enabled    = false  # No public IP
    private_network = "projects/${var.project_id}/global/networks/${var.network_name}"
    ssl_mode        = "ENCRYPTED_ONLY"  # Enforce SSL

    # No authorized networks (use private IP only)
  }

  # Enable automatic backups
  backup_configuration {
    enabled                        = true
    point_in_time_recovery_enabled = true

    backup_retention_settings {
      retained_backups = 30  # 30 days retention
    }
  }
}
```

### Cost Optimization

#### 1. Right-Sizing Resources

```hcl
# Development environment
container_cpu_limit    = "1000m"  # 1 vCPU
container_memory_limit = "2Gi"
min_instance_count     = 0  # Scale to zero
max_instance_count     = 2

# Production environment
container_cpu_limit    = "2000m"  # 2 vCPU
container_memory_limit = "4Gi"
min_instance_count     = 1  # Always-on
max_instance_count     = 5
```

#### 2. Database Instance Sizing

```hcl
# Development
postgres_tier = "db-f1-micro"  # Lowest cost

# Staging
postgres_tier = "db-custom-1-3840"  # 1 vCPU, 3.75GB RAM

# Production
postgres_tier = "db-custom-2-8192"  # 2 vCPU, 8GB RAM
availability_type = "REGIONAL"  # High availability
```

#### 3. NFS vs Cloud Filestore

```hcl
# Cost-effective: GCE-based NFS (recommended for < 1TB)
create_network_filesystem   = true
network_filesystem_capacity = 100  # GB
network_filesystem_machine  = "e2-medium"

# Premium: Cloud Filestore (recommended for > 1TB or high IOPS)
create_filestore           = true
filestore_tier             = "BASIC_HDD"  # Or BASIC_SSD for performance
filestore_capacity_gb      = 1024
```

**Cost Comparison (us-central1, monthly estimates):**
- GCE NFS (e2-medium + 100GB SSD): ~$50/month
- Cloud Filestore Basic HDD (1TB): ~$200/month
- Cloud Filestore Basic SSD (1TB): ~$800/month

#### 4. Storage Lifecycle Policies

```hcl
resource "google_storage_bucket" "odoo_backups" {
  name     = "odoo-backups-${var.project_id}"
  location = "US"

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 90  # Delete backups older than 90 days
    }
  }

  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
    condition {
      age = 30  # Move to Nearline after 30 days
    }
  }
}
```

### Disaster Recovery

#### 1. Backup Strategy

```hcl
# Automated Cloud SQL backups
backup_configuration {
  enabled                        = true
  point_in_time_recovery_enabled = true  # Enables PITR

  backup_retention_settings {
    retained_backups = 30  # 30 automated backups
  }

  transaction_log_retention_days = 7  # PITR for 7 days
}

# NFS disk snapshots
resource "google_compute_resource_policy" "daily_snapshot" {
  name   = "daily-nfs-snapshot"
  region = var.region

  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1
        start_time    = "04:00"
      }
    }

    retention_policy {
      max_retention_days    = 14
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"
    }

    snapshot_properties {
      labels = {
        snapshot_type = "automated"
      }
      storage_locations = [var.region]
    }
  }
}
```

#### 2. Recovery Procedures

**Database Recovery:**
```bash
# Point-in-time recovery
gcloud sql backups create \
  --instance=${INSTANCE_NAME} \
  --description="Pre-recovery backup"

# Restore to specific timestamp
gcloud sql instances restore-backup ${INSTANCE_NAME} \
  --backup-id=${BACKUP_ID}

# Or create a clone at specific point in time
gcloud sql instances clone ${SOURCE_INSTANCE} ${NEW_INSTANCE} \
  --point-in-time='2026-01-24T10:00:00.000Z'
```

**NFS Recovery:**
```bash
# List snapshots
gcloud compute snapshots list \
  --filter="sourceDisk:data-disk"

# Create disk from snapshot
gcloud compute disks create recovered-nfs-disk \
  --source-snapshot=${SNAPSHOT_NAME} \
  --zone=${ZONE}

# Attach to instance
gcloud compute instances attach-disk ${INSTANCE_NAME} \
  --disk=recovered-nfs-disk \
  --device-name=data-disk \
  --zone=${ZONE}
```

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. Container Fails to Start

**Symptom:** Cloud Run service shows "Container failed to start"

**Diagnosis:**
```bash
# Check logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=odoo" \
  --limit 50

# Check initialization jobs
gcloud logging read "resource.type=cloud_run_job" --limit 50
```

**Common causes:**
- NFS mount not accessible
- Database connection failure
- Missing configuration file
- Insufficient permissions

**Solution:**
```bash
# Verify NFS server is running
gcloud compute instances describe ${NFS_INSTANCE} --zone=${ZONE}

# Test database connectivity from Cloud Shell
gcloud sql connect ${DB_INSTANCE} --user=postgres

# Verify service account permissions
gcloud projects get-iam-policy ${PROJECT_ID} \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${SA_EMAIL}"
```

#### 2. Performance Issues

**Symptom:** Slow page loads, timeouts

**Diagnosis:**
```bash
# Check Cloud Run metrics
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/request_latencies"'

# Check database performance
gcloud sql operations list --instance=${DB_INSTANCE}

# Check active database connections
gcloud sql connect ${DB_INSTANCE} --user=postgres
postgres=> SELECT count(*) FROM pg_stat_activity;
```

**Solutions:**
- Increase worker count in odoo.conf
- Scale up Cloud Run instances (increase max_instance_count)
- Optimize database queries (enable Odoo developer mode, check logs)
- Increase Cloud SQL tier
- Enable Redis caching

#### 3. File Upload Failures

**Symptom:** Cannot upload files, "Permission denied" errors

**Diagnosis:**
```bash
# Check NFS mount in container
gcloud run services describe odoo --region=${REGION}

# Test NFS write from Cloud Shell
# SSH to NFS server
gcloud compute ssh ${NFS_INSTANCE} --zone=${ZONE}

# Check permissions
ls -la /data/nfs/filestore
```

**Solution:**
```bash
# Fix permissions on NFS server
sudo chown -R 101:101 /data/nfs/filestore
sudo chmod -R 775 /data/nfs/filestore

# Restart Cloud Run service
gcloud run services update odoo --region=${REGION}
```

#### 4. Database Connection Errors

**Symptom:** "FATAL: password authentication failed"

**Diagnosis:**
```bash
# Verify database credentials
gcloud secrets versions access latest --secret=odoo-db-password

# Check Cloud SQL instance status
gcloud sql instances describe ${DB_INSTANCE}

# Verify VPC connector
gcloud compute networks vpc-access connectors describe ${CONNECTOR_NAME} \
  --region=${REGION}
```

**Solution:**
```bash
# Reset database password
NEW_PASS=$(openssl rand -base64 32)

# Update in Secret Manager
echo -n "${NEW_PASS}" | gcloud secrets versions add odoo-db-password --data-file=-

# Update in Cloud SQL
gcloud sql users set-password odoo \
  --instance=${DB_INSTANCE} \
  --password=${NEW_PASS}

# Restart Cloud Run
gcloud run services update odoo --region=${REGION}
```

## Conclusion

This implementation provides a production-ready, scalable, and cost-effective solution for deploying Odoo on Google Cloud Platform using Terraform. The modular architecture separates infrastructure concerns from application deployment, enabling reusability and maintainability.

### Key Takeaways

1. **Modularity**: Separate infrastructure (GCP_Services) from application (CloudRunApp) for clean separation of concerns
2. **Security**: Use private networking, Secret Manager, and minimal IAM permissions
3. **Scalability**: Cloud Run auto-scaling with session affinity for stateful sessions
4. **Reliability**: Automated backups, health checks, and auto-healing
5. **Cost-Efficiency**: Scale-to-zero for non-production, right-sized resources
6. **Observability**: Built-in monitoring, logging, and alerting

### Next Steps

1. **Customize for your needs**: Adjust resource sizing, regions, and configuration
2. **Set up CI/CD**: Integrate with Cloud Build for automated deployments
3. **Implement monitoring**: Set up custom dashboards and alerts
4. **Plan for growth**: Consider multi-region deployment and load balancing
5. **Security hardening**: Implement additional security controls based on your requirements
6. **Backup testing**: Regularly test disaster recovery procedures

### Additional Resources

- [Odoo Documentation](https://www.odoo.com/documentation/18.0/)
- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Cloud SQL Best Practices](https://cloud.google.com/sql/docs/postgres/best-practices)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

---

*This implementation is based on the open-source rad-modules project. For the complete source code, visit the repository.*

**Author:** Technical Analysis based on rad-modules Terraform implementation
**Published:** January 2026
**Version:** 1.0 (Odoo 18.0, Terraform 1.5+, Google Provider 5.0+)
