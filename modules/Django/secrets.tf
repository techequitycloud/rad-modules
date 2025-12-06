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

resource "random_password" "django_secret_key" {
  length  = 50
  special = false
}

resource "random_password" "dev_superuser_password" {
  count   = var.configure_development_environment ? 1 : 0
  length  = 16
  special = false
}

resource "random_password" "qa_superuser_password" {
  count   = var.configure_nonproduction_environment ? 1 : 0
  length  = 16
  special = false
}

resource "random_password" "prod_superuser_password" {
  count   = var.configure_production_environment ? 1 : 0
  length  = 16
  special = false
}

# --- Dev Secrets ---

resource "google_secret_manager_secret" "dev_application_settings" {
  count     = var.configure_development_environment ? 1 : 0
  secret_id = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-dev-application-settings"
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  project = local.project.project_id
}

resource "google_secret_manager_secret_version" "dev_application_settings" {
  count       = var.configure_development_environment ? 1 : 0
  secret      = google_secret_manager_secret.dev_application_settings[0].id
  secret_data = <<EOT
DEBUG=True
SECRET_KEY="${random_password.django_secret_key.result}"
GS_BUCKET_NAME=google_storage_bucket.dev_storage[0].name
DATABASE_URL="postgres://${google_sql_user.dev_user[0].name}:${google_sql_user.dev_user[0].password}@/${google_sql_database.dev_db[0].name}?host=/cloudsql/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}"
EOT
}

resource "google_secret_manager_secret" "dev_superuser_password" {
  count     = var.configure_development_environment ? 1 : 0
  secret_id = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-dev-superuser-password"
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  project = local.project.project_id
}

resource "google_secret_manager_secret_version" "dev_superuser_password" {
  count       = var.configure_development_environment ? 1 : 0
  secret      = google_secret_manager_secret.dev_superuser_password[0].id
  secret_data = var.django_superuser_password != null ? var.django_superuser_password : random_password.dev_superuser_password[0].result
}

# --- QA Secrets ---

resource "google_secret_manager_secret" "qa_application_settings" {
  count     = var.configure_nonproduction_environment ? 1 : 0
  secret_id = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-qa-application-settings"
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  project = local.project.project_id
}

resource "google_secret_manager_secret_version" "qa_application_settings" {
  count       = var.configure_nonproduction_environment ? 1 : 0
  secret      = google_secret_manager_secret.qa_application_settings[0].id
  secret_data = <<EOT
DEBUG=False
SECRET_KEY="${random_password.django_secret_key.result}"
GS_BUCKET_NAME=google_storage_bucket.qa_storage[0].name
DATABASE_URL="postgres://${google_sql_user.qa_user[0].name}:${google_sql_user.qa_user[0].password}@/${google_sql_database.qa_db[0].name}?host=/cloudsql/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}"
EOT
}

resource "google_secret_manager_secret" "qa_superuser_password" {
  count     = var.configure_nonproduction_environment ? 1 : 0
  secret_id = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-qa-superuser-password"
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  project = local.project.project_id
}

resource "google_secret_manager_secret_version" "qa_superuser_password" {
  count       = var.configure_nonproduction_environment ? 1 : 0
  secret      = google_secret_manager_secret.qa_superuser_password[0].id
  secret_data = var.django_superuser_password != null ? var.django_superuser_password : random_password.qa_superuser_password[0].result
}

# --- Prod Secrets ---

resource "google_secret_manager_secret" "prod_application_settings" {
  count     = var.configure_production_environment ? 1 : 0
  secret_id = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-prod-application-settings"
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  project = local.project.project_id
}

resource "google_secret_manager_secret_version" "prod_application_settings" {
  count       = var.configure_production_environment ? 1 : 0
  secret      = google_secret_manager_secret.prod_application_settings[0].id
  secret_data = <<EOT
DEBUG=False
SECRET_KEY="${random_password.django_secret_key.result}"
GS_BUCKET_NAME=google_storage_bucket.prod_storage[0].name
DATABASE_URL="postgres://${google_sql_user.prod_user[0].name}:${google_sql_user.prod_user[0].password}@/${google_sql_database.prod_db[0].name}?host=/cloudsql/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}"
EOT
}

resource "google_secret_manager_secret" "prod_superuser_password" {
  count     = var.configure_production_environment ? 1 : 0
  secret_id = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-prod-superuser-password"
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  project = local.project.project_id
}

resource "google_secret_manager_secret_version" "prod_superuser_password" {
  count       = var.configure_production_environment ? 1 : 0
  secret      = google_secret_manager_secret.prod_superuser_password[0].id
  secret_data = var.django_superuser_password != null ? var.django_superuser_password : random_password.prod_superuser_password[0].result
}
