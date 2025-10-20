/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# GROUP 1: Deployment 

variable "module_description" {
  description = "The description of the module. {{UIMeta group=0 order=100 }}"
  type        = string
  default     = <<-EOT
**Purpose:** This module enables you to create and manage a Microsoft Azure Kubernetes Service (AKS) cluster from your Google Cloud console. This is useful for organizations that use both Azure and Google Cloud and want a unified way to manage their applications.

**What it does:**
- Creates an AKS cluster on Azure.
- Connects the AKS cluster to your Google Cloud project.
- Enables you to manage Azure applications from the Google Cloud console.

**Dependencies:** This module deploys into an existing Google Cloud project and requires an Azure account. You are advised to delete deployed resources within your Azure AKS cluster prior to deleting this module.
EOT
}

variable "module_dependency" {
  description = "Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["Azure Account", "GCP Project"]
}

variable "credit_cost" {
  description = "Specify the module cost {{UIMeta group=0 order=103 }}"
  type        = string
  default     = "100"
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

# GROUP 2: Application Project

variable "existing_project_id" {
  description = "Enter the project ID of the destination project. {{UIMeta group=2 order=200 updatesafe }}"
  type        = string
}

# GROUP 3: Cluster

variable "cluster_name_prefix" {
  description = "Prefix to use for generating cluster resources. {{UIMeta group=0 order=301 updatesafe }}"
  type        = string
  default     = "azure-aks-cluster"
}

variable "gcp_location" {
  description = "GCP region where Azure resources will be registered and managed. List - https://cloud.google.com/compute/docs/regions-zones#available. {{UIMeta group=2 order=302 updatesafe }}"
  type        = string
  default     = "us-central1"
}

variable "azure_region" {
  description = "Azure resource region. {{UIMeta group=2 order=303 updatesafe }}"
  type        = string
  default     = "westus2"
}

variable "node_count" {
  description = "The number of nodes in the default node pool. {{UIMeta group=0 order=304 updatesafe }}"
  type        = number
  default     = 3
}

variable "k8s_version" {
  description = "Kubernetes version of the AKS cluster. {{UIMeta group=0 order=304 updatesafe }}"
  type        = string
  default     = "1.31"
}

variable "platform_version" {
  description = "Platform version of the attached cluster resource. {{UIMeta group=0 order=304 updatesafe }}"
  type        = string
  default     = "1.31.0-gke.3"
}

// GROUP 4: IAM

variable "client_id" {
  description = "Azure Client ID (Application ID). {{UIMeta group=3 order=401 updatesafe }}"
  type        = string
}

variable "client_secret" {
  description = "Azure Client Secret. {{UIMeta group=3 order=402 updatesafe }}"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure Tenant ID. {{UIMeta group=3 order=403 updatesafe }}"
  type        = string
}

variable "subscription_id" {
  description = "Azure Subscription ID. {{UIMeta group=3 order=404 updatesafe }}"
  type        = string
}

variable "trusted_users" {
  description = "Email addresses of cluster admin users (e.g. `username@abc.com`). At least one trusted user must be specified. {{UIMeta group=1 order=404 updatesafe }}"
  type        = set(string)

  validation {
    condition     = length(var.trusted_users) > 0
    error_message = "At least one trusted user must be specified."
  }
  
  validation {
    condition = alltrue([
      for user in var.trusted_users : trimspace(user) != ""
    ])
    error_message = "Trusted users cannot be empty strings or contain only whitespace."
  }
  
  validation {
    condition     = length(var.trusted_users) == length(distinct(var.trusted_users))
    error_message = "Duplicate users are not allowed in the owner_users list."
  }
}

variable "owner_users" {
  description = "List of users that should be granted ownershop of the project. {{UIMeta group=0 order=406 updatesafe }}"
  type        = list(string)
  default     = []
}

