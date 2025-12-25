# Copyright 2024 Tech Equity Ltd
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

#########################################################################
# Generate random passwords (Django-specific only)
#########################################################################

resource "random_password" "django_secret_key" {
  length  = 50
  special = false
}

resource "random_password" "dev_superuser_password" {
  length  = 16
  special = true
  override_special = "_%@"
}

# NOTE: Database passwords (dev_db_password, qa_db_password, prod_db_password) 
# are already defined in database.tf - DO NOT duplicate them here

#########################################################################
# Dev Secrets
#########################################################################

resource "google_secret_manager_secret" "dev_application_settings" {
  secret_id = "${var.application_name}${var.tenant_deployment_id}${local.random_id}-dev-application-settings"
  replication {
    user_managed {
      replicas {
        location = local.region
      }
    }
  }
  project = local.project.project_id
}

resource "google_secret_manager_secret_version" "dev_application_settings" {
  secret      = google_secret_manager_secret.dev_application_settings.id
  secret_data = <<EOT
DEBUG=True
SECRET_KEY="${random_password.django_secret_key.result}"
GS_BUCKET_NAME="${google_storage_bucket.storage.name}"
DATABASE_URL="postgres://${google_sql_user.dev_user.name}:${google_sql_user.dev_user.password}@/${google_sql_database.dev_db.name}?host=/cloudsql/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}"
EOT

  depends_on = [
    google_secret_manager_secret.dev_application_settings,
    random_password.django_secret_key
  ]
}

resource "google_secret_manager_secret" "dev_superuser_password" {
  secret_id = "${var.application_name}${var.tenant_deployment_id}${local.random_id}-dev-superuser-password"
  replication {
    user_managed {
      replicas {
        location = local.region
      }
    }
  }
  project = local.project.project_id
}

resource "google_secret_manager_secret_version" "dev_superuser_password" {
  secret      = google_secret_manager_secret.dev_superuser_password.id
  secret_data = var.django_superuser_password != null && var.django_superuser_password != "" ? var.django_superuser_password : random_password.dev_superuser_password.result

  depends_on = [
    google_secret_manager_secret.dev_superuser_password,
    random_password.dev_superuser_password
  ]
}

#########################################################################
# Database Password Secrets (for OpenEMR)
# NOTE: The random_password resources are in database.tf
#########################################################################

resource "google_secret_manager_secret" "dev_db_password" {
  secret_id = "${var.application_name}${var.tenant_deployment_id}${local.random_id}-dev-db-password"
  replication {
    user_managed {
      replicas {
        location = local.region
      }
    }
  }
  project = local.project.project_id
}

resource "google_secret_manager_secret_version" "dev_db_password" {
  secret      = google_secret_manager_secret.dev_db_password.id
  secret_data = random_password.dev_db_password.result

  depends_on = [
    google_secret_manager_secret.dev_db_password,
    random_password.dev_db_password
  ]
}

data "google_secret_manager_secret_version" "dev_db_password" {
  secret     = google_secret_manager_secret.dev_db_password.id
  version    = "latest"
  
  depends_on = [
    google_secret_manager_secret_version.dev_db_password
  ]
}
