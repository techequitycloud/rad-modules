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
  default     = "This module deploys N8N AI Starter Kit (n8n, Qdrant, Ollama) on Google Cloud Run."
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
  description = "Select an existing project. If no project is listed, create a new project using the GCP Project module. {{UIMeta group=2 order=200 }}"
  type        = string
}

variable "network_name" {
  description = "The name of the VPC network. {{UIMeta group=0 order=201 }}"
  type        = string
  default     = "vpc-network"
}

# GROUP 3: Deploy

variable "application_name" {
  description = "Specify application name. The application name is used to identify configured resources alongside other attributes that ensures uniqueness. {{UIMeta group=0 order=501}}"
  type        = string
  default     = "n8n"
}

variable "application_database_user" {
  description = "Specify application database user name. {{UIMeta group=0 order=502}}"
  type        = string
  default     = "n8n"
}

variable "application_database_name" {
  description = "Specify application database name. {{UIMeta group=0 order=503 }}"
  type        = string
  default     = "n8n"
}

variable "application_version" {
  description = "Enter application version (image tag). {{UIMeta group=0 order=504}}"
  type        = string
  default     = "latest"
}

# GROUP 4: Tenant

variable "tenant_deployment_id" {
  description = "Specify a client or application deployment id. This uniquely identifies the client or application deployment. {{UIMeta group=2 order=701}}"
  type        = string
}

variable "configure_environment" {
  description = "Select to configure environment. {{UIMeta group=0 order=703 }}"
  type        = bool
  default     = false
}

# GROUP 5: AI Components

variable "enable_ai_components" {
  description = "Set to true to enable AI components (Qdrant, Ollama). {{UIMeta group=0 order=901 }}"
  type        = bool
  default     = true
}

variable "enable_qdrant" {
  description = "Set to true to enable Qdrant vector database. Requires enable_ai_components=true. {{UIMeta group=0 order=902 }}"
  type        = bool
  default     = true
}

variable "qdrant_version" {
  description = "Qdrant Docker image version/tag. {{UIMeta group=0 order=903 }}"
  type        = string
  default     = "latest"
}

variable "enable_ollama" {
  description = "Set to true to enable Ollama LLM provider. Requires enable_ai_components=true. {{UIMeta group=0 order=904 }}"
  type        = bool
  default     = true
}

variable "ollama_version" {
  description = "Ollama Docker image version/tag. {{UIMeta group=0 order=905 }}"
  type        = string
  default     = "latest"
}

variable "ollama_model" {
  description = "The Ollama model to pull on startup (if script implemented) or for documentation. Default is llama3.2. {{UIMeta group=0 order=906 }}"
  type        = string
  default     = "llama3.2"
}

# GROUP 8: Tenant

variable "configure_monitoring" {
  description = "Select this option to configure monitoring. Configures uptime checks, SLOs and SLIs for application, and CPU utilization monitoring for NFS virtual machine. {{UIMeta group=0 order=805}}"
  type        = bool
  default     = true
}
