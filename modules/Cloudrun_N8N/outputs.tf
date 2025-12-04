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

output "deployment_info" {
  value = {
    deployment_id  = var.deployment_id
    region         = local.region
    project_id = local.project.project_id
  }
}

output "cloud_sql_info" {
  value = {
    cloudsql_instance_ip = local.sql_server_exists ? local.db_internal_ip : ""
    cloud_sql_studio = length(local.db_instance_name) > 0 ? "https://console.cloud.google.com/sql/instances/${local.db_instance_name}/studio?project=${local.project.project_id}" : ""
    development_database_name =  var.configure_development_environment && length(google_sql_database.dev_db) > 0 ? google_sql_database.dev_db[0].name : ""
    development_database_user = var.configure_development_environment && length(google_sql_user.dev_user) > 0 ? google_sql_user.dev_user[0].name : ""
    nonproduction_database_name = var.configure_nonproduction_environment && length(google_sql_database.qa_db) > 0 ? google_sql_database.qa_db[0].name : ""
    nonproduction_database_user = var.configure_nonproduction_environment && length(google_sql_user.qa_user) > 0 ? google_sql_user.qa_user[0].name : ""
    production_database_name = var.configure_production_environment && length(google_sql_database.prod_db) > 0 ? google_sql_database.prod_db[0].name : ""
    production_database_user = var.configure_production_environment && length(google_sql_user.prod_user) > 0 ? google_sql_user.prod_user[0].name : ""
  }
}

output "application_info" {
  value = {
    application_dev_url  = var.configure_development_environment && length(google_cloud_run_v2_service.dev_app_service) > 0 ? google_cloud_run_v2_service.dev_app_service[0].uri : ""
    application_qa_url   = var.configure_nonproduction_environment && length(google_cloud_run_v2_service.qa_app_service) > 0 ? google_cloud_run_v2_service.qa_app_service[0].uri : ""
    application_prod_url = var.configure_production_environment && length(google_cloud_run_v2_service.prod_app_service) > 0 ? google_cloud_run_v2_service.prod_app_service[0].uri : ""
    cloud_secret_manager = var.configure_development_environment || var.configure_nonproduction_environment || var.configure_production_environment ? "https://console.cloud.google.com/security/secret-manager?project=${local.project.project_id}" : ""
  }
}

output "service_info" {
  value = {
    service_dev_url  = var.configure_development_environment ? "https://console.cloud.google.com/run/detail/${local.region}/${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-dev/metrics?project=${local.project.project_id}" : ""
    service_qa_url = var.configure_nonproduction_environment ? "https://console.cloud.google.com/run/detail/${local.region}/${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-qa/metrics?project=${local.project.project_id}" : ""
    service_prod_url = var.configure_production_environment ? "https://console.cloud.google.com/run/detail/${local.region}/${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-prod/metrics?project=${local.project.project_id}" : ""
  }
}
