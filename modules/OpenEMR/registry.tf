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
# Configure Artifact Registry
#########################################################################

# Resource for creating a Google Artifact Registry repository to store application images
resource "google_artifact_registry_repository" "application_image" {
  count         = var.configure_development_environment ? 1 : 0
  project       = local.project.project_id  
  location      = local.region                
  repository_id = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}" 
  description   = "${var.application_name} artifact registry repository"  
  format        = "DOCKER"                 
}
