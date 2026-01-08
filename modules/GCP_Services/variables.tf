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
  default     = "This module configures foundational Google Cloud serverless platform services, preparing your project by enabling the necessary APIs and services required for other application modules to function correctly."
}

variable "module_dependency" {
  description = "Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP_Project"]
}

variable "module_services" {
  description = "Specify the module services. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["Cloud SQL", "Compute Engine", "Cloud IAM", "Cloud Networking"]
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

variable "agent_service_account" {
  description = "If deploying into an existing GCP project outside of the RAD platform, enter a RAD GCP project agent service account, e.g. rad-agent@gcp-project.sr65.iam.gserviceaccount.com, and grant this service account IAM Owner role in the target Google Cloud project. Leave this field blank if deploying into a target project on the RAD platform. {{UIMeta group=1 order=200 updatesafe }}"
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
  description = "Select an existing project on the RAD platform or enter the project ID of an external GCP project. You must grant Owner role to the RAD GCP Project agent service account when deploying into an external project. {{UIMeta group=2 order=200 }}"
  type        = string
}

variable "enable_services" {
  description = "Enable project APIs. {{UIMeta group=0 order=202 }}"
  type        = bool
  default     = true
}

# GROUP 3: Network

variable "network_name" {
  description = "Name to be assigned to the network. {{UIMeta group=0 order=301 }}"
  type        = string
  default     = "vpc-network"
}

variable "availability_regions" {
  description = "The two regions where compute resources can be configured. The deployment might fail if sufficient resources not available in chosen region. {{UIMeta group=2 order=302 }}"
  type        = list(string)
  default     = ["us-central1"]
}

# GROUP 4: SQL

variable "create_postgres" {
  description = "Select to create postgres database instance. {{UIMeta group=3 order=400 }}"
  type        = bool
  default     = true  # Change to true to create the resource
}

variable "create_mysql" {
  description = "Select to create mysql database instance. {{UIMeta group=3 order=401 }}"
  type        = bool
  default     = false  # Change to true to create the resource
}

variable "postgres_database_version" {
  description = "Database Server version to use. {{UIMeta group=0 order=402 options=POSTGRES_16 }}"
  type        = string
  default     = "POSTGRES_16"
}

variable "postgres_database_availability_type" {
  description = "The availability type of the Cloud SQL instance. {{UIMeta group=0 order=403 options=REGIONAL,ZONAL }}"
  type        = string
  default     = "ZONAL"
}

variable "postgres_tier" {
  description = "The machine type to use. Postgres supports only shared-core machine types, and custom machine types such as `db-custom-2-13312`. {{UIMeta group=0 order=404 }}"
  type        = string
  default     = "db-custom-1-3840"
}

variable "mysql_database_version" {
  description = "Database Server version to use. {{UIMeta group=0 order=405 options=MYSQL_8_0 }}"
  type        = string
  default     = "MYSQL_8_0"
}

variable "mysql_database_availability_type" {
  description = "The availability type of the Cloud SQL instance. {{UIMeta group=0 order=406 options=REGIONAL,ZONAL }}"
  type        = string
  default     = "ZONAL"
}

variable "mysql_tier" {
  description = "The machine type to use. Postgres supports only shared-core machine types, and custom machine types such as `db-custom-2-13312`. {{UIMeta group=0 order=407 }}"
  type        = string
  default     = "db-custom-1-3840"
}

# GROUP 6: NFS Service

variable "create_network_filesystem" {
  description = "Select to create NFS server using Compute Engine instances. {{UIMeta group=0 order=601}}"
  type        = bool
  default     = true
}

variable "network_filesystem_machine" {
  description = "NFS server machine type. {{UIMeta group=0 order=602 }}"
  type        = string
  default     = "e2-small"
}

variable "network_filesystem_capacity" {
  description = "Size of NFS server disks. {{UIMeta group=0 order=603 }}"
  type        = number
  default     = 10
}
