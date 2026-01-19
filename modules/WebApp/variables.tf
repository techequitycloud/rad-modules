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
  default     = "This module deploys a generic Web Application on Google Cloud Run, with configurable Database (Cloud SQL), NFS, and Cloud Storage."
}

variable "module_dependency" {
  description = "Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP_Services"]
}

variable "module_services" {
  description = "Specify the module services. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["Cloud Run", "Cloud Build", "Artifact Registry", "Cloud Storage", "Cloud SQL", "Cloud IAM", "Cloud Networking"]
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
  type        = bool
  default     = true
}

variable "deployment_id" {
  description = "Unique ID suffix for resources.  Leave blank to generate random ID."
  type        = string
  default     = null
}

variable "agent_service_account" {
  description = "If deploying into an existing GCP project outside of the RAD platform, enter a RAD GCP project agent service account. {{UIMeta group=1 order=200 updatesafe }}"
  type        = string
  default     = null
}

variable "resource_creator_identity" {
  description = "The terraform Service Account used to create resources in the destination project. {{UIMeta group=0 order=103 }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "trusted_users" {
  description = "List of trusted users with limited Google Cloud project admin privileges. {{UIMeta group=0 order=104 }}"
  type        = set(string)
  default     = []
}

# GROUP 2: Application Project

variable "existing_project_id" {
  description = "Select an existing project on the RAD platform or enter the project ID of an external GCP project. {{UIMeta group=2 order=200 }}"
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
  default     = false
}

# GROUP 5: Deploy

variable "application_name" {
  description = "Specify application name. {{UIMeta group=0 order=501}}"
  type        = string
  default     = "webapp"
}

variable "application_image" {
  description = "Specify application container image URL. {{UIMeta group=0 order=502}}"
  type        = string
}

variable "application_port" {
  description = "Specify application port. {{UIMeta group=0 order=503}}"
  type        = number
  default     = 8080
}

variable "application_env_vars" {
  description = "Map of environment variables to set for the application. {{UIMeta group=0 order=504}}"
  type        = map(string)
  default     = {}
}

variable "application_database_name" {
  description = "Specify application database name. {{UIMeta group=0 order=505 }}"
  type        = string
  default     = "webapp"
}

variable "database_type" {
  description = "Specify database type (MYSQL, POSTGRES, or NONE). {{UIMeta group=0 order=506}}"
  type        = string
  default     = "NONE"
  validation {
    condition     = contains(["MYSQL", "POSTGRES", "NONE"], var.database_type)
    error_message = "The database_type must be one of: MYSQL, POSTGRES, NONE."
  }
}

variable "enable_nfs" {
  description = "Select to enable NFS storage. {{UIMeta group=0 order=507}}"
  type        = bool
  default     = false
}

variable "nfs_mount_path" {
  description = "Path to mount NFS volume in the container. {{UIMeta group=0 order=508}}"
  type        = string
  default     = "/mnt/nfs"
}

# GROUP 7: Tenant

variable "tenant_deployment_id" {
  description = "Specify a client or application deployment id. {{UIMeta group=2 order=701}}"
  type        = string
}

variable "configure_environment" {
  description = "Select to configure environment. {{UIMeta group=0 order=703 }}"
  type        = bool
  default     = true
}

# GROUP 8: Tenant

variable "configure_monitoring" {
  description = "Select this option to configure monitoring. {{UIMeta group=0 order=805}}"
  type        = bool
  default     = true
}
