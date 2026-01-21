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

module "webapp" {
  source = "../WebApp"

  application_module = "moodle"

  # Module Metadata & Admin
  module_description       = var.module_description
  module_dependency        = var.module_dependency
  module_services          = var.module_services
  credit_cost              = var.credit_cost
  require_credit_purchases = var.require_credit_purchases
  enable_purge             = var.enable_purge
  public_access            = var.public_access
  deployment_id            = var.deployment_id
  resource_creator_identity = var.resource_creator_identity
  trusted_users            = var.trusted_users

  # Deployment Configuration
  existing_project_id      = var.existing_project_id
  agent_service_account    = var.agent_service_account
  tenant_deployment_id     = var.tenant_deployment_id
  deployment_region        = var.deployment_region
  deployment_regions       = var.deployment_regions
  configure_environment    = var.configure_environment

  # Network
  network_name             = var.network_name

  # Storage
  create_cloud_storage     = var.create_cloud_storage

  # Application Configuration
  application_name          = var.application_name
  application_database_user = var.application_database_user
  application_database_name = var.application_database_name
  application_version       = var.application_version

  # Monitoring
  uptime_check_config = {
    enabled = var.configure_monitoring
    path    = "/"
  }
}
