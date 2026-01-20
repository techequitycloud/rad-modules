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
# GROUP 1: Deployment
#########################################################################

variable "agent_service_account" {
  description = "Service account email for Cloud Run services. If deploying into an existing GCP project outside of the RAD platform, enter a RAD GCP project agent service account and grant this service account IAM Owner role in the target Google Cloud project. Leave this field blank if deploying into a target project on the RAD platform. {{UIMeta group=1 order=200 updatesafe }}"
  type        = string
  default     = null
}

#########################################################################
# GROUP 2: Application Project
#########################################################################

variable "existing_project_id" {
  description = "Existing GCP project ID where resources will be deployed. {{UIMeta group=2 order=200 }}"
  type        = string
}

variable "tenant_deployment_id" {
  description = "Unique identifier for this deployment (used as resource prefix). {{UIMeta group=2 order=201 }}"
  type        = string
}

#########################################################################
# GROUP 0: Advanced Configuration (Hidden/Admin)
#########################################################################

variable "deployment_region" {
  description = "GCP region for Cloud Run deployments. {{UIMeta group=0 order=202 updatesafe }}"
  type        = string
  default     = null
}

variable "network_name" {
  description = "Name of the existing VPC network. {{UIMeta group=0 order=301 updatesafe }}"
  type        = string
  default     = null
}

variable "resource_creator_identity" {
  description = "Identity of the resource creator (user or service account). {{UIMeta group=0 order=102 updatesafe }}"
  type        = string
  default     = null
}

variable "storage_location" {
  description = "Location for the shared GCS bucket (US, EU, ASIA, or specific region). {{UIMeta group=0 order=500 updatesafe }}"
  type        = string
  default     = null
}

variable "force_destroy_storage" {
  description = "Allow deletion of non-empty storage bucket. {{UIMeta group=0 order=501 updatesafe }}"
  type        = bool
  default     = null
}

variable "enable_storage_versioning" {
  description = "Enable versioning on the shared storage bucket. {{UIMeta group=0 order=502 updatesafe }}"
  type        = bool
  default     = null
}

variable "application_database_name" {
  description = "Database name for N8N. {{UIMeta group=0 order=503 updatesafe }}"
  type        = string
  default     = null
}

variable "application_database_user" {
  description = "Database username for N8N. {{UIMeta group=0 order=504 updatesafe }}"
  type        = string
  default     = null
}

# Qdrant Configuration

variable "qdrant_version" {
  description = "Qdrant Docker image version. {{UIMeta group=0 order=600 updatesafe }}"
  type        = string
  default     = null
}

variable "qdrant_cpu" {
  description = "CPU limit for Qdrant container (e.g., '1', '2', '4'). {{UIMeta group=0 order=601 updatesafe }}"
  type        = string
  default     = null
}

variable "qdrant_memory" {
  description = "Memory limit for Qdrant container (e.g., '512Mi', '1Gi', '2Gi'). {{UIMeta group=0 order=602 updatesafe }}"
  type        = string
  default     = null
}

variable "qdrant_ingress" {
  description = "Ingress settings for Qdrant service (all, internal, internal-and-cloud-load-balancing). {{UIMeta group=0 order=603 updatesafe }}"
  type        = string
  default     = null
}

# Ollama Configuration

variable "ollama_version" {
  description = "Ollama Docker image version. {{UIMeta group=0 order=610 updatesafe }}"
  type        = string
  default     = null
}

variable "ollama_cpu" {
  description = "CPU limit for Ollama container (e.g., '2', '4', '8'). {{UIMeta group=0 order=611 updatesafe }}"
  type        = string
  default     = null
}

variable "ollama_memory" {
  description = "Memory limit for Ollama container (e.g., '2Gi', '4Gi', '8Gi'). {{UIMeta group=0 order=612 updatesafe }}"
  type        = string
  default     = null
}

variable "ollama_ingress" {
  description = "Ingress settings for Ollama service (all, internal, internal-and-cloud-load-balancing). {{UIMeta group=0 order=613 updatesafe }}"
  type        = string
  default     = null
}

# N8N Configuration

variable "n8n_version" {
  description = "N8N Docker image version. {{UIMeta group=0 order=620 updatesafe }}"
  type        = string
  default     = null
}

variable "n8n_cpu" {
  description = "CPU limit for N8N container (e.g., '1', '2', '4'). {{UIMeta group=0 order=621 updatesafe }}"
  type        = string
  default     = null
}

variable "n8n_memory" {
  description = "Memory limit for N8N container (e.g., '2Gi', '4Gi', '8Gi'). {{UIMeta group=0 order=622 updatesafe }}"
  type        = string
  default     = null
}

variable "n8n_min_instances" {
  description = "Minimum number of N8N instances. {{UIMeta group=0 order=623 updatesafe }}"
  type        = number
  default     = null
}

variable "n8n_max_instances" {
  description = "Maximum number of N8N instances. {{UIMeta group=0 order=624 updatesafe }}"
  type        = number
  default     = null
}

variable "timezone" {
  description = "Timezone for N8N workflows. {{UIMeta group=0 order=630 updatesafe }}"
  type        = string
  default     = null
}

variable "additional_n8n_env_vars" {
  description = "Additional environment variables for N8N. {{UIMeta group=0 order=631 updatesafe }}"
  type        = map(string)
  default     = null
}

# Monitoring Configuration

variable "configure_monitoring" {
  description = "Enable monitoring and uptime checks for all services. {{UIMeta group=0 order=805 updatesafe }}"
  type        = bool
  default     = null
}
