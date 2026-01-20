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

locals {
  random_id = var.deployment_id != null ? var.deployment_id : random_id.default[0].hex

  project = ((length(data.google_project.existing_project) > 0 
        ? data.google_project.existing_project  
        : null) 
  ) 

  # Set impersonation service account based on agent service account availability
  # Falls back to resource_creator_identity if agent_service_account is not set
  impersonation_service_account = var.agent_service_account != null && var.agent_service_account != "" ? var.agent_service_account : var.resource_creator_identity

  # Determine if we should use impersonation
  use_impersonation = local.impersonation_service_account != null && local.impersonation_service_account != ""

  region  = tolist(local.regions_list)[0]
  regions = tolist(local.regions_list)
  project_number = try(data.google_project.existing_project.number, "")
}

data "google_compute_zones" "available_zones" {
  project = local.project.project_id
  region  = local.region
  status  = "UP"
}

resource "random_id" "default" {
  count       = var.deployment_id == null ? 1 : 0 
  byte_length = 2 
}

data "google_project" "existing_project" {
  project_id = trimspace(var.existing_project_id)
}

module "django_preset" {
  source = "../WebApp/modules/django"
}

locals {
  application_name          = coalesce(var.application_name, module.django_preset.django_module.app_name)
  application_version       = coalesce(var.application_version, lookup(module.django_preset.django_module, "app_version", "latest"))
  application_database_name = coalesce(var.application_database_name, module.django_preset.django_module.db_name)
  application_database_user = coalesce(var.application_database_user, module.django_preset.django_module.db_user)
  db_tier                   = coalesce(var.db_tier, lookup(module.django_preset.django_module, "db_tier", "db-f1-micro"))
  django_superuser_email    = coalesce(var.django_superuser_email, lookup(module.django_preset.django_module, "django_superuser_email", "admin@example.com"))
  django_superuser_username = coalesce(var.django_superuser_username, lookup(module.django_preset.django_module, "django_superuser_username", "admin"))
}
