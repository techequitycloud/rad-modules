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

# GROUP 1: Deployment

variable "module_description" {
  description = "The description of the module. {{UIMeta group=0 order=100 }}"
  type        = string
  default     = "This module deploys a Django application on Google Cloud Run. Django is a high-level Python web framework that encourages rapid development and clean, pragmatic design."
}

variable "module_dependency" {
  description = "Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP Project","GCP Services"]
}

variable "module_services" {
  description = "Specify the module services. {{UIMeta group=0 order=102 }}"
  type = list(string)
  default = ["GCP", "Cloud Run", "Cloud SQL", "Secret Manager", "Cloud IAM"]
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
  description = "The terraform Service Account used to create resources in the destination project. This Service Account must be assigned roles/owner IAM role in the destination project. {{UIMeta group=1 order=102 updatesafe }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "trusted_users" {
  description = "List of trusted users with limited Google Cloud project admin privileges. (e.g. `username@abc.com`). {{UIMeta group=0 order=103 updatesafe }}"
  type        = list(string)
}

# GROUP 2: Application Project

variable "existing_project_id" {
  description = "Enter the project ID of the destination project. {{UIMeta group=2 order=200 updatesafe }}"
  type        = string
}

variable "region" {
  description = "The region to deploy to."
  type        = string
  default     = "us-central1"
}

variable "network_name" {
  description = "The name of the VPC network. {{UIMeta group=2 order=201 updatesafe }}"
  type        = string
  default     = "vpc-network"
}

# GROUP 3: Deploy

variable "application_name" {
  description = "Specify application name. The application name is used to identify configured resources alongside other attributes that ensures uniqueness. {{UIMeta group=0 order=501 updatesafe}}"
  type        = string
  default     = "django"
}

variable "application_database_user" {
  description = "Specify application database user name. {{UIMeta group=0 order=502 updatesafe}}"
  type        = string
  default     = "django"
}

variable "application_database_name" {
  description = "Specify application database name. {{UIMeta group=0 order=503 updatesafe }}"
  type        = string
  default     = "django"
}

variable "application_version" {
  description = "Enter application version (image tag). {{UIMeta group=0 order=504 updatesafe}}"
  type        = string
  default     = "latest"
}

# GROUP 4: Tenant

variable "tenant_deployment_id" {
  description = "Specify a client or application deployment id. This uniquely identifies the client or application deployment. {{UIMeta group=3 order=701 updatesafe}}"
  type        = string
}

variable "configure_development_environment" {
  description = "Select to configure development environment. {{UIMeta group=3 order=703 updatesafe }}"
  type        = bool
  default     = true
}

variable "configure_nonproduction_environment" {
  description = "Select to configure staging environment. {{UIMeta group=3 order=704 updatesafe }}"
  type        = bool
  default     = false
}

variable "configure_production_environment" {
  description = "Select to configure production environment. {{UIMeta group=3 order=705 updatesafe }}"
  type        = bool
  default     = false
}

# Django Specific Variables

variable "db_tier" {
  description = "The machine type to use for the database."
  type        = string
  default     = "db-f1-micro"
}

variable "django_superuser_email" {
  description = "Email for the Django superuser."
  type        = string
  default     = "admin@example.com"
}

variable "django_superuser_username" {
  description = "Username for the Django superuser."
  type        = string
  default     = "admin"
}

variable "django_superuser_password" {
  description = "Password for the Django superuser. If not provided, one will be generated."
  type        = string
  sensitive   = true
  default     = null
}
