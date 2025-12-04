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

resource "random_password" "secret_key" {
  length  = 50
  special = false
}

resource "random_password" "superuser_password" {
  length  = 30
  special = false
}

locals {
  superuser_password_value = var.django_superuser_password != null ? var.django_superuser_password : random_password.superuser_password.result
}

resource "google_secret_manager_secret" "application_settings" {
  secret_id = "${var.application_name}-settings-${local.random_id}"
  project   = local.project_id
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "application_settings" {
  secret      = google_secret_manager_secret.application_settings.id
  secret_data = <<EOF
DATABASE_URL="postgres://${google_sql_user.user.name}:${google_sql_user.user.password}@//cloudsql/${local.project_id}:${var.region}:${google_sql_database_instance.instance.name}/${google_sql_database.database.name}"
GS_BUCKET_NAME="${google_storage_bucket.media.name}"
SECRET_KEY="${random_password.secret_key.result}"
DEBUG="True"
EOF
}

resource "google_secret_manager_secret" "superuser_password" {
  secret_id = "${var.application_name}-superuser-password-${local.random_id}"
  project   = local.project_id
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "superuser_password" {
  secret      = google_secret_manager_secret.superuser_password.id
  secret_data = local.superuser_password_value
}
