# Copyright 2024 (c) Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

resource "random_id" "wrapper_deployment" {
  byte_length = 4
}

locals {
  # Calculate prefix locally to avoid circular dependency with Core outputs for SA creation
  # Logic matches Core: app + name + tenant + random
  # Use user provided name or preset default
  _app_name = coalesce(var.application_name, lookup(local.presets[var.deploy_app_preset], "app_name", null), "webapp")
  wrapper_prefix = "app${local._app_name}${var.tenant_deployment_id}${random_id.wrapper_deployment.hex}"

  # Preset Configurations
  presets = {
    custom = {}

    cyclos = {
      app_name       = "cyclos"
      db_name        = "cyclos_db"
      db_user        = "cyclos_user"
      db_type        = "POSTGRES"
      image_source   = "custom"
      port           = 8080
      resources      = { cpu_limit = "2000m", memory_limit = "4Gi" }
      startup_probe  = { enabled = true, type = "TCP", path = "/", initial_delay_seconds = 60, timeout_seconds = 30, period_seconds = 60, failure_threshold = 3 }
      liveness_probe = { enabled = true, type = "HTTP", path = "/api", initial_delay_seconds = 60, timeout_seconds = 5, period_seconds = 60, failure_threshold = 3 }
    }

    django = {
      app_name       = "django"
      db_name        = "django_db"
      db_user        = "django_user"
      db_type        = "POSTGRES"
      image_source   = "custom"
      cloudsql_vol   = true
      cloudsql_path  = "/cloudsql"
    }

    moodle = {
      app_name       = "moodle"
      db_name        = "moodle_db"
      db_user        = "moodle_user"
      db_type        = "POSTGRES"
      image_source   = "custom"
      resources      = { cpu_limit = "1000m", memory_limit = "2Gi" }
      nfs_enabled    = true
      nfs_path       = "/mnt"
      cloudsql_vol   = true
      startup_probe  = { enabled = true, type = "TCP", path = "/", initial_delay_seconds = 120, timeout_seconds = 60, period_seconds = 120, failure_threshold = 1 }
      liveness_probe = { enabled = true, type = "HTTP", path = "/", initial_delay_seconds = 120, timeout_seconds = 5, period_seconds = 120, failure_threshold = 3 }
    }

    n8n = {
      app_name       = "n8n"
      db_name        = "n8n_db"
      db_user        = "n8n_user"
      db_type        = "POSTGRES"
      image_source   = "prebuilt"
      image          = "n8nio/n8n:latest"
      resources      = { cpu_limit = "1000m", memory_limit = "2Gi" }
      cloudsql_vol   = true
      cloudsql_path  = "/cloudsql"
      startup_probe  = { enabled = true, type = "HTTP", path = "/", initial_delay_seconds = 10, timeout_seconds = 3, period_seconds = 10, failure_threshold = 3 }
      liveness_probe = { enabled = true, type = "HTTP", path = "/", initial_delay_seconds = 30, timeout_seconds = 5, period_seconds = 30, failure_threshold = 3 }
    }

    odoo = {
      app_name       = "odoo"
      db_name        = "odoo_db"
      db_user        = "odoo_user"
      db_type        = "POSTGRES"
      image_source   = "custom"
      resources      = { cpu_limit = "1000m", memory_limit = "2Gi" }
      nfs_enabled    = true
      nfs_path       = "/mnt"
      startup_probe  = { enabled = true, type = "TCP", path = "/", initial_delay_seconds = 180, timeout_seconds = 60, period_seconds = 120, failure_threshold = 3 }
      liveness_probe = { enabled = true, type = "HTTP", path = "/web/health", initial_delay_seconds = 120, timeout_seconds = 60, period_seconds = 120, failure_threshold = 3 }
    }

    openemr = {
      app_name       = "openemr"
      db_name        = "openemr_db"
      db_user        = "openemr_user"
      db_type        = "MYSQL_8_0"
      image_source   = "prebuilt"
      image          = "openemr/openemr:7.0.3"
      resources      = { cpu_limit = "2000m", memory_limit = "4Gi" }
      nfs_enabled    = true
      nfs_path       = "/var/www/localhost/htdocs/openemr/sites"
      cloudsql_vol   = true
      startup_probe  = { enabled = true, type = "TCP", path = "/", initial_delay_seconds = 240, timeout_seconds = 60, period_seconds = 240, failure_threshold = 5 }
      liveness_probe = { enabled = true, type = "HTTP", path = "/interface/login/login.php", initial_delay_seconds = 300, timeout_seconds = 60, period_seconds = 60, failure_threshold = 3 }
    }

    wordpress = {
      app_name       = "wordpress"
      db_name        = "wordpress_db"
      db_user        = "wordpress_user"
      db_type        = "MYSQL_8_0"
      image_source   = "custom"
      resources      = { cpu_limit = "1000m", memory_limit = "2Gi" }
      cloudsql_vol   = true
      gcs_volumes    = [
        {
          name          = "gcs-data-volume"
          bucket_name   = null
          mount_path    = "/var/www/html/wp-content"
          readonly      = false
          mount_options = ["implicit-dirs", "stat-cache-ttl=60s", "type-cache-ttl=60s"]
        }
      ]
      startup_probe  = { enabled = true, type = "TCP", path = "/", initial_delay_seconds = 240, timeout_seconds = 60, period_seconds = 240, failure_threshold = 1 }
      liveness_probe = { enabled = true, type = "HTTP", path = "/wp-admin/install.php", initial_delay_seconds = 300, timeout_seconds = 60, period_seconds = 60, failure_threshold = 3 }
    }
  }

  preset = local.presets[var.deploy_app_preset]

  # Dynamic Environment Variables
  preset_env_vars = merge(
    var.deploy_app_preset == "n8n" ? {
      N8N_PORT                 = "5678"
      N8N_PROTOCOL             = "https"
      N8N_DIAGNOSTICS_ENABLED  = "true"
      N8N_METRICS              = "true"
      DB_TYPE                  = "postgresdb"
      DB_POSTGRESDB_DATABASE   = module.core.database_name
      DB_POSTGRESDB_USER       = module.core.database_user
      DB_POSTGRESDB_HOST       = module.core.database_host
      N8N_DEFAULT_BINARY_DATA_MODE = "filesystem"
      N8N_S3_ENDPOINT              = "https://storage.googleapis.com"
      N8N_S3_BUCKET_NAME           = try(google_storage_bucket.n8n_storage[0].name, "")
      N8N_S3_REGION                = var.deployment_region
    } : {},
    var.deploy_app_preset == "wordpress" ? {
      WORDPRESS_DB_NAME = module.core.database_name
      WORDPRESS_DB_USER = module.core.database_user
      WORDPRESS_DB_HOST = module.core.database_host
      WORDPRESS_DEBUG   = "false"
    } : {},
    var.deploy_app_preset == "openemr" ? {
      MYSQL_DATABASE = module.core.database_name
      MYSQL_USER     = module.core.database_user
      MYSQL_HOST     = module.core.database_host
      MYSQL_PORT     = "3306"
      OE_USER        = "admin"
      OE_PASS        = "admin"
      MANUAL_SETUP   = "no"
    } : {}
  )

  preset_secret_env_vars = merge(
    var.deploy_app_preset == "n8n" ? {
      N8N_S3_ACCESS_KEY      = try(google_secret_manager_secret.storage_access_key[0].secret_id, "")
      N8N_S3_ACCESS_SECRET   = try(google_secret_manager_secret.storage_secret_key[0].secret_id, "")
      N8N_ENCRYPTION_KEY     = try(google_secret_manager_secret.encryption_key[0].secret_id, "")
      DB_POSTGRESDB_PASSWORD = module.core.database_password_secret
    } : {},
    var.deploy_app_preset == "wordpress" ? {
      WORDPRESS_DB_PASSWORD = module.core.database_password_secret
    } : {},
    var.deploy_app_preset == "openemr" ? {
      MYSQL_ROOT_PASS = "${module.core.database_instance_name}-root-password"
    } : {}
  )
}

# ==============================================================================
# N8N SPECIFIC RESOURCES
# ==============================================================================
resource "google_service_account" "n8n_sa" {
  count        = var.deploy_app_preset == "n8n" ? 1 : 0
  account_id   = "${local.wrapper_prefix}-sa"
  display_name = "N8N Service Account"
  project      = var.existing_project_id
}

resource "google_storage_bucket" "n8n_storage" {
  count         = var.deploy_app_preset == "n8n" ? 1 : 0
  name          = "${local.wrapper_prefix}-storage"
  location      = var.deployment_region
  force_destroy = true
  project       = var.existing_project_id
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "storage_admin" {
  count  = var.deploy_app_preset == "n8n" ? 1 : 0
  bucket = google_storage_bucket.n8n_storage[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.n8n_sa[0].email}"
}

resource "google_storage_hmac_key" "n8n_key" {
  count                 = var.deploy_app_preset == "n8n" ? 1 : 0
  service_account_email = google_service_account.n8n_sa[0].email
  project               = var.existing_project_id
}

resource "google_secret_manager_secret" "storage_access_key" {
  count     = var.deploy_app_preset == "n8n" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-access-key"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "storage_access_key" {
  count       = var.deploy_app_preset == "n8n" ? 1 : 0
  secret      = google_secret_manager_secret.storage_access_key[0].id
  secret_data = google_storage_hmac_key.n8n_key[0].access_id
}

resource "google_secret_manager_secret" "storage_secret_key" {
  count     = var.deploy_app_preset == "n8n" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-secret-key"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "storage_secret_key" {
  count       = var.deploy_app_preset == "n8n" ? 1 : 0
  secret      = google_secret_manager_secret.storage_secret_key[0].id
  secret_data = google_storage_hmac_key.n8n_key[0].secret
}

resource "random_password" "encryption_key" {
  count   = var.deploy_app_preset == "n8n" ? 1 : 0
  length  = 32
  special = true
}

resource "google_secret_manager_secret" "encryption_key" {
  count     = var.deploy_app_preset == "n8n" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-encryption-key"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "encryption_key" {
  count       = var.deploy_app_preset == "n8n" ? 1 : 0
  secret      = google_secret_manager_secret.encryption_key[0].id
  secret_data = random_password.encryption_key[0].result
}

# ==============================================================================
# CORE MODULE
# ==============================================================================
module "core" {
  source = "./presets/Core"

  # Application Config (User Input > Preset > Default)
  application_name          = coalesce(var.application_name, lookup(local.preset, "app_name", null), "webapp")
  application_database_name = coalesce(var.application_database_name, lookup(local.preset, "db_name", null), "webapp_db")
  application_database_user = coalesce(var.application_database_user, lookup(local.preset, "db_user", null), "webapp_user")
  database_type             = coalesce(var.database_type, lookup(local.preset, "db_type", null), "POSTGRES")

  # Container Config
  container_image_source = coalesce(var.container_image_source, lookup(local.preset, "image_source", null), "prebuilt")
  container_image        = var.container_image != null ? var.container_image : lookup(local.preset, "image", null)
  container_port         = coalesce(var.container_port, lookup(local.preset, "port", null), 8080)
  container_resources    = coalesce(var.container_resources, lookup(local.preset, "resources", null), {
    cpu_limit    = "1000m"
    memory_limit = "512Mi"
  })

  # Probes
  startup_probe_config = coalesce(var.startup_probe_config, lookup(local.preset, "startup_probe", null), {
    enabled               = true
    type                  = "TCP"
    path                  = "/"
    initial_delay_seconds = 0
    timeout_seconds       = 240
    period_seconds        = 240
    failure_threshold     = 1
  })

  health_check_config = coalesce(var.health_check_config, lookup(local.preset, "liveness_probe", null), {
    enabled               = false
    type                  = "HTTP"
    path                  = "/"
  })

  # Storage & Network
  nfs_enabled                = coalesce(var.nfs_enabled, lookup(local.preset, "nfs_enabled", null), true)
  nfs_mount_path             = coalesce(var.nfs_mount_path, lookup(local.preset, "nfs_path", null), "/mnt")
  enable_cloudsql_volume     = coalesce(var.enable_cloudsql_volume, lookup(local.preset, "cloudsql_vol", null), false)
  cloudsql_volume_mount_path = coalesce(var.cloudsql_volume_mount_path, lookup(local.preset, "cloudsql_path", null), "/cloudsql")

  # Inject N8N Service Account if active
  cloudrun_service_account = var.deploy_app_preset == "n8n" ? google_service_account.n8n_sa[0].email : var.cloudrun_service_account

  # Merge Environment Variables
  environment_variables        = merge(var.environment_variables, local.preset_env_vars)
  secret_environment_variables = merge(var.secret_environment_variables, local.preset_secret_env_vars)

  # GCS Volumes (Merge or Override?)
  # Logic: If preset has GCS volumes, use them unless user overrides.
  # But user override via `gcs_volumes` list is tricky.
  # If user passes `[]`, they might mean "default".
  # If they pass `[...]`, they mean "use this".
  # Safe bet: If user provided non-empty list, use it. Else use preset default.
  gcs_volumes = length(var.gcs_volumes) > 0 ? var.gcs_volumes : lookup(local.preset, "gcs_volumes", [])

  # Pass-through all other variables
  module_description         = var.module_description
  module_dependency          = var.module_dependency
  module_services            = var.module_services
  credit_cost                = var.credit_cost
  require_credit_purchases   = var.require_credit_purchases
  enable_purge               = var.enable_purge
  public_access              = var.public_access
  deployment_id              = var.deployment_id != null ? var.deployment_id : random_id.wrapper_deployment.hex # Sync deployment IDs
  resource_creator_identity  = var.resource_creator_identity
  resource_labels            = var.resource_labels
  deployment_regions         = var.deployment_regions
  configure_environment      = var.configure_environment
  create_cloud_storage       = var.deploy_app_preset == "n8n" ? false : var.create_cloud_storage # N8N handles own storage
  configure_monitoring       = var.configure_monitoring
  network_name               = var.network_name
  cloudbuild_service_account = var.cloudbuild_service_account
  cloudsql_service_account   = var.cloudsql_service_account
  execution_environment      = var.execution_environment
  secret_propagation_delay   = var.secret_propagation_delay
  service_annotations        = var.service_annotations
  service_labels             = var.service_labels
  agent_service_account      = var.agent_service_account
  existing_project_id        = var.existing_project_id
  tenant_deployment_id       = var.tenant_deployment_id
  deployment_region          = var.deployment_region
  application_display_name   = var.application_display_name
  application_version        = var.application_version
  application_description    = var.application_description
  container_protocol         = var.container_protocol
  container_build_config     = var.container_build_config
  github_repository_url      = var.github_repository_url
  github_token_secret_name   = var.github_token_secret_name
  github_app_installation_id = var.github_app_installation_id
  enable_cicd_trigger        = var.enable_cicd_trigger
  cicd_trigger_config        = var.cicd_trigger_config
  database_password_length   = var.database_password_length
  database_flags             = var.database_flags
  container_concurrency      = var.container_concurrency
  timeout_seconds            = var.timeout_seconds
  min_instance_count         = var.min_instance_count
  max_instance_count         = var.max_instance_count
  max_instance_request_concurrency = var.max_instance_request_concurrency
  storage_buckets            = var.storage_buckets
  custom_volumes             = var.custom_volumes
  trusted_users              = var.trusted_users
  uptime_check_config        = var.uptime_check_config
  alert_policies             = var.alert_policies
  initialization_jobs        = var.initialization_jobs
  enable_postgres_extensions = var.enable_postgres_extensions
  postgres_extensions        = var.postgres_extensions
  enable_backup_import       = var.enable_backup_import
  backup_source              = var.backup_source
  backup_uri                 = var.backup_uri
  backup_format              = var.backup_format
  enable_gdrive_backup_import = var.enable_gdrive_backup_import
  gdrive_backup_file_id      = var.gdrive_backup_file_id
  gdrive_backup_format       = var.gdrive_backup_format
  enable_gcs_backup_import   = var.enable_gcs_backup_import
  gcs_backup_uri             = var.gcs_backup_uri
  gcs_backup_format          = var.gcs_backup_format
  enable_mysql_plugins       = var.enable_mysql_plugins
  mysql_plugins              = var.mysql_plugins
  enable_custom_sql_scripts  = var.enable_custom_sql_scripts
  custom_sql_scripts_bucket  = var.custom_sql_scripts_bucket
  custom_sql_scripts_path    = var.custom_sql_scripts_path
  custom_sql_scripts_use_root = var.custom_sql_scripts_use_root
  vpc_egress_setting         = var.vpc_egress_setting
  network_tags               = var.network_tags
  ingress_settings           = var.ingress_settings
}

# Django Post-Deployment Update (CSRF Origin)
resource "null_resource" "update_csrf_origin" {
  count = var.deploy_app_preset == "django" ? 1 : 0

  triggers = {
    service_id = module.core.service_name
  }

  provisioner "local-exec" {
    command = <<EOF
      IMPERSONATE_FLAG=""
      if [ -n "${var.impersonation_service_account}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${var.impersonation_service_account}"
      fi

      SERVICE_NAME="${module.core.service_name}"
      REGION="${var.deployment_region}"
      PROJECT="${var.existing_project_id}"

      if [ -n "$SERVICE_NAME" ]; then
        URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --project $PROJECT --format 'value(uri)')
        gcloud run services update $SERVICE_NAME \
          --region $REGION \
          --project $PROJECT \
          --set-env-vars CLOUDRUN_SERVICE_URLS=$URL \
          $IMPERSONATE_FLAG
      fi
    EOF
  }
}
