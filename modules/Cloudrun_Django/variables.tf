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

variable "project_id" {
  description = "The project ID to deploy to."
  type        = string
}

variable "region" {
  description = "The region to deploy to."
  type        = string
  default     = "us-central1"
}

variable "application_name" {
  description = "Name of the application."
  type        = string
  default     = "django-cloudrun"
}

variable "deployment_id" {
  description = "Unique identifier for the deployment."
  type        = string
  default     = null
}

variable "resource_creator_identity" {
  description = "The identity creating the resources."
  type        = string
  default     = null
}

variable "configure_development_environment" {
  description = "Whether to configure the development environment."
  type        = bool
  default     = true
}

variable "configure_nonproduction_environment" {
  description = "Whether to configure the non-production environment."
  type        = bool
  default     = false
}

variable "configure_production_environment" {
  description = "Whether to configure the production environment."
  type        = bool
  default     = false
}

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

variable "application_version" {
  description = "Version of the application to deploy."
  type        = string
  default     = "latest"
}

variable "existing_project_id" {
  description = "The project ID if it already exists."
  type        = string
  default     = ""
}

variable "network_name" {
  description = "Name of the VPC network."
  type        = string
  default     = "default"
}
