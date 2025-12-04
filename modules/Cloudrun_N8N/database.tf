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

#########################################################################
# Create Database and User
#########################################################################

resource "google_sql_database" "dev_db" {
  count    = var.configure_development_environment && local.sql_server_exists ? 1 : 0
  name     = "${var.application_database_name}-${var.tenant_deployment_id}-${local.random_id}-dev"
  instance = local.db_instance_name
  project  = local.project.project_id
}

resource "google_sql_user" "dev_user" {
  count    = var.configure_development_environment && local.sql_server_exists ? 1 : 0
  name     = "${var.application_database_user}-${var.tenant_deployment_id}-${local.random_id}-dev"
  instance = local.db_instance_name
  project  = local.project.project_id
  password = random_password.dev_db_password.result
}

resource "google_sql_database" "qa_db" {
  count    = var.configure_nonproduction_environment && local.sql_server_exists ? 1 : 0
  name     = "${var.application_database_name}-${var.tenant_deployment_id}-${local.random_id}-qa"
  instance = local.db_instance_name
  project  = local.project.project_id
}

resource "google_sql_user" "qa_user" {
  count    = var.configure_nonproduction_environment && local.sql_server_exists ? 1 : 0
  name     = "${var.application_database_user}-${var.tenant_deployment_id}-${local.random_id}-qa"
  instance = local.db_instance_name
  project  = local.project.project_id
  password = random_password.qa_db_password.result
}

resource "google_sql_database" "prod_db" {
  count    = var.configure_production_environment && local.sql_server_exists ? 1 : 0
  name     = "${var.application_database_name}-${var.tenant_deployment_id}-${local.random_id}-prod"
  instance = local.db_instance_name
  project  = local.project.project_id
}

resource "google_sql_user" "prod_user" {
  count    = var.configure_production_environment && local.sql_server_exists ? 1 : 0
  name     = "${var.application_database_user}-${var.tenant_deployment_id}-${local.random_id}-prod"
  instance = local.db_instance_name
  project  = local.project.project_id
  password = random_password.prod_db_password.result
}
