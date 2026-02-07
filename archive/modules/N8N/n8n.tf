locals {
  n8n_module = {
    app_name            = "n8n"
    display_name        = "N8N Workflow Automation"
    description         = "n8n Workflow Automation - Workflow automation platform"
    container_image     = "n8nio/n8n"
    application_version = var.application_version

    image_source    = "custom"
    enable_image_mirroring = true
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "n8n"
      dockerfile_content = null
      build_args         = {}
      artifact_repo_name = null
    }
    container_port  = 5678
    database_type   = "POSTGRES_15"
    db_name         = "n8n_db"
    db_user         = "n8n_user"
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"
    gcs_volumes = [{
      name       = "n8n-data"
      mount_path = "/home/node/.n8n"
      read_only  = false
      mount_options = [
        "implicit-dirs",
        "metadata-cache-ttl-secs=60",
        "uid=1000",
        "gid=1000"
      ]
    }]
    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 0
    max_instance_count = 3
    environment_variables = {
      DB_TYPE                          = "postgresdb"
      DB_POSTGRESDB_PORT               = "5432"
      N8N_USER_MANAGEMENT_DISABLED     = "false"
      EXECUTIONS_DATA_SAVE_ON_ERROR    = "all"
      EXECUTIONS_DATA_SAVE_ON_SUCCESS  = "all"
      GENERIC_TIMEZONE                 = "UTC"
      TZ                               = "UTC"
      N8N_DEFAULT_BINARY_DATA_MODE     = "filesystem"
      N8N_EMAIL_MODE                   = "smtp"
      N8N_SMTP_HOST                    = ""
      N8N_SMTP_PORT                    = "587"
      N8N_SMTP_USER                    = ""
      N8N_SMTP_SENDER                  = ""
      N8N_SMTP_SSL                     = "false"
    }
    enable_postgres_extensions = false
    postgres_extensions         = []

    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create N8N Database and User"
        image           = "alpine:3.19"
        script_path       = "${path.module}/scripts/n8n/db-init.sh"
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
      }
    ]

    startup_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 120
      timeout_seconds       = 3
      period_seconds        = 10
      failure_threshold     = 3
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 30
      timeout_seconds       = 5
      period_seconds        = 30
      failure_threshold     = 3
    }
  }

  application_modules = {
    n8n = local.n8n_module
  }

  module_env_vars = local.n8n_env_vars
  module_secret_env_vars = local.n8n_secret_env_vars
  module_storage_buckets = local.n8n_storage_buckets

  n8n_env_vars = {
    N8N_PORT                     = "5678"
    N8N_PROTOCOL                 = "https"
    N8N_DIAGNOSTICS_ENABLED      = "true"
    N8N_METRICS                  = "true"
    DB_TYPE                      = "postgresdb"
    DB_POSTGRESDB_DATABASE       = local.database_name_full
    DB_POSTGRESDB_USER           = local.database_user_full
    DB_POSTGRESDB_HOST           = local.db_internal_ip
    N8N_DEFAULT_BINARY_DATA_MODE = "filesystem"
    WEBHOOK_URL                  = local.predicted_service_url
    N8N_EDITOR_BASE_URL          = local.predicted_service_url
    QUEUE_BULL_REDIS_HOST        = var.redis_host != null ? var.redis_host : (var.enable_redis && local.nfs_server_exists ? local.nfs_internal_ip : "")
    QUEUE_BULL_REDIS_PORT        = var.redis_host != null || (var.enable_redis && local.nfs_server_exists) ? var.redis_port : ""
  }

  n8n_secret_env_vars = {
    N8N_ENCRYPTION_KEY     = try(google_secret_manager_secret.encryption_key.secret_id, "")
    DB_POSTGRESDB_PASSWORD = try(google_secret_manager_secret.db_password[0].secret_id, "")
    N8N_SMTP_PASS          = try(google_secret_manager_secret.n8n_smtp_password.secret_id, "")
  }

  n8n_storage_buckets = [
    {
      name_suffix              = "n8n-data"
      name                     = "${local.wrapper_prefix}-storage" # Preserving legacy naming
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
# N8N SPECIFIC RESOURCES
# ==============================================================================

resource "google_storage_bucket_iam_member" "n8n_cloudrun_access" {
  bucket = google_storage_bucket.buckets["n8n-data"].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${local.cloud_run_sa_email}"
}

resource "random_password" "n8n_smtp_password_dummy" {
  length  = 16
  special = false
}

resource "google_secret_manager_secret" "n8n_smtp_password" {
  secret_id = "${local.wrapper_prefix}-smtp-password"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "n8n_smtp_password" {
  secret      = google_secret_manager_secret.n8n_smtp_password.id
  secret_data = random_password.n8n_smtp_password_dummy.result
}

resource "random_password" "encryption_key" {
  length  = 32
  special = true
}

resource "google_secret_manager_secret" "encryption_key" {
  secret_id = "${local.wrapper_prefix}-encryption-key"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "encryption_key" {
  secret      = google_secret_manager_secret.encryption_key.id
  secret_data = random_password.encryption_key.result
}
