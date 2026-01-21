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
    deployment_id = module.webapp.deployment_id
    tenant_id     = module.webapp.tenant_id
    project_id    = module.webapp.project_id
    region        = var.deployment_region
  }
}

output "cloud_sql_info" {
  value = {
    cloudsql_instance_ip = module.webapp.database_host
    database_name        = module.webapp.database_name
    database_user        = module.webapp.database_user
    database_port        = module.webapp.database_port
  }
}

output "application_info" {
  value = {
    application_url = module.webapp.service_url
    service_name    = module.webapp.service_name
  }
}

output "service_info" {
  value = {
    service_url      = module.webapp.service_url
    service_location = module.webapp.service_location
  }
}

output "deployment_summary" {
  description = "Summary of the deployment"
  value       = module.webapp.deployment_summary
}
