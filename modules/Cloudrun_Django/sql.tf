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

resource "google_sql_database_instance" "instance" {
  name             = "${var.application_name}-db-${local.random_id}"
  database_version = "POSTGRES_14"
  region           = var.region
  project          = local.project_id

  settings {
    tier = var.db_tier
  }
  deletion_protection = false
}

resource "google_sql_database" "database" {
  name     = "${var.application_name}-db"
  instance = google_sql_database_instance.instance.name
  project  = local.project_id
}

resource "random_password" "db_password" {
  length  = 30
  special = false
}

resource "google_sql_user" "user" {
  name     = "${var.application_name}-user"
  instance = google_sql_database_instance.instance.name
  password = random_password.db_password.result
  project  = local.project_id
}
