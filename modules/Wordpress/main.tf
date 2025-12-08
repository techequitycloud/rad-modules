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

locals {
  random_id = var.deployment_id != null ? var.deployment_id : random_id.default[0].hex

  project = ((length(data.google_project.existing_project) > 0 
        ? data.google_project.existing_project  
        : null) 
  ) 

  region  = tolist(local.regions_list)[0]
  regions = tolist(local.regions_list)
  project_number = try(data.google_project.existing_project.number, "")

  # Environment definitions
  environments = merge(
    var.configure_development_environment ? {
      dev = {
        name_suffix = "dev"
        short_name  = "dev"
      }
    } : {},
    var.configure_nonproduction_environment ? {
      qa = {
        name_suffix = "qa"
        short_name  = "qa"
      }
    } : {},
    var.configure_production_environment ? {
      prod = {
        name_suffix = "prod"
        short_name  = "prod"
      }
    } : {}
  )

  # Cartesian product of environments and regions for Services
  # If local.regions has multiple, we deploy to all (or logic says first 2 if length >=2, else first 1)
  # The original logic was: (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]]))
  target_regions = length(local.regions) >= 2 ? local.regions : [local.regions[0]]

  service_instances = flatten([
    for env_key, env_config in local.environments : [
      for region in local.target_regions : {
        key         = "${env_key}-${region}"
        env_key     = env_key
        region      = region
        name_suffix = env_config.name_suffix
        short_name  = env_config.short_name
      }
    ]
  ])
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
