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

resource "google_cloud_run_v2_service" "app_service" {
  count               = var.configure_environment && local.sql_server_exists ? 1 : 0
  project             = local.project.project_id
  name                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
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
      env = "app"
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
          path = "/"  # ✅ Changed from /healthz to /
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
          path = "/"  # ✅ Changed from /healthz to /
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
        value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
      }
      env {
        name  = "DB_POSTGRESDB_USER"
        value = "app${var.application_database_user}${var.tenant_deployment_id}${local.random_id}"
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

      # Storage Configuration - S3 mode with GCS
      env {
        name  = "N8N_DEFAULT_BINARY_DATA_MODE"
        value = "s3"
      }
      env {
        name  = "N8N_S3_ENDPOINT"
        value = "https://storage.googleapis.com"
      }
      env {
        name  = "N8N_S3_BUCKET_NAME"
        value = google_storage_bucket.storage.name
      }
      env {
        name  = "N8N_S3_REGION"
        value = local.region
      }
      env {
        name = "N8N_S3_ACCESS_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.storage_access_key.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "N8N_S3_ACCESS_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.storage_secret_key.secret_id
            version = "latest"
          }
        }
      }

      # Secrets
      env {
        name = "DB_POSTGRESDB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password[0].secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "N8N_ENCRYPTION_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.encryption_key.secret_id
            version = "latest"
          }
        }
      }

      # Volume Mounts
      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
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
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag     = "latest"
    percent = 100
  }

  # ✅ Fixed dependencies
  depends_on = [
    null_resource.execute_import_db_job,
    google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_version.encryption_key,
    google_storage_bucket.storage,
    google_project_iam_member.storage_admin,
    google_secret_manager_secret_version.storage_access_key,
    google_secret_manager_secret_version.storage_secret_key,
    google_storage_hmac_key.n8n_key,
    null_resource.cleanup_hmac_keys,
    google_secret_manager_secret_iam_member.db_password,
    google_secret_manager_secret_iam_member.storage_access_key,
    google_secret_manager_secret_iam_member.storage_secret_key,
    google_secret_manager_secret_iam_member.encryption_key,
    google_storage_bucket_iam_member.storage_admin
  ]
}

resource "google_cloud_run_service_iam_binding" "app_service" {
  count = var.configure_environment && local.sql_server_exists ? 1 : 0

  project  = local.project.project_id
  location = local.region
  service  = google_cloud_run_v2_service.app_service[0].name
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
