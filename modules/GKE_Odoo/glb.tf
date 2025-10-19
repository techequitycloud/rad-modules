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
# Configure Dev resources
#########################################################################

# Reserve a global IP address for the load balancer
resource "google_compute_global_address" "dev" {
  count   = var.configure_continuous_deployment || var.configure_development_environment ? 1 : 0
  project = local.project.project_id
  name = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
}

#########################################################################
# Configure QA resources
#########################################################################

# Reserve a global IP address for the load balancer
resource "google_compute_global_address" "qa" {
  count   = var.configure_continuous_deployment || var.configure_nonproduction_environment ? 1 : 0
  project = local.project.project_id
  name = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
}

#########################################################################
# Configure Prod resources
#########################################################################

# Reserve a global IP address for the load balancer
resource "google_compute_global_address" "prod" {
  count   = var.configure_continuous_deployment || var.configure_production_environment ? 1 : 0
  project = local.project.project_id
  name = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
}
