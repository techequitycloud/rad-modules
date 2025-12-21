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
  default     = "This module deploys the Odoo Enterprise Resource Planning (ERP) application on Google Cloud Run, providing a comprehensive suite of business management tools including CRM, e-commerce, billing, accounting, and more, in a complete and secure environment."
}

variable "module_dependency" {
  description = "Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP Project","GCP Services"]
}

variable "module_services" {
  description = "Specify the module services. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP", "Cloud Run", "Cloud Build", "Cloud Deploy", "Artifact Registry", "Cloud Storage", "Cloud SQL", "Cloud IAM", "Cloud Networking"]
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
  description = "The terraform Service Account used to create resources in the destination project. This Service Account must be assigned roles/owner IAM role in the destination project. {{UIMeta group=0 order=103 }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "trusted_users" {
  description = "List of trusted users with limited Google Cloud project admin privileges. (e.g. `username@abc.com`). {{UIMeta group=0 order=104 }}"
  type        = list(string)
  default     = []
}

# GROUP 2: Application Project

variable "existing_project_id" {
  description = "Enter the project ID of the destination project. {{UIMeta group=2 order=200 }}"
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
  default     = "odoo"
}

variable "application_database_user" {
  description = "Specify application database user name. The actual database user name includes the customer identifier, environment and deployment id to ensure uniqueness. {{UIMeta group=0 order=502}}"
  type        = string
  default     = "odoo"
}

variable "application_database_name" {
  description = "Specify application database name. The actual database name includes the customer identifier, environment and deployment id to ensure uniqueness. {{UIMeta group=0 order=503 }}"
  type        = string
  default     = "odoo"
}

variable "application_version" {
  description = "Enter application version. Container images are tagged with this version number. {{UIMeta group=0 order=504}}"
  type        = string
  default     = "18.0"
}

variable "application_release" {
  description = "Enter application release. This value can be updated from the docker files at https://hub.docker.com/_/odoo {{UIMeta group=0 order=505}}"
  type        = string
  default     = "20251008"
}

variable "application_sha" {
  description = "Enter application SHA. This value can be updated from the docker files at https://hub.docker.com/_/odoo {{UIMeta group=0 order=506}}"
  type        = string
  default     = "c15a8eb3791e805b9cd3078f2dd4e0d78130b1c2"
}

# GROUP 7: Tenant

variable "tenant_deployment_id" {
  description = "Specify a client or application deployment id. This uniquely identifies the client or application deployment. {{UIMeta group=2 order=701}}"
  type        = string
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

variable "configure_backups" {
  description = "Select this checkbox to schedule daily application backups. Configures a Cloud Scheduler trigger to execute a Cloud Run backup job. {{UIMeta group=0 order=806 }}"
  type        = bool
  default     = false
}

variable "application_backup_schedule" {
  description = "Enter the application backup schedule in cron format. This is used to configure the Cloud Scheduler cron job. {{UIMeta group=0 order=807 }}"
  type        = string
  default     = "0 0 * * *"
}

variable "application_backup_fileid" {
  description = "Enter application backup file ID. When enabled, terraform attempts to download the file from Google Drive, and if found, imports the backup file during deployment. {{UIMeta group=0 order=808}}"
  type        = string
  default     = "1jolaJFFU8-qMUgI8XOfGNBHDLFYrJQQT"
}
