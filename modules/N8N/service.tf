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

resource "google_cloud_run_v2_service" "dev_app_service" {
  count               = var.configure_development_environment && local.sql_server_exists ? 1 : 0
  project             = local.project.project_id
  name                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
  location            = local.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account       = local.cloud_run_sa_email
    session_affinity      = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout               = "300s"

    labels = {
      app = var.application_name,
      env = "dev"
    }

    containers {
      image   = "n8nio/n8n:${var.application_version}"
      command = ["/bin/sh"]
      args    = ["-c", "sleep 5; n8n start"]
      
      ports {
        container_port = 5678
      }

      resources {
        startup_cpu_boost = true
        cpu_idle          = false
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }
      }

      # Startup probe - gives n8n time to initialize
      startup_probe {
        http_get {
          path = "/healthz"
          port = 5678
        }
        initial_delay_seconds = 10
        timeout_seconds       = 3
        period_seconds        = 10
        failure_threshold     = 3
      }

      # Liveness probe - checks if n8n is running
      liveness_probe {
        http_get {
          path = "/healthz"
          port = 5678
        }
        initial_delay_seconds = 30
        timeout_seconds       = 5
        period_seconds        = 30
        failure_threshold     = 3
      }

      # n8n Configuration
      env {
        name  = "N8N_PORT"
        value = "5678"
      }
      env {
        name  = "N8N_PROTOCOL"
        value = "https"
      }
      env {
        name  = "N8N_DIAGNOSTICS_ENABLED"
        value = "true"
      }
      env {
        name  = "N8N_METRICS"
        value = "true"
      }

      # Database Configuration
      env {
        name  = "DB_TYPE"
        value = "postgresdb"
      }
      env {
        name  = "DB_POSTGRESDB_DATABASE"
        value = google_sql_database.dev_db.name
      }
      env {
        name  = "DB_POSTGRESDB_USER"
        value = google_sql_user.dev_user.name
      }
      env {
        name  = "DB_POSTGRESDB_HOST"
        value = "/cloudsql/${local.project.project_id}:${local.region}:${local.db_instance_name}"
      }
      env {
        name  = "DB_POSTGRESDB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_POSTGRESDB_SCHEMA"
        value = "public"
      }
      env {
        name  = "GENERIC_TIMEZONE"
        value = "UTC"
      }
      env {
        name  = "QUEUE_HEALTH_CHECK_ACTIVE"
        value = "true"
      }

      # Storage Configuration - Filesystem mode with GCS FUSE
      env {
        name  = "N8N_AVAILABLE_BINARY_DATA_MODES"
        value = "filesystem"
      }
      env {
        name  = "N8N_DEFAULT_BINARY_DATA_MODE"
        value = "filesystem"
      }
      env {
        name  = "N8N_BINARY_DATA_STORAGE_PATH"
        value = "/files"
      }

      # Secrets
      env {
        name = "DB_POSTGRESDB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.dev_db_password.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "N8N_ENCRYPTION_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.dev_encryption_key.secret_id
            version = "latest"
          }
        }
      }

      # Volume Mounts
      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
      
      volume_mounts {
        name       = "gcs-data"
        mount_path = "/files"
      }
    }

    vpc_access {
      network_interfaces {
        network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
        subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
      }
    }

    scaling {
      min_instance_count = 1
      max_instance_count = 1
    }

    # Volume Definitions
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = ["${local.project.project_id}:${local.region}:${local.db_instance_name}"]
      }
    }

    volumes {
      name = "gcs-data"
      gcs {
        bucket    = google_storage_bucket.dev_storage.name
        read_only = false
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag     = "latest"
    percent = 100
  }

  depends_on = [
    google_sql_database.dev_db,
    google_sql_user.dev_user,
    google_secret_manager_secret_version.dev_db_password,
    google_secret_manager_secret_version.dev_encryption_key,
    google_project_iam_member.cloudsql_client,
    google_storage_bucket.dev_storage,
    google_project_iam_member.storage_admin
  ]
}

resource "google_cloud_run_service_iam_binding" "dev" {
  count = var.configure_development_environment && local.sql_server_exists ? 1 : 0

  project  = local.project.project_id
  location = local.region
  service  = google_cloud_run_v2_service.dev_app_service[0].name
  role     = "roles/run.invoker"
  members = [
    "allUsers"
  ]
}

resource "google_cloud_run_v2_service" "qa_app_service" {
  count               = var.configure_nonproduction_environment && local.sql_server_exists ? 1 : 0
  project             = local.project.project_id
  name                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
  location            = local.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account       = local.cloud_run_sa_email
    session_affinity      = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout               = "300s"

    labels = {
      app = var.application_name,
      env = "qa"
    }

    containers {
      image   = "n8nio/n8n:${var.application_version}"
      command = ["/bin/sh"]
      args    = ["-c", "sleep 5; n8n start"]
      
      ports {
        container_port = 5678
      }

      resources {
        startup_cpu_boost = true
        cpu_idle          = false
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }
      }

      # Startup probe
      startup_probe {
        http_get {
          path = "/healthz"
          port = 5678
        }
        initial_delay_seconds = 10
        timeout_seconds       = 3
        period_seconds        = 10
        failure_threshold     = 3
      }

      # Liveness probe
      liveness_probe {
        http_get {
          path = "/healthz"
          port = 5678
        }
        initial_delay_seconds = 30
        timeout_seconds       = 5
        period_seconds        = 30
        failure_threshold     = 3
      }

      # n8n Configuration
      env {
        name  = "N8N_PORT"
        value = "5678"
      }
      env {
        name  = "N8N_PROTOCOL"
        value = "https"
      }
      env {
        name  = "N8N_DIAGNOSTICS_ENABLED"
        value = "true"
      }
      env {
        name  = "N8N_METRICS"
        value = "true"
      }

      # Database Configuration
      env {
        name  = "DB_TYPE"
        value = "postgresdb"
      }
      env {
        name  = "DB_POSTGRESDB_DATABASE"
        value = google_sql_database.qa_db.name
      }
      env {
        name  = "DB_POSTGRESDB_USER"
        value = google_sql_user.qa_user.name
      }
      env {
        name  = "DB_POSTGRESDB_HOST"
        value = "/cloudsql/${local.project.project_id}:${local.region}:${local.db_instance_name}"
      }
      env {
        name  = "DB_POSTGRESDB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_POSTGRESDB_SCHEMA"
        value = "public"
      }
      env {
        name  = "GENERIC_TIMEZONE"
        value = "UTC"
      }
      env {
        name  = "QUEUE_HEALTH_CHECK_ACTIVE"
        value = "true"
      }
      env {
        name  = "N8N_RUNNERS_ENABLED"
        value = "true"
      }
      env {
        name  = "N8N_BLOCK_ENV_ACCESS_IN_NODE"
        value = "false"
      }
      env {
        name  = "N8N_GIT_NODE_DISABLE_BARE_REPOS"
        value = "true"
      }

      # Storage Configuration - Filesystem mode with GCS FUSE
      env {
        name  = "N8N_AVAILABLE_BINARY_DATA_MODES"
        value = "filesystem"
      }
      env {
        name  = "N8N_DEFAULT_BINARY_DATA_MODE"
        value = "filesystem"
      }
      env {
        name  = "N8N_BINARY_DATA_STORAGE_PATH"
        value = "/files"
      }

      # Secrets
      env {
        name = "DB_POSTGRESDB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.qa_db_password.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "N8N_ENCRYPTION_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.qa_encryption_key.secret_id
            version = "latest"
          }
        }
      }

      # Volume Mounts
      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
      
      volume_mounts {
        name       = "gcs-data"
        mount_path = "/files"
      }
    }

    vpc_access {
      network_interfaces {
        network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
        subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
      }
    }

    scaling {
      min_instance_count = 1
      max_instance_count = 1
    }

    # Volume Definitions
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = ["${local.project.project_id}:${local.region}:${local.db_instance_name}"]
      }
    }

    volumes {
      name = "gcs-data"
      gcs {
        bucket    = google_storage_bucket.qa_storage.name
        read_only = false
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag     = "latest"
    percent = 100
  }

  depends_on = [
    google_sql_database.qa_db,
    google_sql_user.qa_user,
    google_secret_manager_secret_version.qa_db_password,
    google_secret_manager_secret_version.qa_encryption_key,
    google_project_iam_member.cloudsql_client,
    google_storage_bucket.qa_storage,
    google_project_iam_member.storage_admin
  ]
}

resource "google_cloud_run_service_iam_binding" "qa" {
  count = var.configure_nonproduction_environment && local.sql_server_exists ? 1 : 0

  project  = local.project.project_id
  location = local.region
  service  = google_cloud_run_v2_service.qa_app_service[0].name
  role     = "roles/run.invoker"
  members = [
    "allUsers"
  ]
}

resource "google_cloud_run_v2_service" "prod_app_service" {
  count               = var.configure_production_environment && local.sql_server_exists ? 1 : 0
  project             = local.project.project_id
  name                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
  location            = local.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account       = local.cloud_run_sa_email
    session_affinity      = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout               = "300s"

    labels = {
      app = var.application_name,
      env = "prod"
    }

    containers {
      image   = "n8nio/n8n:${var.application_version}"
      command = ["/bin/sh"]
      args    = ["-c", "sleep 5; n8n start"]
      
      ports {
        container_port = 5678
      }

      resources {
        startup_cpu_boost = true
        cpu_idle          = false
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }
      }

      # Startup probe - more lenient for production
      startup_probe {
        http_get {
          path = "/healthz"
          port = 5678
        }
        initial_delay_seconds = 15
        timeout_seconds       = 5
        period_seconds        = 10
        failure_threshold     = 5
      }

      # Liveness probe - conservative settings for prod
      liveness_probe {
        http_get {
          path = "/healthz"
          port = 5678
        }
        initial_delay_seconds = 60
        timeout_seconds       = 10
        period_seconds        = 60
        failure_threshold     = 3
      }

      # n8n Configuration
      env {
        name  = "N8N_PORT"
        value = "5678"
      }
      env {
        name  = "N8N_PROTOCOL"
        value = "https"
      }
      env {
        name  = "N8N_DIAGNOSTICS_ENABLED"
        value = "true"
      }
      env {
        name  = "N8N_METRICS"
        value = "true"
      }

      # Database Configuration
      env {
        name  = "DB_TYPE"
        value = "postgresdb"
      }
      env {
        name  = "DB_POSTGRESDB_DATABASE"
        value = google_sql_database.prod_db.name
      }
      env {
        name  = "DB_POSTGRESDB_USER"
        value = google_sql_user.prod_user.name
      }
      env {
        name  = "DB_POSTGRESDB_HOST"
        value = "/cloudsql/${local.project.project_id}:${local.region}:${local.db_instance_name}"
      }
      env {
        name  = "DB_POSTGRESDB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_POSTGRESDB_SCHEMA"
        value = "public"
      }
      env {
        name  = "GENERIC_TIMEZONE"
        value = "UTC"
      }
      env {
        name  = "QUEUE_HEALTH_CHECK_ACTIVE"
        value = "true"
      }
      env {
        name  = "N8N_RUNNERS_ENABLED"
        value = "true"
      }
      env {
        name  = "N8N_BLOCK_ENV_ACCESS_IN_NODE"
        value = "false"
      }
      env {
        name  = "N8N_GIT_NODE_DISABLE_BARE_REPOS"
        value = "true"
      }

      # Storage Configuration - Filesystem mode with GCS FUSE
      env {
        name  = "N8N_AVAILABLE_BINARY_DATA_MODES"
        value = "filesystem"
      }
      env {
        name  = "N8N_DEFAULT_BINARY_DATA_MODE"
        value = "filesystem"
      }
      env {
        name  = "N8N_BINARY_DATA_STORAGE_PATH"
        value = "/files"
      }

      # Secrets
      env {
        name = "DB_POSTGRESDB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.prod_db_password.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "N8N_ENCRYPTION_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.prod_encryption_key.secret_id
            version = "latest"
          }
        }
      }

      # Volume Mounts
      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
      
      volume_mounts {
        name       = "gcs-data"
        mount_path = "/files"
      }
    }

    vpc_access {
      network_interfaces {
        network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
        subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
      }
    }

    scaling {
      min_instance_count = 1
      max_instance_count = 1
    }

    # Volume Definitions
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = ["${local.project.project_id}:${local.region}:${local.db_instance_name}"]
      }
    }

    volumes {
      name = "gcs-data"
      gcs {
        bucket    = google_storage_bucket.prod_storage.name
        read_only = false
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag     = "latest"
    percent = 100
  }

  depends_on = [
    google_sql_database.prod_db,
    google_sql_user.prod_user,
    google_secret_manager_secret_version.prod_db_password,
    google_secret_manager_secret_version.prod_encryption_key,
    google_project_iam_member.cloudsql_client,
    google_storage_bucket.prod_storage,
    google_project_iam_member.storage_admin
  ]
}

resource "google_cloud_run_service_iam_binding" "prod" {
  count = var.configure_production_environment && local.sql_server_exists ? 1 : 0

  project  = local.project.project_id
  location = local.region
  service  = google_cloud_run_v2_service.prod_app_service[0].name
  role     = "roles/run.invoker"
  members = [
    "allUsers"
  ]
}

# IAM binding for GCS bucket access
resource "google_project_iam_member" "storage_admin" {
  project = local.project.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${local.cloud_run_sa_email}"
}
