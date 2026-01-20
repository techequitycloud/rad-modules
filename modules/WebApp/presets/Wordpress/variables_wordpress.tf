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

variable "existing_project_id" {
  description = "The project ID of the Google Cloud project."
  type        = string
}

variable "deployment_id" {
  description = "Unique ID suffix for resources."
  type        = string
  default     = null
}

variable "tenant_deployment_id" {
  description = "Unique tenant or deployment identifier."
  type        = string
}

variable "deployment_region" {
  description = "Primary deployment region."
  type        = string
  default     = "us-central1"
}

variable "application_name" {
  description = "Application name."
  type        = string
  default     = "wordpress"
}

variable "application_version" {
  description = "Application version."
  type        = string
  default     = "latest"
}

variable "application_database_name" {
  description = "Application database name."
  type        = string
  default     = "wordpress_db"
}

variable "application_database_user" {
  description = "Application database user."
  type        = string
  default     = "wordpress_user"
}

variable "database_type" {
  description = "Database type."
  type        = string
  default     = "MYSQL_8_0"
}

variable "container_image_source" {
  description = "Container image source: 'prebuilt' or 'custom'."
  type        = string
  default     = "custom"
}

variable "container_build_config" {
  description = "Custom container build configuration."
  type = object({
    enabled            = bool
    dockerfile_path    = optional(string, "Dockerfile")
    dockerfile_content = optional(string, null)
    context_path       = optional(string, ".")
    build_args         = optional(map(string), {})
    artifact_repo_name = optional(string, "webapp-repo")
  })
  default = {
    enabled = true
    dockerfile_path = "Dockerfile"
    context_path    = "."
  }
}

variable "container_image" {
  description = "Pre-built container image."
  type        = string
  default     = null
}

variable "gcs_volumes" {
  description = "GCS FUSE volume mounts."
  type = list(object({
    name        = string
    bucket_name = optional(string, null)
    mount_path  = string
    readonly    = optional(bool, false)
    mount_options = optional(list(string), [
      "implicit-dirs",
      "stat-cache-ttl=60s",
      "type-cache-ttl=60s"
    ])
  }))
  default = []
}

variable "network_name" {
  description = "Name of the VPC network."
  type        = string
  default     = "vpc-network"
}

variable "cloudrun_service_account" {
  description = "Service account for Cloud Run."
  type        = string
  default     = null
}

variable "environment_variables" {
  description = "Additional environment variables."
  type        = map(string)
  default     = {}
}
