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

  application_module = "odoo"

  # Group 1: Deployment
  # module_description, module_dependency, module_services, credit_cost, require_credit_purchases, enable_purge, public_access are UI meta vars, usually not passed to module logic unless WebApp supports them (it supports some like public_access via ingress settings?)
  # WebApp has public_access var.
  public_access             = var.public_access
  deployment_id             = var.deployment_id
  agent_service_account     = var.agent_service_account
  resource_creator_identity = var.resource_creator_identity
  trusted_users             = var.trusted_users

  # Group 2: Application Project
  existing_project_id       = var.existing_project_id

  # Group 3: Network
  network_name              = var.network_name

  # Group 5: Storage
  create_cloud_storage      = var.create_cloud_storage

  # Group 5: Deploy (Application)
  application_name          = var.application_name
  application_database_user = var.application_database_user
  application_database_name = var.application_database_name
  application_version       = var.application_version

  # Group 7: Tenant
  tenant_deployment_id      = var.tenant_deployment_id
  configure_environment     = var.configure_environment

  # Group 8: Monitoring & Backups
  # Configure uptime check based on configure_monitoring
  uptime_check_config = var.configure_monitoring ? { enabled = true, path = "/" } : { enabled = false }

  # Backup Import (Legacy to Unified mapping)
  enable_backup_import = var.application_backup_fileid != ""
  backup_source        = "gdrive"
  backup_uri           = var.application_backup_fileid

  # Note: application_backup_schedule (Cloud Scheduler) is not yet supported by WebApp
}
