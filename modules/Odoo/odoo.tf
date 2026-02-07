locals {
  # Logic to determine Redis Host (Terraform only handles explicit overrides to avoid cycles)
  # Runtime fallback logic is handled in the odoo-config job script
  redis_host_final = var.redis_host != null ? var.redis_host : ""

  odoo_module = {
    app_name                = "odoo"
    application_version     = var.application_version
    display_name            = "Odoo Community Edition"
    description             = "Odoo ERP System - CRM, e-commerce, billing, accounting, manufacturing, warehouse, project management"
    container_image         = "odoo"

    # image_source    = "build"
    image_source    = "prebuilt"
    enable_image_mirroring  = true

    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "odoo"
      dockerfile_content = null
      build_args = {
        ODOO_VERSION = var.application_version
      }
      artifact_repo_name = null
    }
    container_port  = 8069
    database_type   = "POSTGRES_15"

    container_command = ["/bin/bash", "-c"]
    container_args = [
      <<-EOT
        set -e
        echo "=========================================="
        echo "Starting Odoo Server"
        echo "=========================================="

        if [ ! -f /mnt/odoo.conf ]; then
            echo "ERROR: /mnt/odoo.conf not found"
            exit 1
        fi

        if [ ! -d /mnt/filestore ]; then
            echo "ERROR: /mnt/filestore not found"
            exit 1
        fi

        if ! touch /mnt/filestore/.test 2>/dev/null; then
            echo "ERROR: Cannot write to /mnt/filestore"
            ls -la /mnt/filestore/
            exit 1
        fi
        rm -f /mnt/filestore/.test

        # Set permissive umask so new filestore subdirectories are world-writable
        umask 0000
        chmod -R 777 /mnt/filestore /mnt/sessions 2>/dev/null || true

        echo "All checks passed"
        echo "Starting Odoo server..."
        exec odoo -c /mnt/odoo.conf
      EOT
    ]
    db_name         = "odoo"
    db_user         = "odoo"

    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"

    enable_nfs    = true
    nfs_mount_path = "/mnt"

    gcs_volumes = [
      {
        name          = "odoo-addons"
        mount_path    = "/mnt/extra-addons"
        read_only     = false
        mount_options = ["implicit-dirs", "metadata-cache-ttl-secs=60"]
      }
    ]

    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }

    min_instance_count = 0
    max_instance_count = 3

    environment_variables = {
      SMTP_HOST     = ""
      SMTP_PORT     = "25"
      SMTP_USER     = ""
      SMTP_PASSWORD = ""
      SMTP_SSL      = "false"
      EMAIL_FROM    = "odoo@example.com"
    }

    # Enable PostgreSQL extensions
    enable_postgres_extensions = false
    postgres_extensions = []

    initialization_jobs = [
      # Job 1: NFS Initialization
      {
        name            = "nfs-init"
        description     = "Initialize NFS directories for Odoo"
        image           = "alpine:3.19"
        script_path       = "${path.module}/scripts/odoo/nfs-init.sh"
        mount_nfs         = true
        mount_gcs_volumes = []
        depends_on_jobs   = []
        execute_on_apply  = true
      },

      # Job 2: Database Initialization
      {
        name            = "db-init"
        description     = "Create Odoo Database and User"
        image           = "alpine:3.19"
        script_path       = "${path.module}/scripts/odoo/db-init.sh"
        mount_nfs         = false
        mount_gcs_volumes = []
        depends_on_jobs   = []
        execute_on_apply  = true
      },

      # Job 3: Configuration Generation
      {
        name            = "odoo-config"
        description     = "Generate Odoo configuration file"
        image           = "alpine:3.19"
        env_vars = {
          REDIS_HOST   = local.redis_host_final
          REDIS_PORT   = var.redis_port
          ENABLE_REDIS = tostring(var.enable_redis)
        }
        script_path       = "${path.module}/scripts/odoo/odoo-config.sh"
        mount_nfs         = true
        mount_gcs_volumes = []
        depends_on_jobs   = ["nfs-init"]
        execute_on_apply  = true
      },

      # Job 4: Odoo Initialization
      {
        name            = "odoo-init"
        description     = "Initialize Odoo database"
        image           = null
        script_path       = "${path.module}/scripts/odoo/odoo-init.sh"
        mount_nfs         = true
        mount_gcs_volumes = ["odoo-addons"]
        depends_on_jobs   = ["nfs-init", "db-init", "odoo-config"]
        execute_on_apply  = true
      }
    ]

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

  application_modules = {
    odoo = local.odoo_module
  }

  module_env_vars = {
    HOST    = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip
    DB_HOST = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip
    USER    = local.database_user_full
    DB_PORT = "5432"
    PGPORT  = "5432"
  }

  module_secret_env_vars = {
    ODOO_MASTER_PASS = try(google_secret_manager_secret.odoo_master_pass.secret_id, "")
  }

  module_storage_buckets = [
    {
      name_suffix              = "odoo-addons"
      location                 = var.deployment_region
      storage_class            = "STANDARD"
      force_destroy            = true
      versioning_enabled       = false
      lifecycle_rules          = []
      public_access_prevention = "inherited"
    }
  ]
}

# ==============================================================================
# ODOO SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "odoo_master_pass" {
  length  = 16
  special = false
}

resource "google_secret_manager_secret" "odoo_master_pass" {
  secret_id = "${local.wrapper_prefix}-master-pass"
  replication {
    auto {}
  }
  project = var.existing_project_id

  labels = local.common_labels
}

resource "google_secret_manager_secret_version" "odoo_master_pass" {
  secret      = google_secret_manager_secret.odoo_master_pass.id
  secret_data = random_password.odoo_master_pass.result
}
