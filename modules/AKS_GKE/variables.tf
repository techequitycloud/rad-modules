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

# SECTION 1: Deployment

variable "module_description" {
  description = "Human-readable description of this module displayed to users in the platform UI. Changing this will update the description shown in the module catalog. Defaults to the module's built-in description. {{UIMeta group=0 order=100 }}"
  type        = string
  default     = "This module enables you to create and manage a Microsoft Azure Kubernetes Service (AKS) cluster from your Google Cloud console, providing a unified way for organizations using both Azure and Google Cloud to manage their applications. This module is for demonstration purposes only."
}

variable "module_dependency" {
  description = "Ordered list of module names that must be fully deployed before this module can be deployed. The platform enforces this sequence. Defaults to ['Azure Account', 'GCP Project']. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["Azure Account", "GCP Project"]
}

variable "module_services" {
  description = "List of cloud service tags associated with this module, used for display and filtering in the platform UI. Represents the key services provisioned by this module. Defaults to the core services this module provisions. {{UIMeta group=0 order=102 }}"
  type = list(string)
  default = ["Azure", "AKS", "Resource Group", "GCP", "GKE Hub", "Anthos"]
}

variable "credit_cost" {
  description = "Number of platform credits consumed when this module is deployed. Credits are purchased separately; if require_credit_purchases is true, users must have sufficient credit balance before deploying. Defaults to 100. {{UIMeta group=0 order=103 }}"
  type        = number
  default     = 100
}

variable "require_credit_purchases" {
  description = "Set to true to require users to hold a credit balance before deploying this module. When false (default), the module can be deployed regardless of credit balance. {{UIMeta group=0 order=104 }}"
  type        = bool
  default     = false
}

variable "enable_purge" {
  description = "Set to true (default) to allow platform administrators to permanently delete all resources created by this module via the platform purge operation. Set to false to prevent purge operations on this deployment. {{UIMeta group=0 order=105 }}"
  type        = bool
  default     = true
}

variable "public_access" {
  description = "Set to true (default) to make this module visible and deployable by all platform users. Set to false to restrict the module to platform administrators only. {{UIMeta group=0 order=106 }}"
  type = bool
  default = true
}

variable "deployment_id" {
  description = "Short alphanumeric suffix appended to resource names to ensure uniqueness across deployments (e.g. 'abc123'). Leave blank (default null) to have the platform automatically generate a random suffix. Modifying this after initial deployment will force recreation of all named resources."
  type        = string
  default     = null
}

variable "resource_creator_identity" {
  description = "Email of the Terraform service account used to provision resources in the destination GCP project (format: name@project-id.iam.gserviceaccount.com). This account must hold roles/owner in the destination project. Defaults to the platform's built-in provisioning service account; only override if using a custom service account. {{UIMeta group=0 order=102 updatesafe }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "trusted_users" {
  description = "List of Google account email addresses granted cluster-admin privileges on the AKS cluster (e.g. ['user@example.com']). Defaults to an empty list (no additional admin users). Entries must be valid, non-blank email addresses with no duplicates. {{UIMeta group=1 order=103 updatesafe }}"
  type        = list(string)
  default     = []

  validation {
    condition = var.trusted_users == null ? true : alltrue([
      for user in var.trusted_users : trimspace(user) != ""
    ])
    error_message = "Trusted users cannot be empty strings or contain only whitespace."
  }

  validation {
    condition     = var.trusted_users == null ? true : length(var.trusted_users) == length(distinct(var.trusted_users))
    error_message = "Duplicate users are not allowed in the trusted_users list."
  }
}

# SECTION 2: Application Project

variable "existing_project_id" {
  description = "GCP project ID of the destination project where the AKS cluster will be registered via GKE Hub (format: lowercase letters, digits, and hyphens, e.g. 'my-project-123'). This project must already exist and the resource_creator_identity service account must hold roles/owner in it. Required; no default. {{UIMeta group=2 order=200 updatesafe }}"
  type        = string
}

# SECTION 3: Network

variable "gcp_location" {
  description = "GCP region where the AKS cluster will be registered in GKE Hub and appear in the Google Cloud console (e.g. 'us-central1', 'europe-west1'). Defaults to 'us-central1'. Must be a region that supports GKE Hub Attached Clusters. {{UIMeta group=2 order=302 updatesafe }}"
  type        = string
  default     = "us-central1"
}

variable "azure_region" {
  description = "Azure region where the AKS cluster and its supporting resources (Resource Group, Virtual Network) will be created (e.g. 'westus2', 'eastus', 'westeurope'). Defaults to 'westus2'. Availability of AKS features and VM SKUs varies by region. {{UIMeta group=2 order=303 updatesafe }}"
  type        = string
  default     = "westus2"
}

# SECTION 4: Cluster

variable "cluster_name_prefix" {
  description = "Prefix prepended to all generated cluster and resource names (e.g. 'azure-aks-cluster' produces names like 'azure-aks-cluster-<deployment_id>'). Use lowercase letters, digits, and hyphens only. Defaults to 'azure-aks-cluster'. {{UIMeta group=4 order=401 updatesafe }}"
  type        = string
  default     = "azure-aks-cluster"
}

variable "node_count" {
  description = "Number of nodes in the AKS default node pool. A minimum of 2 is recommended for high availability. Defaults to 3. Higher node counts increase Azure compute costs proportionally. {{UIMeta group=4 order=402 updatesafe }}"
  type        = number
  default     = 3
}

variable "k8s_version" {
  description = "Kubernetes version to deploy on the AKS cluster, specified as major.minor (e.g. '1.34'). Must be a version currently supported by AKS in the selected azure_region. The patch version is managed automatically by AKS. Defaults to '1.34'. {{UIMeta group=4 order=403 updatesafe }}"
  type        = string
  default     = "1.34"
}

variable "platform_version" {
  description = "GKE Hub Attached Clusters platform version for the managed components installed onto the AKS cluster (format: major.minor.patch-gke.N, e.g. '1.34.0-gke.1'). Must be compatible with the selected k8s_version. Defaults to '1.34.0-gke.1'. {{UIMeta group=4 order=404 updatesafe }}"
  type        = string
  default     = "1.34.0-gke.1"
}

variable "vm_size" {
  description = "Azure VM SKU used for AKS node pool worker nodes (e.g. 'Standard_D2s_v3' = 2 vCPUs, 8 GB RAM; 'Standard_D4s_v3' = 4 vCPUs, 16 GB RAM). Defaults to 'Standard_D2s_v3'. Larger SKUs increase Azure compute costs; availability varies by azure_region. {{UIMeta group=4 order=405 updatesafe }}"
  type        = string
  default     = "Standard_D2s_v3"
}

// SECTION 5: IAM

variable "client_id" {
  description = "Azure Active Directory Application (Client) ID for the service principal used to create and manage AKS resources (UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx). Required; no default. Obtain from Azure Portal > Azure Active Directory > App Registrations. Stored as sensitive and never shown in logs. {{UIMeta group=5 order=501 updatesafe }}"
  type        = string
  sensitive   = true
}

variable "client_secret" {
  description = "Client secret for the Azure AD service principal identified by client_id. Required; no default. Obtain from Azure Portal > Azure Active Directory > App Registrations > Certificates & Secrets. Stored as sensitive and never shown in logs. {{UIMeta group=5 order=502 updatesafe }}"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure Active Directory Tenant ID for the Azure account (UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx). Required; no default. Find this in Azure Portal > Azure Active Directory > Overview > Tenant ID. Stored as sensitive and never shown in logs. {{UIMeta group=5 order=503 updatesafe }}"
  type        = string
  sensitive   = true
}

variable "subscription_id" {
  description = "Azure Subscription ID where AKS resources will be provisioned (UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx). Required; no default. Find this in Azure Portal > Subscriptions. Stored as sensitive and never shown in logs. {{UIMeta group=5 order=504 updatesafe }}"
  type        = string
  sensitive   = true
}
