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

variable "deploy_app_preset" {
  description = "Application preset to deploy. Options: custom, cyclos, django, moodle, n8n, odoo, openemr, wordpress."
  type        = string
  default     = "custom"

  validation {
    condition     = contains(["custom", "cyclos", "django", "moodle", "n8n", "odoo", "openemr", "wordpress"], var.deploy_app_preset)
    error_message = "Application preset must be one of: custom, cyclos, django, moodle, n8n, odoo, openemr, wordpress."
  }
}

variable "application_name" {
  description = "Application name (overrides preset default)."
  type        = string
  default     = null
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
  description = "Additional environment variables (merged with preset)."
  type        = map(string)
  default     = {}
}
