locals {
  openemr_module = {
    app_name            = "openemr"
    application_version = var.application_version
    display_name        = "OpenEMR"
    description         = "This module can be used to deploy OpenEMR"
    container_image     = ""

    image_source           = "custom"
    enable_image_mirroring = false

    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "openemr"
      dockerfile_content = null
      build_args         = {}
      artifact_repo_name = null
    }
    container_port = 80
    database_type  = "MYSQL_8_0"
    db_name        = "openemr"
    db_user        = "openemr"

    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"

    nfs_enabled    = true
    nfs_mount_path = "/var/www/localhost/htdocs/openemr/sites"

    gcs_volumes = []

    container_resources = {
      cpu_limit    = "2000m"


      
      memory_limit = "4Gi"
    }

    min_instance_count = 1
    max_instance_count = 1

    environment_variables = {
      PHP_MEMORY_LIMIT        = "512M"
      PHP_MAX_EXECUTION_TIME  = "60"
      PHP_UPLOAD_MAX_FILESIZE = "64M"
      PHP_POST_MAX_SIZE       = "64M"
      SMTP_HOST               = ""
      SMTP_PORT               = "25"
      SMTP_USER               = ""
      SMTP_PASSWORD           = ""
      SMTP_SSL                = "false"
      EMAIL_FROM              = "openemr@example.com"
    }

    initialization_jobs = [
      # Job 1: NFS Initialization and Backup Restore
      {
        name        = "nfs-init"
        description = "Initialize NFS directories for OpenEMR and restore backup if provided"
        image       = "gcr.io/google.com/cloudsdktool/google-cloud-cli:alpine"
        env_vars = {
          NFS_MOUNT_PATH = "/var/www/localhost/htdocs/openemr/sites"
        }
        script_path       = "${path.module}/scripts/openemr/nfs-init.sh"
        mount_nfs         = true
        mount_gcs_volumes = []
        depends_on_jobs   = []
        execute_on_apply  = true
      },

      # Job 2: Database Initialization
      {
        name        = "db-init"
        description = "Create MySQL Database and User"
        image       = "alpine:3.19"
        script_path       = "${path.module}/scripts/openemr/db-init.sh"
        mount_nfs         = false
        mount_gcs_volumes = []
        depends_on_jobs   = []
        execute_on_apply  = true
      }
    ]

    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 240
      timeout_seconds       = 60
      period_seconds        = 240
      failure_threshold     = 5
    }

    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/interface/login/login.php"
      initial_delay_seconds = 300
      timeout_seconds       = 60
      period_seconds        = 60
      failure_threshold     = 3
    }
  }

  application_modules = {
    openemr = local.openemr_module
  }

  module_env_vars = {
    MYSQL_DATABASE = local.database_name_full
    MYSQL_USER     = local.database_user_full
    MYSQL_HOST     = local.db_internal_ip
    # MYSQL_HOST     = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip
    MYSQL_PORT      = "3306"
    OE_USER         = "admin"
    MANUAL_SETUP    = "no"
    BACKUP_FILEID   = local.final_backup_uri != null ? local.final_backup_uri : ""
    SWARM_MODE      = "no"
    REDIS_SERVER    = var.enable_redis ? (var.redis_host != "" ? var.redis_host : (local.nfs_server_exists ? local.nfs_internal_ip : "")) : ""
    REDIS_PORT      = var.enable_redis ? (var.redis_port != "" ? var.redis_port : "6379") : ""
    MYSQL_ROOT_PASS = "BLANK"
  }

  module_secret_env_vars = {

    OE_PASS    = try(google_secret_manager_secret.openemr_admin_password[0].secret_id, "")
    MYSQL_PASS = try(google_secret_manager_secret.db_password[0].secret_id, "")
  }

  module_storage_buckets = []
}

# ==============================================================================
# OPENEMR SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "openemr_admin_password" {
  count   = 1
  length  = 20
  special = false
}

resource "google_secret_manager_secret" "openemr_admin_password" {
  count     = 1
  secret_id = "${local.wrapper_prefix}-admin-password"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "openemr_admin_password" {
  count       = 1
  secret      = google_secret_manager_secret.openemr_admin_password[0].id
  secret_data = random_password.openemr_admin_password[0].result
}
