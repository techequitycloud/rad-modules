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
# N8N_AI Wrapper Module Variables
#########################################################################

#########################################################################
# Common Configuration
#########################################################################

variable "existing_project_id" {
  description = "Existing GCP project ID where resources will be deployed"
  type        = string
}

variable "tenant_deployment_id" {
  description = "Unique identifier for this deployment (used as resource prefix)"
  type        = string
}

variable "deployment_region" {
  description = "GCP region for Cloud Run deployments"
  type        = string
  default     = "us-central1"
}

variable "network_name" {
  description = "Name of the existing VPC network"
  type        = string
}

variable "agent_service_account" {
  description = "Service account email for Cloud Run services"
  type        = string
}

variable "resource_creator_identity" {
  description = "Identity of the resource creator (user or service account)"
  type        = string
}

#########################################################################
# Storage Configuration
#########################################################################

variable "storage_location" {
  description = "Location for the shared GCS bucket (US, EU, ASIA, or specific region)"
  type        = string
  default     = "US"
}

variable "force_destroy_storage" {
  description = "Allow deletion of non-empty storage bucket"
  type        = bool
  default     = false
}

variable "enable_storage_versioning" {
  description = "Enable versioning on the shared storage bucket"
  type        = bool
  default     = true
}

#########################################################################
# Qdrant Configuration
#########################################################################

variable "qdrant_version" {
  description = "Qdrant Docker image version"
  type        = string
  default     = "latest"
}

variable "qdrant_cpu" {
  description = "CPU limit for Qdrant container (e.g., '1', '2', '4')"
  type        = string
  default     = "1"
}

variable "qdrant_memory" {
  description = "Memory limit for Qdrant container (e.g., '512Mi', '1Gi', '2Gi')"
  type        = string
  default     = "2Gi"
}

variable "qdrant_ingress" {
  description = "Ingress settings for Qdrant service (all, internal, internal-and-cloud-load-balancing)"
  type        = string
  default     = "internal"
}

#########################################################################
# Ollama Configuration
#########################################################################

variable "ollama_version" {
  description = "Ollama Docker image version"
  type        = string
  default     = "latest"
}

variable "ollama_cpu" {
  description = "CPU limit for Ollama container (e.g., '2', '4', '8')"
  type        = string
  default     = "2"
}

variable "ollama_memory" {
  description = "Memory limit for Ollama container (e.g., '2Gi', '4Gi', '8Gi')"
  type        = string
  default     = "4Gi"
}

variable "ollama_ingress" {
  description = "Ingress settings for Ollama service (all, internal, internal-and-cloud-load-balancing)"
  type        = string
  default     = "internal"
}

#########################################################################
# N8N Configuration
#########################################################################

variable "n8n_version" {
  description = "N8N Docker image version"
  type        = string
  default     = "latest"
}

variable "n8n_cpu" {
  description = "CPU limit for N8N container (e.g., '1', '2', '4')"
  type        = string
  default     = "2"
}

variable "n8n_memory" {
  description = "Memory limit for N8N container (e.g., '2Gi', '4Gi', '8Gi')"
  type        = string
  default     = "4Gi"
}

variable "n8n_min_instances" {
  description = "Minimum number of N8N instances"
  type        = number
  default     = 1
}

variable "n8n_max_instances" {
  description = "Maximum number of N8N instances"
  type        = number
  default     = 10
}

variable "application_database_name" {
  description = "Database name for N8N"
  type        = string
  default     = "n8n"
}

variable "application_database_user" {
  description = "Database username for N8N"
  type        = string
  default     = "n8n"
}

variable "timezone" {
  description = "Timezone for N8N workflows"
  type        = string
  default     = "America/New_York"
}

variable "additional_n8n_env_vars" {
  description = "Additional environment variables for N8N"
  type        = map(string)
  default     = {}
}

#########################################################################
# Monitoring Configuration
#########################################################################

variable "configure_monitoring" {
  description = "Enable monitoring and uptime checks for all services"
  type        = bool
  default     = true
}
