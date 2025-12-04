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
  name                = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-dev"
  location            = local.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.n8n_sa.email
    session_affinity = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout = "300s"

    labels = {
      app = var.application_name,
      env = "dev"
    }

    containers {
      image = "n8nio/n8n:${var.application_version}"
      command = ["/bin/sh"]
      args = ["-c", "sleep 5; n8n start"]
      ports {
        container_port = 5678
      }

      resources {
        startup_cpu_boost = true
        cpu_idle = false
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }
      }

      env {
        name = "N8N_PORT"
        value = "5678"
      }
      env {
        name = "N8N_PROTOCOL"
        value = "https"
      }
      env {
        name = "DB_TYPE"
        value = "postgresdb"
      }
      env {
        name = "DB_POSTGRESDB_DATABASE"
        value = google_sql_database.dev_db[0].name
      }
      env {
        name = "DB_POSTGRESDB_USER"
        value = google_sql_user.dev_user[0].name
      }
      env {
        name = "DB_POSTGRESDB_HOST"
        value = "/cloudsql/${local.project.project_id}:${local.region}:${local.db_instance_name}"
      }
      env {
        name = "DB_POSTGRESDB_PORT"
        value = "5432"
      }
      env {
        name = "DB_POSTGRESDB_SCHEMA"
        value = "public"
      }
      env {
        name = "GENERIC_TIMEZONE"
        value = "UTC"
      }
      env {
        name = "QUEUE_HEALTH_CHECK_ACTIVE"
        value = "true"
      }

      # S3/GCS Storage Configuration
      env {
        name = "N8N_DEFAULT_BINARY_DATA_MODE"
        value = "s3"
      }
      env {
        name = "N8N_S3_BUCKET_NAME"
        value = google_storage_bucket.dev_storage[0].name
      }
      env {
        name = "N8N_S3_BUCKET_REGION"
        value = local.region
      }
      env {
        name = "N8N_S3_ENDPOINT"
        value = "https://storage.googleapis.com"
      }

      env {
        name = "DB_POSTGRESDB_PASSWORD"
        value_source {
          secret_key_ref {
            secret = google_secret_manager_secret.dev_db_password[0].secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "N8N_ENCRYPTION_KEY"
        value_source {
          secret_key_ref {
            secret = google_secret_manager_secret.dev_encryption_key[0].secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "N8N_S3_ACCESS_KEY"
        value_source {
          secret_key_ref {
            secret = google_secret_manager_secret.storage_access_key.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "N8N_S3_ACCESS_SECRET"
        value_source {
          secret_key_ref {
            secret = google_secret_manager_secret.storage_secret_key.secret_id
            version = "latest"
          }
        }
      }

      volume_mounts {
        name = "cloudsql"
        mount_path = "/cloudsql"
      }
    }

    scaling {
      min_instance_count = 1
      max_instance_count = 1
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = ["${local.project.project_id}:${local.region}:${local.db_instance_name}"]
      }
    }
  }

  traffic {
    type   = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag    = "latest"
    percent = 100
  }

  depends_on = [
    google_sql_database.dev_db,
    google_sql_user.dev_user,
    google_secret_manager_secret_version.dev_db_password,
    google_secret_manager_secret_version.dev_encryption_key,
    google_project_iam_member.cloudsql_client,
    google_storage_bucket.dev_storage,
    google_secret_manager_secret_version.storage_access_key,
    google_secret_manager_secret_version.storage_secret_key
  ]
}

resource "google_cloud_run_service_iam_binding" "dev" {
  count  = var.configure_development_environment && local.sql_server_exists && var.public_access ? 1 : 0

  project  = local.project.project_id
  location = local.region
  service  = google_cloud_run_v2_service.dev_app_service[0].name
  role     = "roles/run.invoker"
  members  = [
    "allUsers"
  ]
}

resource "google_cloud_run_v2_service" "qa_app_service" {
  count               = var.configure_nonproduction_environment && local.sql_server_exists ? 1 : 0
  project             = local.project.project_id
  name                = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-qa"
  location            = local.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.n8n_sa.email
    session_affinity = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout = "300s"

    labels = {
      app = var.application_name,
      env = "qa"
    }

    containers {
      image = "n8nio/n8n:${var.application_version}"
      command = ["/bin/sh"]
      args = ["-c", "sleep 5; n8n start"]
      ports {
        container_port = 5678
      }

      resources {
        startup_cpu_boost = true
        cpu_idle = false
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }
      }

      env {
        name = "N8N_PORT"
        value = "5678"
      }
      env {
        name = "N8N_PROTOCOL"
        value = "https"
      }
      env {
        name = "DB_TYPE"
        value = "postgresdb"
      }
      env {
        name = "DB_POSTGRESDB_DATABASE"
        value = google_sql_database.qa_db[0].name
      }
      env {
        name = "DB_POSTGRESDB_USER"
        value = google_sql_user.qa_user[0].name
      }
      env {
        name = "DB_POSTGRESDB_HOST"
        value = "/cloudsql/${local.project.project_id}:${local.region}:${local.db_instance_name}"
      }
      env {
        name = "DB_POSTGRESDB_PORT"
        value = "5432"
      }
      env {
        name = "DB_POSTGRESDB_SCHEMA"
        value = "public"
      }
      env {
        name = "GENERIC_TIMEZONE"
        value = "UTC"
      }
      env {
        name = "QUEUE_HEALTH_CHECK_ACTIVE"
        value = "true"
      }

      # S3/GCS Storage Configuration
      env {
        name = "N8N_DEFAULT_BINARY_DATA_MODE"
        value = "s3"
      }
      env {
        name = "N8N_S3_BUCKET_NAME"
        value = google_storage_bucket.qa_storage[0].name
      }
      env {
        name = "N8N_S3_BUCKET_REGION"
        value = local.region
      }
      env {
        name = "N8N_S3_ENDPOINT"
        value = "https://storage.googleapis.com"
      }

      env {
        name = "DB_POSTGRESDB_PASSWORD"
        value_source {
          secret_key_ref {
            secret = google_secret_manager_secret.qa_db_password[0].secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "N8N_ENCRYPTION_KEY"
        value_source {
          secret_key_ref {
            secret = google_secret_manager_secret.qa_encryption_key[0].secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "N8N_S3_ACCESS_KEY"
        value_source {
          secret_key_ref {
            secret = google_secret_manager_secret.storage_access_key.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "N8N_S3_ACCESS_SECRET"
        value_source {
          secret_key_ref {
            secret = google_secret_manager_secret.storage_secret_key.secret_id
            version = "latest"
          }
        }
      }

      volume_mounts {
        name = "cloudsql"
        mount_path = "/cloudsql"
      }
    }

    scaling {
      min_instance_count = 1
      max_instance_count = 1
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = ["${local.project.project_id}:${local.region}:${local.db_instance_name}"]
      }
    }
  }

  traffic {
    type   = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag    = "latest"
    percent = 100
  }

  depends_on = [
    google_sql_database.qa_db,
    google_sql_user.qa_user,
    google_secret_manager_secret_version.qa_db_password,
    google_secret_manager_secret_version.qa_encryption_key,
    google_project_iam_member.cloudsql_client,
    google_storage_bucket.qa_storage,
    google_secret_manager_secret_version.storage_access_key,
    google_secret_manager_secret_version.storage_secret_key
  ]
}

resource "google_cloud_run_service_iam_binding" "qa" {
  count  = var.configure_nonproduction_environment && local.sql_server_exists && var.public_access ? 1 : 0

  project  = local.project.project_id
  location = local.region
  service  = google_cloud_run_v2_service.qa_app_service[0].name
  role     = "roles/run.invoker"
  members  = [
    "allUsers"
  ]
}

resource "google_cloud_run_v2_service" "prod_app_service" {
  count               = var.configure_production_environment && local.sql_server_exists ? 1 : 0
  project             = local.project.project_id
  name                = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-prod"
  location            = local.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.n8n_sa.email
    session_affinity = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout = "300s"

    labels = {
      app = var.application_name,
      env = "prod"
    }

    containers {
      image = "n8nio/n8n:${var.application_version}"
      command = ["/bin/sh"]
      args = ["-c", "sleep 5; n8n start"]
      ports {
        container_port = 5678
      }

      resources {
        startup_cpu_boost = true
        cpu_idle = false
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }
      }

      env {
        name = "N8N_PORT"
        value = "5678"
      }
      env {
        name = "N8N_PROTOCOL"
        value = "https"
      }
      env {
        name = "DB_TYPE"
        value = "postgresdb"
      }
      env {
        name = "DB_POSTGRESDB_DATABASE"
        value = google_sql_database.prod_db[0].name
      }
      env {
        name = "DB_POSTGRESDB_USER"
        value = google_sql_user.prod_user[0].name
      }
      env {
        name = "DB_POSTGRESDB_HOST"
        value = "/cloudsql/${local.project.project_id}:${local.region}:${local.db_instance_name}"
      }
      env {
        name = "DB_POSTGRESDB_PORT"
        value = "5432"
      }
      env {
        name = "DB_POSTGRESDB_SCHEMA"
        value = "public"
      }
      env {
        name = "GENERIC_TIMEZONE"
        value = "UTC"
      }
      env {
        name = "QUEUE_HEALTH_CHECK_ACTIVE"
        value = "true"
      }

      # S3/GCS Storage Configuration
      env {
        name = "N8N_DEFAULT_BINARY_DATA_MODE"
        value = "s3"
      }
      env {
        name = "N8N_S3_BUCKET_NAME"
        value = google_storage_bucket.prod_storage[0].name
      }
      env {
        name = "N8N_S3_BUCKET_REGION"
        value = local.region
      }
      env {
        name = "N8N_S3_ENDPOINT"
        value = "https://storage.googleapis.com"
      }

      env {
        name = "DB_POSTGRESDB_PASSWORD"
        value_source {
          secret_key_ref {
            secret = google_secret_manager_secret.prod_db_password[0].secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "N8N_ENCRYPTION_KEY"
        value_source {
          secret_key_ref {
            secret = google_secret_manager_secret.prod_encryption_key[0].secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "N8N_S3_ACCESS_KEY"
        value_source {
          secret_key_ref {
            secret = google_secret_manager_secret.storage_access_key.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "N8N_S3_ACCESS_SECRET"
        value_source {
          secret_key_ref {
            secret = google_secret_manager_secret.storage_secret_key.secret_id
            version = "latest"
          }
        }
      }

      volume_mounts {
        name = "cloudsql"
        mount_path = "/cloudsql"
      }
    }

    scaling {
      min_instance_count = 1
      max_instance_count = 1
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = ["${local.project.project_id}:${local.region}:${local.db_instance_name}"]
      }
    }
  }

  traffic {
    type   = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag    = "latest"
    percent = 100
  }

  depends_on = [
    google_sql_database.prod_db,
    google_sql_user.prod_user,
    google_secret_manager_secret_version.prod_db_password,
    google_secret_manager_secret_version.prod_encryption_key,
    google_project_iam_member.cloudsql_client,
    google_storage_bucket.prod_storage,
    google_secret_manager_secret_version.storage_access_key,
    google_secret_manager_secret_version.storage_secret_key
  ]
}

resource "google_cloud_run_service_iam_binding" "prod" {
  count  = var.configure_production_environment && local.sql_server_exists && var.public_access ? 1 : 0

  project  = local.project.project_id
  location = local.region
  service  = google_cloud_run_v2_service.prod_app_service[0].name
  role     = "roles/run.invoker"
  members  = [
    "allUsers"
  ]
}
