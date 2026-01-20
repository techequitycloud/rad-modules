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

resource "random_id" "deployment" {
  byte_length = 4
}

locals {
  resource_prefix = "app${var.application_name}${var.tenant_deployment_id}${random_id.deployment.hex}"
}

# Service Account
resource "google_service_account" "n8n_sa" {
  account_id   = "${local.resource_prefix}-sa"
  display_name = "N8N Service Account"
  project      = var.existing_project_id
}

# Storage
resource "google_storage_bucket" "n8n_storage" {
  name          = "${local.resource_prefix}-storage"
  location      = var.deployment_region
  force_destroy = true
  project       = var.existing_project_id
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "storage_admin" {
  bucket = google_storage_bucket.n8n_storage.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.n8n_sa.email}"
}

# HMAC Key
resource "google_storage_hmac_key" "n8n_key" {
  service_account_email = google_service_account.n8n_sa.email
  project               = var.existing_project_id
}

# Secrets
resource "google_secret_manager_secret" "storage_access_key" {
  secret_id = "${local.resource_prefix}-access-key"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "storage_access_key" {
  secret      = google_secret_manager_secret.storage_access_key.id
  secret_data = google_storage_hmac_key.n8n_key.access_id
}

resource "google_secret_manager_secret" "storage_secret_key" {
  secret_id = "${local.resource_prefix}-secret-key"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "storage_secret_key" {
  secret      = google_secret_manager_secret.storage_secret_key.id
  secret_data = google_storage_hmac_key.n8n_key.secret
}

resource "random_password" "encryption_key" {
  length  = 32
  special = true
}

resource "google_secret_manager_secret" "encryption_key" {
  secret_id = "${local.resource_prefix}-encryption-key"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "encryption_key" {
  secret      = google_secret_manager_secret.encryption_key.id
  secret_data = random_password.encryption_key.result
}


module "webapp" {
  source = "../../"

  # Project & Deployment
  existing_project_id  = var.existing_project_id
  deployment_id        = random_id.deployment.hex # Use the same random ID
  tenant_deployment_id = var.tenant_deployment_id
  deployment_region    = var.deployment_region

  # Application
  application_name          = var.application_name
  application_version       = var.application_version
  application_database_name = var.application_database_name
  application_database_user = var.application_database_user
  database_type             = var.database_type

  # Container
  container_image_source = var.container_image_source
  container_image        = var.container_image
  container_build_config = var.container_build_config
  container_port         = 5678

  container_resources = {
    cpu_limit    = "1000m"
    memory_limit = "2Gi"
  }

  min_instance_count = 1
  max_instance_count = 1

  # Network
  network_name = var.network_name

  # Service Account
  cloudrun_service_account = google_service_account.n8n_sa.email

  # Storage (Handled externally)
  create_cloud_storage = false

  # Cloud SQL Volume
  enable_cloudsql_volume     = true
  cloudsql_volume_mount_path = "/cloudsql"

  # Probes
  startup_probe_config = {
    enabled               = true
    type                  = "HTTP"
    path                  = "/"
    initial_delay_seconds = 10
    timeout_seconds       = 3
    period_seconds        = 10
    failure_threshold     = 3
  }

  health_check_config = {
    enabled               = true
    type                  = "HTTP"
    path                  = "/"
    initial_delay_seconds = 30
    timeout_seconds       = 5
    period_seconds        = 30
    failure_threshold     = 3
  }

  environment_variables = merge(var.environment_variables, {
    N8N_PORT                 = "5678"
    N8N_PROTOCOL             = "https"
    N8N_DIAGNOSTICS_ENABLED  = "true"
    N8N_METRICS              = "true"
    DB_TYPE                  = "postgresdb"
    DB_POSTGRESDB_DATABASE   = module.webapp.database_name
    DB_POSTGRESDB_USER       = module.webapp.database_user
    DB_POSTGRESDB_HOST       = module.webapp.database_host

    # Storage
    N8N_DEFAULT_BINARY_DATA_MODE = "filesystem"
    N8N_S3_ENDPOINT              = "https://storage.googleapis.com"
    N8N_S3_BUCKET_NAME           = google_storage_bucket.n8n_storage.name
    N8N_S3_REGION                = var.deployment_region
  })

  secret_environment_variables = merge(var.secret_environment_variables, {
    N8N_S3_ACCESS_KEY    = google_secret_manager_secret.storage_access_key.secret_id
    N8N_S3_ACCESS_SECRET = google_secret_manager_secret.storage_secret_key.secret_id
    N8N_ENCRYPTION_KEY   = google_secret_manager_secret.encryption_key.secret_id
    DB_POSTGRESDB_PASSWORD = module.webapp.database_password_secret
  })
}
