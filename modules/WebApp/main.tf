locals {
  presets = {
    custom = {
      app_name      = "myapp"
      db_type       = "POSTGRES"
      db_name       = "myapp"
      db_user       = "myapp"
      image_source  = "prebuilt"
      image         = "nginx:latest"
      port          = 80
      resources     = { cpu_limit = "1000m", memory_limit = "512Mi" }
      nfs           = false
      nfs_path      = "/mnt"
      gcs           = []
      env_vars      = {}
      sql_vol       = false
      startup_probe = { enabled = true, type = "TCP", path = "/" }
      liveness_probe = { enabled = true, type = "HTTP", path = "/" }
    }
    cyclos = {
      app_name      = "cyclos"
      db_type       = "POSTGRES"
      db_name       = "cyclos_db"
      db_user       = "cyclos_user"
      image_source  = "custom"
      image         = null
      port          = 8080
      resources     = { cpu_limit = "2000m", memory_limit = "4Gi" }
      nfs           = false
      nfs_path      = "/mnt"
      gcs           = []
      env_vars      = {}
      sql_vol       = false
      startup_probe = { enabled = true, type = "TCP", initial_delay_seconds = 60, timeout_seconds = 30, period_seconds = 60, failure_threshold = 3 }
      liveness_probe = { enabled = true, type = "HTTP", path = "/api", initial_delay_seconds = 60, timeout_seconds = 5, period_seconds = 60, failure_threshold = 3 }
    }
    django = {
      app_name      = "django"
      db_type       = "POSTGRES"
      db_name       = "django_db"
      db_user       = "django_user"
      image_source  = "custom"
      image         = null
      port          = 8080
      resources     = { cpu_limit = "1000m", memory_limit = "512Mi" }
      nfs           = false
      nfs_path      = "/mnt"
      gcs           = []
      env_vars      = {}
      sql_vol       = true
      startup_probe = { enabled = true, type = "TCP", path = "/" }
      liveness_probe = { enabled = true, type = "HTTP", path = "/" }
    }
    moodle = {
      app_name      = "moodle"
      db_type       = "POSTGRES"
      db_name       = "moodle_db"
      db_user       = "moodle_user"
      image_source  = "custom"
      image         = null
      port          = 80
      resources     = { cpu_limit = "1000m", memory_limit = "2Gi" }
      nfs           = true
      nfs_path      = "/mnt"
      gcs           = []
      env_vars      = {}
      sql_vol       = true
      startup_probe = { enabled = true, type = "TCP", initial_delay_seconds = 120, timeout_seconds = 60, period_seconds = 120, failure_threshold = 1 }
      liveness_probe = { enabled = true, type = "HTTP", path = "/", initial_delay_seconds = 120, timeout_seconds = 5, period_seconds = 120, failure_threshold = 3 }
    }
    n8n = {
      app_name      = "n8n"
      db_type       = "POSTGRES"
      db_name       = "n8n_db"
      db_user       = "n8n_user"
      image_source  = "prebuilt"
      image         = "n8nio/n8n:latest"
      port          = 5678
      resources     = { cpu_limit = "1000m", memory_limit = "2Gi" }
      nfs           = false
      nfs_path      = "/mnt"
      gcs           = []
      env_vars      = {
        N8N_PORT = "5678", N8N_PROTOCOL = "https", N8N_DIAGNOSTICS_ENABLED = "true", N8N_METRICS = "true",
        DB_TYPE = "postgresdb", N8N_DEFAULT_BINARY_DATA_MODE = "filesystem", N8N_S3_ENDPOINT = "https://storage.googleapis.com"
      }
      sql_vol       = true
      startup_probe = { enabled = true, type = "HTTP", path = "/", initial_delay_seconds = 10, timeout_seconds = 3, period_seconds = 10, failure_threshold = 3 }
      liveness_probe = { enabled = true, type = "HTTP", path = "/", initial_delay_seconds = 30, timeout_seconds = 5, period_seconds = 30, failure_threshold = 3 }
    }
    odoo = {
      app_name      = "odoo"
      db_type       = "POSTGRES"
      db_name       = "odoo_db"
      db_user       = "odoo_user"
      image_source  = "custom"
      image         = null
      port          = 8069
      resources     = { cpu_limit = "1000m", memory_limit = "2Gi" }
      nfs           = true
      nfs_path      = "/mnt"
      gcs           = [{
        name = "gcs-data-volume", bucket_name = null, mount_path = "/extra-addons", readonly = false,
        mount_options = ["uid=103", "gid=101", "file-mode=644", "dir-mode=755", "implicit-dirs", "stat-cache-ttl=60s", "type-cache-ttl=60s"]
      }]
      env_vars      = {}
      sql_vol       = false
      startup_probe = { enabled = true, type = "TCP", initial_delay_seconds = 180, timeout_seconds = 60, period_seconds = 120, failure_threshold = 3 }
      liveness_probe = { enabled = true, type = "HTTP", path = "/web/health", initial_delay_seconds = 120, timeout_seconds = 60, period_seconds = 120, failure_threshold = 3 }
    }
    openemr = {
      app_name      = "openemr"
      db_type       = "MYSQL_8_0"
      db_name       = "openemr_db"
      db_user       = "openemr_user"
      image_source  = "prebuilt"
      image         = "openemr/openemr:7.0.3"
      port          = 80
      resources     = { cpu_limit = "2000m", memory_limit = "4Gi" }
      nfs           = true
      nfs_path      = "/var/www/localhost/htdocs/openemr/sites"
      gcs           = []
      env_vars      = { MYSQL_PORT = "3306", OE_USER = "admin", OE_PASS = "admin", MANUAL_SETUP = "no" }
      sql_vol       = true
      startup_probe = { enabled = true, type = "TCP", initial_delay_seconds = 240, timeout_seconds = 60, period_seconds = 240, failure_threshold = 5 }
      liveness_probe = { enabled = true, type = "HTTP", path = "/interface/login/login.php", initial_delay_seconds = 300, timeout_seconds = 60, period_seconds = 60, failure_threshold = 3 }
    }
    wordpress = {
      app_name      = "wordpress"
      db_type       = "MYSQL_8_0"
      db_name       = "wordpress_db"
      db_user       = "wordpress_user"
      image_source  = "custom"
      image         = null
      port          = 80
      resources     = { cpu_limit = "1000m", memory_limit = "2Gi" }
      nfs           = false
      nfs_path      = "/mnt"
      gcs           = [{
        name = "gcs-data-volume", bucket_name = null, mount_path = "/var/www/html/wp-content", readonly = false,
        mount_options = ["implicit-dirs", "stat-cache-ttl=60s", "type-cache-ttl=60s"]
      }]
      env_vars      = { WORDPRESS_DEBUG = "false" }
      sql_vol       = true
      startup_probe = { enabled = true, type = "TCP", initial_delay_seconds = 240, timeout_seconds = 60, period_seconds = 240, failure_threshold = 1 }
      liveness_probe = { enabled = true, type = "HTTP", path = "/wp-admin/install.php", initial_delay_seconds = 300, timeout_seconds = 60, period_seconds = 60, failure_threshold = 3 }
    }
  }

  selected = local.presets[var.deploy_app_preset]
}

module "webapp" {
  source = "./modules/WebApp"

  existing_project_id  = var.existing_project_id
  deployment_id        = var.deployment_id
  tenant_deployment_id = var.tenant_deployment_id
  deployment_region    = var.deployment_region

  application_name          = var.application_name != null ? var.application_name : local.selected.app_name
  application_database_name = local.selected.db_name
  application_database_user = local.selected.db_user
  database_type             = local.selected.db_type

  container_image_source = local.selected.image_source
  container_image        = local.selected.image
  container_port         = local.selected.port
  container_resources    = local.selected.resources

  network_name             = var.network_name
  cloudrun_service_account = var.cloudrun_service_account

  nfs_enabled            = local.selected.nfs
  nfs_mount_path         = local.selected.nfs_path
  gcs_volumes            = local.selected.gcs
  enable_cloudsql_volume = local.selected.sql_vol

  startup_probe_config = local.selected.startup_probe
  health_check_config  = local.selected.liveness_probe

  environment_variables = merge(local.selected.env_vars, var.environment_variables)
  
  # Note: Some complex post-deployment logic (Django CSRF, N8N S3, OpenEMR Root Pass) from the dedicated presets
  # cannot be fully replicated in this simple switch without making the root module extremely complex or
  # creating conditional resources here. This is a "best effort" mapping to the underlying WebApp module.
  # For full feature parity (e.g. N8N S3 keys), users should still use the specific preset directory.
}
