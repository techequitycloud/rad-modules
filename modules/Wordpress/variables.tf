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
  default     = "This module deploys WordPress, a popular open-source Content Management System (CMS), on Google Cloud Run, providing a serverless, secure, and complete environment for your website with a database, file storage, and networking."
}

variable "module_dependency" {
  description = "Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP Services"]
}

variable "module_services" {
  description = "Specify the module services. {{UIMeta group=0 order=102 }}"
  type = list(string)
  default = ["GCP", "Cloud Run", "Cloud Build", "Cloud Deploy", "Artifact Registry", "Cloud Storage", "Cloud SQL", "Cloud IAM", "Cloud Networking"]
}

variable "credit_cost" {
  description = "Specify the module cost {{UIMeta group=0 order=103 }}"
  type        = number
  default     = 100
}

variable "require_credit_purchases" {
  description = "Set to true to require credit purchases to deploy this module. {{UIMeta group=0 order=104 }}"
  type        = bool
  default     = false
}

variable "enable_purge" {
  description = "Set to true to enable the ability to purge this module. {{UIMeta group=0 order=105 }}"
  type        = bool
  default     = true
}

variable "public_access" {
  description = "Set to true to enable the module to be available to all platform users. {{UIMeta group=0 order=106 }}"
  type = bool
  default = true
}

variable "deployment_id" {
  description = "Unique ID suffix for resources.  Leave blank to generate random ID."
  type        = string
  default     = null
}

variable "resource_creator_identity" {
  description = "The terraform Service Account used to create resources in the destination project. This Service Account must be assigned roles/owner IAM role in the destination project. {{UIMeta group=0 order=102 }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "trusted_users" {
  description = "List of trusted users with limited Google Cloud project admin privileges. (e.g. `username@abc.com`). {{UIMeta group=0 order=103 }}"
  type        = list(string)
  default     = []
}

# GROUP 2: Application Project

variable "existing_project_id" {
  description = "Select an existing project. If no project is listed, create a new project using the GCP Project module. {{UIMeta group=2 order=200 }}"
  type        = string
}

# GROUP 3: Network

variable "network_name" {
  description = "Name to be assigned to the network. {{UIMeta group=0 order=301 }}"
  type        = string
  default     = "vpc-network"
}

# GROUP 5: Storage

variable "create_cloud_storage" {
  description = "Select to enable access to Cloud Storage. {{UIMeta group=0 order=501 }}"
  type        = bool
  default     = true  # Change to true to create the resource
}

# GROUP 5: Deploy

variable "application_name" {
  description = "Specify application name. The application name is used to identify configured resources alongside other attributes that ensures uniqueness. {{UIMeta group=0 order=501}}"
  type        = string
  default     = "wp"
}

variable "application_database_user" {
  description = "Specify application database user name. The actual database user name includes the customer identifier, environment and deployment id to ensure uniqueness. {{UIMeta group=0 order=502}}"
  type        = string
  default     = "wp"
}

variable "application_database_name" {
  description = "Specify application database name. The actual database name includes the customer identifier, environment and deployment id to ensure uniqueness. {{UIMeta group=0 order=503 }}"
  type        = string
  default     = "wp"
}

variable "application_version" {
  description = "Enter application version. Container images are tagged with this version number. {{UIMeta group=0 order=504}}"
  type        = string
  default     = "6.8.1"
}

variable "application_sha" {
  description = "Enter application SHA. This value can be updated from the docker files at https://hub.docker.com/_/odoo {{UIMeta group=0 order=506}}"
  type        = string
  default     = "52d5f05c96a9155f78ed84700264307e5dea14b4"
}

# GROUP 7: Tenant

variable "tenant_deployment_id" {
  description = "Specify a client or application deployment id. This uniquely identifies the client or application deployment. {{UIMeta group=2 order=701}}"
  type        = string
  default     = ""
}

variable "configure_environment" {
  description = "Select to configure environment. {{UIMeta group=0 order=703 }}"
  type        = bool
  default     = true
}

# GROUP 8: Tenant

variable "configure_monitoring" {
  description = "Select this option to configure monitoring. Configures uptime checks, SLOs and SLIs for application, and CPU utilization monitoring for NFS virtual machine. {{UIMeta group=0 order=805}}"
  type        = bool
  default     = true
}
