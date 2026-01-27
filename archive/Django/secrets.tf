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

resource "random_password" "superuser_password" {
  length  = 16
  special = true
  override_special = "_%@"
}

resource "random_password" "db_password" {
  length  = 30
  special = false

  lifecycle {
    create_before_destroy = true
  }
}

#########################################################################
# Secrets
#########################################################################

resource "google_secret_manager_secret" "application_settings" {
  secret_id = "${var.application_name}${var.tenant_deployment_id}${local.random_id}-application-settings"
  replication {
    user_managed {
      replicas {
        location = local.region
      }
    }
  }
  project = local.project.project_id
}

resource "google_secret_manager_secret_version" "application_settings" {
  secret      = google_secret_manager_secret.application_settings.id
  secret_data = <<EOT
DEBUG=True
SECRET_KEY="${random_password.django_secret_key.result}"
GS_BUCKET_NAME="${google_storage_bucket.storage.name}"
DATABASE_URL="postgres://${var.application_database_user}-${var.tenant_deployment_id}-${local.random_id}:${random_password.db_password.result}@/${var.application_database_name}-${var.tenant_deployment_id}-${local.random_id}?host=/cloudsql/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}"
EOT

  depends_on = [
    google_secret_manager_secret.application_settings,
    random_password.django_secret_key,
    random_password.db_password
  ]
}

resource "google_secret_manager_secret" "superuser_password" {
  secret_id = "${var.application_name}${var.tenant_deployment_id}${local.random_id}-superuser-password"
  replication {
    user_managed {
      replicas {
        location = local.region
      }
    }
  }
  project = local.project.project_id
}

resource "google_secret_manager_secret_version" "superuser_password" {
  secret      = google_secret_manager_secret.superuser_password.id
  secret_data = random_password.superuser_password.result

  depends_on = [
    google_secret_manager_secret.superuser_password,
    random_password.superuser_password
  ]
}

#########################################################################
# Database Password Secrets
#########################################################################

resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.application_name}${var.tenant_deployment_id}${local.random_id}-db-password"
  replication {
    user_managed {
      replicas {
        location = local.region
      }
    }
  }
  project = local.project.project_id
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result

  depends_on = [
    google_secret_manager_secret.db_password,
    random_password.db_password
  ]
}

data "google_secret_manager_secret_version" "db_password" {
  secret     = google_secret_manager_secret.db_password.id
  version    = "latest"
  
  depends_on = [
    google_secret_manager_secret_version.db_password
  ]
}
