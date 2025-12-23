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
  default     = "This module deploys the Cyclos Banking System (CBS) on Google Cloud Run. This provides a serverless environment for the banking application, which means you don't have to manage servers."
}

variable "module_dependency" {
  description = "Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP_Services"]
}

variable "credit_cost" {
  description = "Specify the module cost {{UIMeta group=0 order=103 }}"
  type        = string
  default     = "250"
}

variable "deployment_id" {
  description = "Unique ID suffix for resources.  Leave blank to generate random ID."
  type        = string
  default     = null
}

variable "resource_creator_identity" {
  description = "The terraform Service Account used to create resources in the destination project. This Service Account must be assigned roles/owner IAM role in the destination project. {{UIMeta group=0 order=102 updatesafe }}"
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
  description = "Enter the project ID of the destination project. {{UIMeta group=1 order=200 updatesafe }}"
  type        = string
}

# GROUP 3: Network

variable "network_name" {
  description = "Name to be assigned to the network. {{UIMeta group=0 order=301 updatesafe }}"
  type        = string
  default     = "vpc-network"
}

# GROUP 5: Storage

variable "create_cloud_storage" {
  description = "Select to enable access to Cloud Storage. {{UIMeta group=0 order=501 updatesafe }}"
  type        = bool
  default     = true  # Change to true to create the resource
}

# GROUP 5: Deploy

variable "application_name" {
  description = "Specify application name. The application name is used to identify configured resources alongside other attributes that ensures uniqueness. {{UIMeta group=0 order=501 updatesafe}}"
  type        = string
  default     = "cyclos"
}

variable "application_database_user" {
  description = "Specify application database user name. The actual database user name includes the customer identifier, environment and deployment id to ensure uniqueness. {{UIMeta group=0 order=502 updatesafe}}"
  type        = string
  default     = "cyclos"
}

variable "application_database_name" {
  description = "Specify application database name. The actual database name includes the customer identifier, environment and deployment id to ensure uniqueness. {{UIMeta group=0 order=503 updatesafe }}"
  type        = string
  default     = "cyclos"
}

variable "application_version" {
  description = "Enter application version. Container images are tagged with this version number. {{UIMeta group=0 order=504 updatesafe}}"
  type        = string
  default     = "4.16.15"
}

# GROUP 7: Tenant

variable "tenant_deployment_id" {
  description = "Specify a client or application deployment id. This uniquely identifies the client or application deployment. {{UIMeta group=1 order=701 updatesafe}}"
  type        = string
}

variable "configure_environment" {
  description = "Select to configure environment. Code is committed to the branch in the github repository. {{UIMeta group=0 order=703 updatesafe }}"
  type        = bool
  default     = true
}

# GROUP 8: Tenant

variable "configure_monitoring" {
  description = "Select this option to configure monitoring. Configures uptime checks, SLOs and SLIs for application, and CPU utilization monitoring. {{UIMeta group=0 order=805 updatesafe}}"
  type        = bool
  default     = true
}

variable "application_backup_fileid" {
  description = "Enter application backup file ID. When enabled, terraform attempts to download the file from Google Drive, and if found, imports the backup files during deployment. {{UIMeta group=0 order=808 updatesafe}}"
  type        = string
  default     = "1NWsxy_PHGKn9LJnXaQh5FFqp_WKjYEsJ"
}

