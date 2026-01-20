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
# N8N_AI Wrapper Module Outputs
#########################################################################

#########################################################################
# Service URLs
#########################################################################

output "n8n_url" {
  description = "URL for the N8N web interface"
  value       = module.n8n.service_url
}

output "qdrant_url" {
  description = "Internal URL for Qdrant vector database"
  value       = module.qdrant.service_url
}

output "ollama_url" {
  description = "Internal URL for Ollama LLM service"
  value       = module.ollama.service_url
}

#########################################################################
# Storage Information
#########################################################################

output "shared_bucket_name" {
  description = "Name of the shared GCS bucket for all services"
  value       = google_storage_bucket.shared_data.name
}

output "shared_bucket_url" {
  description = "GCS URL of the shared bucket"
  value       = google_storage_bucket.shared_data.url
}

#########################################################################
# Database Information
#########################################################################

output "n8n_database_info" {
  description = "N8N database connection information"
  value = {
    instance_name = module.n8n.database_instance_name
    database_name = module.n8n.database_name
    database_user = module.n8n.database_user
  }
}

#########################################################################
# Service Account Information
#########################################################################

output "n8n_service_account" {
  description = "Service account email for N8N Cloud Run service"
  value       = module.n8n.cloud_run_service_account_email
}

output "qdrant_service_account" {
  description = "Service account email for Qdrant Cloud Run service"
  value       = module.qdrant.cloud_run_service_account_email
}

output "ollama_service_account" {
  description = "Service account email for Ollama Cloud Run service"
  value       = module.ollama.cloud_run_service_account_email
}

#########################################################################
# Deployment Information
#########################################################################

output "deployment_summary" {
  description = "Summary of the N8N AI Stack deployment"
  value = {
    tenant_id          = var.tenant_deployment_id
    region             = var.deployment_region
    n8n_url            = module.n8n.service_url
    qdrant_internal    = module.qdrant.service_url
    ollama_internal    = module.ollama.service_url
    shared_storage     = google_storage_bucket.shared_data.name
    monitoring_enabled = var.configure_monitoring
  }
}
