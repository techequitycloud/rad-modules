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
  default     = "This module enables you to create and manage an Amazon Elastic Kubernetes Service (EKS) cluster from your Google Cloud console, providing a unified way for organizations using both AWS and Google Cloud to manage their applications. This module is for demonstration purposes only."
}

variable "module_dependency" {
  description = "Ordered list of module names that must be fully deployed before this module can be deployed. The platform enforces this sequence. Defaults to ['AWS Account', 'GCP Project']. {{UIMeta group=0 order=101 }}"
  type        = list(string)
  default     = ["AWS Account", "GCP Project"]
}

variable "module_services" {
  description = "List of cloud service tags associated with this module, used for display and filtering in the platform UI. Represents the key services provisioned by this module. Defaults to the core services this module provisions. {{UIMeta group=0 order=102 }}"
  type = list(string)
  default = ["AWS", "EKS", "IAM", "VPC", "GCP", "GKE Hub", "Anthos"]
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
  description = "Email of the Terraform service account used to provision resources in the destination GCP project (format: name@project-id.iam.gserviceaccount.com). This account must hold roles/owner in the destination project. Defaults to the platform's built-in provisioning service account; only override if using a custom service account. {{UIMeta group=0 order=107 updatesafe }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "trusted_users" {
  description = "List of Google account email addresses granted cluster-admin privileges on the EKS cluster (e.g. ['user@example.com']). Defaults to an empty list (no additional admin users). Entries must be valid, non-blank email addresses with no duplicates. {{UIMeta group=1 order=108 updatesafe }}"
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
  description = "GCP project ID of the destination project where the EKS cluster will be registered via GKE Hub (format: lowercase letters, digits, and hyphens, e.g. 'my-project-123'). This project must already exist and the resource_creator_identity service account must hold roles/owner in it. Required; no default. {{UIMeta group=2 order=200 updatesafe }}"
  type        = string
}

# SECTION 3: Network

variable "gcp_location" {
  description = "GCP region where the EKS cluster will be registered in GKE Hub and appear in the Google Cloud console (e.g. 'us-central1', 'europe-west1'). Defaults to 'us-central1'. Must be a region that supports GKE Hub Attached Clusters. {{UIMeta group=2 order=301 updatesafe }}"
  type        = string
  default     = "us-central1"
}

variable "aws_region" {
  description = "AWS region where the EKS cluster, VPC, and supporting resources will be created (e.g. 'us-west-2', 'us-east-1', 'eu-west-1'). Defaults to 'us-west-2'. The subnet_availability_zones must be valid AZs within this region. {{UIMeta group=2 order=302 updatesafe }}"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr_block" {
  description = "IPv4 CIDR block for the AWS VPC created for the EKS cluster (e.g. '10.0.0.0/16'). Must not overlap with other VPCs in the same AWS account if VPC peering is planned. Defaults to '10.0.0.0/16'. Only used when deploying the cluster. {{UIMeta group=2 order=303 updatesafe }}"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr_blocks" {
  description = "List of IPv4 CIDR blocks for the public subnets, one per availability zone in subnet_availability_zones (e.g. ['10.0.101.0/24', '10.0.102.0/24', '10.0.103.0/24']). Must be subsets of vpc_cidr_block. Only used when enable_public_subnets is true. Defaults to three /24 subnets. {{UIMeta group=2 order=304 updatesafe }}"
  type        = list(string)
  default = [
    "10.0.101.0/24",
    "10.0.102.0/24",
    "10.0.103.0/24"
  ]
}

variable "private_subnet_cidr_blocks" {
  description = "List of IPv4 CIDR blocks for the private subnets, one per availability zone in subnet_availability_zones (e.g. ['10.0.1.0/24', '10.0.2.0/24', '10.0.3.0/24']). Must be subsets of vpc_cidr_block. Used when enable_public_subnets is false. Defaults to three /24 subnets. {{UIMeta group=0 order=305 updatesafe }}"
  type        = list(string)
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24"
  ]
}

variable "subnet_availability_zones" {
  description = "List of AWS availability zones in which to create subnets (e.g. ['us-west-2a', 'us-west-2b', 'us-west-2c']). Must be valid AZs within the selected aws_region. The number of entries must match the number of entries in public_subnet_cidr_blocks and private_subnet_cidr_blocks. Defaults to three AZs in us-west-2. {{UIMeta group=2 order=306 updatesafe }}"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "enable_public_subnets" {
  description = "Set to true (default) to place EKS worker nodes in public subnets with direct internet access. Set to false to place nodes in private subnets with internet access via NAT Gateway (recommended for production workloads for improved security). {{UIMeta group=2 order=307 updatesafe }}"
  type        = bool
  default     = true
}

# SECTION 4: Platform

variable "cluster_name_prefix" {
  description = "Prefix prepended to all generated cluster and resource names (e.g. 'aws-eks-cluster' produces names like 'aws-eks-cluster-<deployment_id>'). Use lowercase letters, digits, and hyphens only. Defaults to 'aws-eks-cluster'. {{UIMeta group=3 order=401 updatesafe }}"
  type        = string
  default     = "aws-eks-cluster"
}

variable "platform_version" {
  description = "GKE Hub Attached Clusters platform version for the managed components installed onto the EKS cluster (format: major.minor.patch-gke.N, e.g. '1.34.0-gke.1'). Must be compatible with the selected k8s_version. Defaults to '1.34.0-gke.1'. {{UIMeta group=3 order=402 updatesafe }}"
  type        = string
  default     = "1.34.0-gke.1"
}

variable "k8s_version" {
  description = "Kubernetes version to deploy on the EKS cluster, specified as major.minor (e.g. '1.34'). Must be a version currently supported by EKS in the selected aws_region. The patch version is managed automatically by EKS. Defaults to '1.34'. {{UIMeta group=3 order=403 updatesafe }}"
  type        = string
  default     = "1.34"
}

variable "node_group_desired_size" {
  description = "Desired number of worker nodes in the EKS managed node group at deployment time. Must be between node_group_min_size and node_group_max_size. Defaults to 2. The cluster autoscaler may adjust this value over time. {{UIMeta group=3 order=404 updatesafe }}"
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Maximum number of worker nodes the EKS managed node group can scale up to. Must be >= node_group_desired_size. Defaults to 5. Higher values allow greater burst capacity but increase potential AWS compute costs. {{UIMeta group=3 order=405 updatesafe }}"
  type        = number
  default     = 5
}

variable "node_group_min_size" {
  description = "Minimum number of worker nodes the EKS managed node group will maintain. Must be <= node_group_desired_size. Defaults to 2. A minimum of 2 is recommended for high availability. {{UIMeta group=3 order=406 updatesafe }}"
  type        = number
  default     = 2
}

// SECTION 5: IAM

variable "aws_access_key" {
  description = "AWS Access Key ID for the IAM user or role used to provision EKS resources (format: 20-character alphanumeric string beginning with 'AKIA' or 'ASIA', e.g. 'AKIAIOSFODNN7EXAMPLE'). Required; no default. Obtain from AWS IAM Console > Security credentials. Stored as sensitive and never shown in logs. {{UIMeta group=4 order=501 updatesafe }}"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Access Key corresponding to aws_access_key (40-character base64-encoded string). Required; no default. Obtain from AWS IAM Console > Security credentials at the time the access key is created (not retrievable afterwards). Stored as sensitive and never shown in logs. {{UIMeta group=4 order=502 updatesafe }}"
  type        = string
  sensitive   = true
}
