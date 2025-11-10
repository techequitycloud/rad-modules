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
  default     = <<-EOT
**Purpose:** This module is used to create a Google Cloud project. It is the foundation for the `Standalone_Platform` used by other modules to deploy applications.

**What it does:**
- Creates a Google Cloud project.
- Enables the APIs needed to configure budgets.

**Dependencies:** None. This is the first module that should be deployed.
EOT
}

variable "module_dependency" {
  description = "Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = []
}

variable "module_services" {
  description = "Specify the module services. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP", "Cloud IAM"]
}

variable "credit_cost" {
  description = "Specify the module cost {{UIMeta group=0 order=103 }}"
  type        = number
  default     = 50
}

variable "require_credit_purchases" {
  description = "Set to true to require credit purchases to deploy this module. {{UIMeta group=0 order=104 }}"
  type        = bool
  default     = false
}

variable "enable_purge" {
  description = "Set to true to enable the ability to purge this module. {{UIMeta group=0 order=105 }}"
  type        = bool
  default     = false
}

variable "deployment_id" {
  description = "Unique ID suffix for resources. Leave blank to generate random ID."
  type        = string
  default     = null
}

variable "resource_creator_identity" {
  description = "The terraform Service Account used to create resources in the destination project. {{UIMeta group=0 order=102 updatesafe }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "folder_id" {
  description = "RAD UI folder ID. {{UIMeta group=0 order=104 }}"
  type        = string
  default     = "158723424265"
}

variable "module_folder_id" {
  description = "Specify the RAD folder ID. {{UIMeta group=0 order=104 }}"
  type        = string
  default     = "785897258084"
}

variable "organization_id" {
  description = "Organization ID where GCP Resources need to be deployed. {{UIMeta group=0 order=1 }}"
  type        = string
  default     = ""
}

variable "billing_account_id" {
  description = "Billing Account associated with GCP resources. {{UIMeta group=0 order=0 updatesafe }}"
  type        = string
}

# GROUP 2: Project

variable "project_id_prefix" {
  description = "Enter the prefix of the project ID. {{UIMeta group=1 order=200 updatesafe }}"
  type        = string
}

variable "trusted_users" {
  description = "List of users with project trusted privileges. {{UIMeta group=0 order=201 updatesafe }}"
  type        = list(string)
  default     = []
}

variable "enable_services" {
  description = "Enable project APIs. {{UIMeta group=1 order=202 updatesafe }}"
  type        = bool
  default     = true
}
