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

output "app_service_url" {
  description = "The URL of the deployed application"
  value       = module.webapp.service_url
}

output "service_name" {
  description = "The name of the Cloud Run service"
  value       = module.webapp.service_name
}

output "deployment_info" {
  description = "Deployment information including IDs and names"
  value       = module.webapp.deployment_info
}

output "database_info" {
  description = "Database connection information"
  value = {
    instance_name = module.webapp.database_instance_name
    database_name = module.webapp.database_name
    database_user = module.webapp.database_user
    host          = module.webapp.database_host
    port          = module.webapp.database_port
  }
}

output "storage_buckets" {
  description = "Created storage buckets"
  value       = module.webapp.storage_buckets
}

output "n8n_module" {
  description = "N8N module configuration used"
  value       = "n8n"
}
