/**
 * Copyright 2026 Google LLC
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

// SECTION 1: Provider

variable "module_description" {
  description = "Human-readable description of this module displayed to users in the platform UI. {{UIMeta group=0 order=100 }}"
  type        = string
  default     = "This module prepares a Google Cloud project for an instructor-led demonstration of Gemini Enterprise using the fictional Cymbal Pools company. It creates the Gemini Enterprise app (\"Cymbal Pools GE\") with Google Identity configured, a searchable data store of Cymbal Pools documents, a Cloud Storage bucket holding the demo brochure, installation analysis, announcement image and pH-table image, a BigQuery dataset of pool installation requests, a custom ADK BigQuery agent deployed to Vertex AI Agent Runtime with the IAM it needs, and a Model Armor template covering sensitive data, harassment and prompt-injection filtering. What remains for the instructor is the part that needs an interactive Google Workspace sign-in or is itself demoed live: connecting Google Drive and Calendar, creating the OAuth client, registering the BigQuery agent, publishing the announcement, and enabling Feature Management and Model Armor on the app."
}

variable "module_documentation" {
  description = "URL linking to the external documentation for this module. Displayed in the platform UI as a help reference. Metadata only. {{UIMeta group=0 order=1 }}"
  type        = string
  default     = "https://github.com/techequitycloud/rad-modules/blob/main/docs/labs/Gemini_Enterprise.md"
}

variable "module_dependency" {
  description = "Ordered list of module names that must be fully deployed before this module can be deployed. {{UIMeta group=0 order=101 }}"
  type        = list(string)
  default     = ["GCP Project"]
}

variable "module_services" {
  description = "List of cloud service tags associated with this module. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP", "Gemini Enterprise", "Vertex AI", "Agent Runtime", "Agent Development Kit", "BigQuery", "Model Armor", "Cloud Storage", "Cloud IAM"]
}

variable "credit_cost" {
  description = "Number of platform credits consumed when this module is deployed. {{UIMeta group=0 order=103 }}"
  type        = number
  default     = 0
}

variable "require_credit_purchases" {
  description = "Set to true to require users to hold a credit balance before deploying this module. {{UIMeta group=0 order=104 }}"
  type        = bool
  default     = false
}

variable "enable_purge" {
  description = "Set to true (default) to allow platform administrators to permanently delete all resources created by this module. {{UIMeta group=0 order=105 }}"
  type        = bool
  default     = true
}

variable "public_access" {
  description = "Set to false to restrict this module to platform administrators only. Set to true (the default) to make it visible and deployable by all platform users. {{UIMeta group=0 order=106 }}"
  type        = bool
  default     = true
}

variable "enable_rad_gcpproject" {
  description = "Set to false to hide the \"GCP Project on RAD\" option for this module -- it may only be deployed into a customer's own GCP project. This module enables modelarmor, which is absent from every RAD-managed tier allowlist, and aiplatform, which the sandbox and lab tiers do not permit; Gemini Enterprise itself also needs a per-project license or free trial. {{UIMeta group=0 order=110 }}"
  type        = bool
  default     = false
}

variable "shared_users" {
  description = "List of users who can view and deploy this module regardless of the public_access setting. Enter one or more user email addresses. Metadata only — not referenced within the Terraform module execution; consumed by the deployment platform only. {{UIMeta group=0 order=107 }}"
  type        = list(string)
  default     = []
}

variable "resource_creator_identity" {
  description = "Email of the Terraform service account used to provision resources (format: name@project-id.iam.gserviceaccount.com). Must hold roles/owner in the destination project. Leave empty to use Application Default Credentials. {{UIMeta group=0 order=107 updatesafe }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "deployment_id" {
  description = "Short alphanumeric suffix appended to resource names to ensure uniqueness within the project. Set by the platform; leave blank to generate one. {{UIMeta group=0 order=108 }}"
  type        = string
  default     = null
}

variable "enable_services" {
  description = "Set to true (default) to automatically enable required GCP project APIs. Set to false when APIs are already enabled. {{UIMeta group=0 order=109 }}"
  type        = bool
  default     = true
}

// SECTION 2: Main

variable "project_id" {
  description = "GCP project ID to prepare for the Gemini Enterprise demo. Must already exist and the service account must hold roles/owner. Use a project whose users are in the same Google Workspace / Cloud Identity domain as the instructor's sign-in (for Qwiklabs, the lab project with the student account). {{UIMeta group=1 order=101 }}"
  type        = string
  default     = null
}

variable "region" {
  description = "GCP region the custom ADK agent is deployed to on Vertex AI Agent Runtime (e.g. 'us-central1'). Must be a region where Agent Runtime is available and permitted by any constraints/gcp.resourceLocations org policy. Defaults to 'us-central1'. {{UIMeta group=1 order=103 }}"
  type        = string
  default     = "us-central1"
}

// SECTION 3: Gemini Enterprise App

variable "create_gemini_enterprise_app" {
  description = "Set to true (default) to create the Gemini Enterprise app and its Cymbal Pools document data store. Requires Gemini Enterprise to be activated in the project: on a project that has never used it, open Gemini Enterprise in the console once and click 'Start free trial' before deploying, or the app creation fails. Set to false to create the app by hand as the lab describes. {{UIMeta group=2 order=201 }}"
  type        = bool
  default     = true
}

variable "ge_location" {
  description = "Gemini Enterprise location for the app, its data stores and the identity provider: 'global' (default), 'us' or 'eu'. The Drive/Calendar connectors and the BigQuery agent registration must later be created in this same location. Some sandbox projects have zero custom-agent quota at 'global'; use 'us' there. {{UIMeta group=2 order=202 }}"
  type        = string
  default     = "global"
  validation {
    condition     = contains(["global", "us", "eu"], var.ge_location)
    error_message = "ge_location must be one of: global, us, eu."
  }
}

variable "app_display_name" {
  description = "Display name of the Gemini Enterprise app. Defaults to 'Cymbal Pools GE', matching the lab guide. {{UIMeta group=2 order=203 }}"
  type        = string
  default     = "Cymbal Pools GE"
}

variable "company_name" {
  description = "Company name set on the Gemini Enterprise app (Advanced Options > Company Name). It helps the assistant ground answers about 'our company'. Defaults to 'Cymbal Pools'. {{UIMeta group=2 order=204 }}"
  type        = string
  default     = "Cymbal Pools"
}

variable "configure_google_identity" {
  description = "Set to true (default) to select Google Identity as the identity provider for the chosen ge_location. Required before Google Drive or Calendar connectors can be created. Set to false if the project already uses a third-party (workforce identity federation) provider. {{UIMeta group=2 order=205 }}"
  type        = bool
  default     = true
}

// SECTION 4: Demo Content

variable "bucket_location" {
  description = "Location of the demo content bucket (e.g. 'US', 'us-central1'). Defaults to 'US'. {{UIMeta group=3 order=301 }}"
  type        = string
  default     = "US"
}

variable "public_announcement_image" {
  description = "Set to true (default) to make only the 'pool party.png' announcement image publicly readable, so it renders on the Gemini Enterprise home page for every user. Set to false in projects that enforce constraints/storage.publicAccessPrevention, and use an image hosted elsewhere for the announcement. {{UIMeta group=3 order=302 }}"
  type        = bool
  default     = true
}

variable "bq_dataset_id" {
  description = "BigQuery dataset holding the installation_requests table queried by the BigQuery agent. Letters, numbers and underscores only. Defaults to 'cymbal_pools'. {{UIMeta group=3 order=303 }}"
  type        = string
  default     = "cymbal_pools"
  validation {
    condition     = can(regex("^[A-Za-z_][A-Za-z0-9_]*$", var.bq_dataset_id)) && length(var.bq_dataset_id) <= 1024
    error_message = "bq_dataset_id must start with a letter or underscore and contain only letters, numbers and underscores."
  }
}

variable "bq_location" {
  description = "BigQuery dataset location (e.g. 'US', 'EU', 'us-central1'). Defaults to 'US'. {{UIMeta group=3 order=304 }}"
  type        = string
  default     = "US"
}

// SECTION 5: Custom ADK Agent

variable "deploy_adk_agent" {
  description = "Set to true (default) to deploy the BigQuery ADK agent to Vertex AI Agent Runtime and grant the Reasoning Engine service agent Vertex AI User, BigQuery User and BigQuery Data Editor. Deployment takes 5-10 minutes and requires python3 on the machine running Terraform. Set to false to deploy it from Cloud Shell during class as the lab describes. {{UIMeta group=4 order=401 }}"
  type        = bool
  default     = true
}

variable "agent_display_name" {
  description = "Display name of the agent on Agent Runtime. The deployment ID is appended so destroy can find exactly this engine. Defaults to 'BigQuery Pool Data Agent'. {{UIMeta group=4 order=402 }}"
  type        = string
  default     = "BigQuery Pool Data Agent"
}

variable "agent_model" {
  description = "Gemini model the BigQuery agent uses (e.g. 'gemini-3.5-flash'). Changing it redeploys the agent as a new engine, which must then be re-registered in Gemini Enterprise. Defaults to 'gemini-3.5-flash'. {{UIMeta group=4 order=403 }}"
  type        = string
  default     = "gemini-3.5-flash"
}

variable "agent_model_location" {
  description = "Vertex AI location the agent calls the model in. Defaults to 'global', where the newest Gemini models are served; set a region only if the chosen model is regional. {{UIMeta group=4 order=404 }}"
  type        = string
  default     = "global"
}

variable "agent_auth_id" {
  description = "Optional ID of the Gemini Enterprise Authorization (e.g. 'bq-auth') the agent is registered with. When set, BigQuery queries run as the signed-in Gemini Enterprise user via that OAuth token; when empty (default), they run as the Agent Runtime service agent, so the agent works whether or not it is registered with an authorization. {{UIMeta group=4 order=405 }}"
  type        = string
  default     = ""
}

// SECTION 6: Model Armor

variable "create_model_armor_template" {
  description = "Set to true (default) to create the Model Armor template demonstrated in class (sensitive data, harassment/RAI and prompt-injection filters). The instructor attaches it to the app live under Configurations > Assistant. {{UIMeta group=5 order=501 }}"
  type        = bool
  default     = true
}

variable "model_armor_location" {
  description = "Location of the Model Armor template (e.g. 'us', 'eu', 'us-central1'). Leave empty (default) to follow ge_location, with 'global' mapped to 'us' because Model Armor has no global templates. {{UIMeta group=5 order=502 }}"
  type        = string
  default     = ""
}

variable "model_armor_confidence" {
  description = "Minimum confidence at which Model Armor blocks content: 'LOW_AND_ABOVE' (strictest), 'MEDIUM_AND_ABOVE' (default) or 'HIGH'. {{UIMeta group=5 order=503 updatesafe }}"
  type        = string
  default     = "MEDIUM_AND_ABOVE"
  validation {
    condition     = contains(["LOW_AND_ABOVE", "MEDIUM_AND_ABOVE", "HIGH"], var.model_armor_confidence)
    error_message = "model_armor_confidence must be LOW_AND_ABOVE, MEDIUM_AND_ABOVE or HIGH."
  }
}
