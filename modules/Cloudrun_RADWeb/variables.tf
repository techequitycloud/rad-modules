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

# GROUP 1: Deployment 

variable "module_description" {
  description = "The description of the module. {{UIMeta group=0 order=100 }}"
  type        = string
  default     = <<-EOT
**Purpose:** This module provides a template for deploying a serverless application on Google Cloud Run. Serverless means you don't have to manage servers, making it easier to deploy and scale your application.

**What it does:**
- Deploys a containerized application on Cloud Run.
- Can be configured to use either a MySQL or PostgreSQL database.
- Sets up a complete environment for the application, including networking, security, and storage.
- Automates the build and deployment process.

**Dependencies:** This module requires the `GCP Services` module to be deployed first to prepare the Google Cloud project.
EOT
}

variable "module_dependency" {
  description = "Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP Project","GCP Services"]
}

variable "credit_cost" {
  description = "Specify the module cost {{UIMeta group=0 order=103 }}"
  type        = string
  default     = "100"
}

variable "deployment_id" {
  description = "Unique ID suffix for resources. Leave blank to generate random ID."
  type        = string
  default     = null
}

variable "resource_creator_identity" {
  description = "The terraform Service Account used to create resources in the destination project. This Service Account must be assigned roles/owner IAM role in the destination project. {{UIMeta group=1 order=102 updatesafe }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "trusted_users" {
  description = "List of trusted users with limited Google Cloud project admin privileges. (e.g. `username@abc.com`). {{UIMeta group=0 order=103 updatesafe }}"
  type        = set(string)
  default     = []
}

# GROUP 2: Application Project

variable "existing_project_id" {
  description = "Enter the project ID of the destination project. {{UIMeta group=2 order=200 updatesafe }}"
  type        = string
}

variable "regions_list" {
  description = "List of regions for application deployment. {{UIMeta group=2 order=201 updatesafe }}"
  type        = set(string)
  default     = ["us-central1"]
}

# GROUP 5: Deploy

variable "application_name" {
  description = "Specify application name. The application name is used to identify configured resources alongside other attributes that ensures uniqueness. {{UIMeta group=0 order=501 updatesafe}}"
  type        = string
  default     = "radweb"
}

variable "application_version" {
  description = "Enter application version. Container images are tagged with this version number. {{UIMeta group=0 order=504 updatesafe}}"
  type        = string
  default     = "1.0"
}

# GROUP 6: CICD

variable "configure_continuous_integration" {
  description = "Select the checkbox to configure GitHub continuous integration and continous delivery pipeline that supports single and multi-region deployment. {{UIMeta group=4 order=601 updatesafe}}"
  type        = bool
  default     = false
}

variable "configure_continuous_deployment" {
  description = "Select the checkbox to configure continous deployment pipeline. Implements a continuous delivery pipeline on the primary deployment region using Cloud Deploy. {{UIMeta group=4 order=600 updatesafe}}"
  type        = bool
  default     = false
}

variable "application_git_token" {
  description = "Specify a github classic token with following privileges needed to configure the code repository: delete_repo, read:org, repo. {{UIMeta group=4 order=602 updatesafe}}"
  type        = string
  default     = ""
  sensitive   = true
}

variable "application_git_usernames" {
  description = "Specify the usernames to add as collaborators to the git repo. {{UIMeta group=4 order=603 updatesafe}}"
  type        = set(string)
  default     = []
}

variable "application_git_installation_id" {
  description = "Specify the application installation ID. {{UIMeta group=0 order=604 updatesafe}}"
  type        = string
  default     = "38735316"
}

variable "application_git_organization" {
  description = "Specify the github organization. {{UIMeta group=0 order=605 updatesafe}}"
  type        = string
  default     = "techequitycloud"
}

# GROUP 7: Tenant

variable "tenant_deployment_id" {
  description = "Specify a client or application deployment id. This uniquely identifies the client or application deployment. {{UIMeta group=3 order=701 updatesafe}}"
  type        = string
}

variable "configure_development_environment" {
  description = "Select to configure development environment. Code is committed to the dev branch in the github repository. {{UIMeta group=3 order=703 updatesafe }}"
  type        = bool
  default     = false
}

variable "configure_nonproduction_environment" {
  description = "Select to configure staging environment. Code is committed to the qa branch in the github repository. {{UIMeta group=3 order=704 updatesafe }}"
  type        = bool
  default     = false
}

variable "configure_production_environment" {
  description = "Select to configure production environment. Code is committed to the prod branch in the github repository. {{UIMeta group=3 order=705 updatesafe }}"
  type        = bool
  default     = false
}

# GROUP 8: Tenant

variable "configure_monitoring" {
  description = "Select this option to configure monitoring. Configures uptime checks, SLOs and SLIs for application, and CPU utilization monitoring for NFS virtual machine. {{UIMeta group=8 order=805 updatesafe}}"
  type        = bool
  default     = false
}
