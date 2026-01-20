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
# N8N_AI Wrapper Module - Multi-Service Deployment Using WebApp
#########################################################################

# This module deploys the N8N AI Stack (N8N + Qdrant + Ollama) using
# the WebApp module three times, wiring them together as a cohesive stack.

module "n8n_ai_config" {
  source = "../WebApp/modules/N8N_AI_WebApp"
}

locals {
  # Resolve defaults
  final_agent_service_account     = var.agent_service_account != null ? var.agent_service_account : module.n8n_ai_config.defaults.agent_service_account
  final_deployment_region         = var.deployment_region != null ? var.deployment_region : module.n8n_ai_config.defaults.deployment_region
  final_network_name              = var.network_name != null ? var.network_name : module.n8n_ai_config.defaults.network_name
  final_resource_creator_identity = var.resource_creator_identity != null ? var.resource_creator_identity : module.n8n_ai_config.defaults.resource_creator_identity
  final_storage_location          = var.storage_location != null ? var.storage_location : module.n8n_ai_config.defaults.storage_location
  final_force_destroy_storage     = var.force_destroy_storage != null ? var.force_destroy_storage : module.n8n_ai_config.defaults.force_destroy_storage
  final_enable_storage_versioning = var.enable_storage_versioning != null ? var.enable_storage_versioning : module.n8n_ai_config.defaults.enable_storage_versioning
  final_application_database_name = var.application_database_name != null ? var.application_database_name : module.n8n_ai_config.defaults.application_database_name
  final_application_database_user = var.application_database_user != null ? var.application_database_user : module.n8n_ai_config.defaults.application_database_user
  final_qdrant_version            = var.qdrant_version != null ? var.qdrant_version : module.n8n_ai_config.defaults.qdrant_version
  final_qdrant_cpu                = var.qdrant_cpu != null ? var.qdrant_cpu : module.n8n_ai_config.defaults.qdrant_cpu
  final_qdrant_memory             = var.qdrant_memory != null ? var.qdrant_memory : module.n8n_ai_config.defaults.qdrant_memory
  final_qdrant_ingress            = var.qdrant_ingress != null ? var.qdrant_ingress : module.n8n_ai_config.defaults.qdrant_ingress
  final_ollama_version            = var.ollama_version != null ? var.ollama_version : module.n8n_ai_config.defaults.ollama_version
  final_ollama_cpu                = var.ollama_cpu != null ? var.ollama_cpu : module.n8n_ai_config.defaults.ollama_cpu
  final_ollama_memory             = var.ollama_memory != null ? var.ollama_memory : module.n8n_ai_config.defaults.ollama_memory
  final_ollama_ingress            = var.ollama_ingress != null ? var.ollama_ingress : module.n8n_ai_config.defaults.ollama_ingress
  final_n8n_version               = var.n8n_version != null ? var.n8n_version : module.n8n_ai_config.defaults.n8n_version
  final_n8n_cpu                   = var.n8n_cpu != null ? var.n8n_cpu : module.n8n_ai_config.defaults.n8n_cpu
  final_n8n_memory                = var.n8n_memory != null ? var.n8n_memory : module.n8n_ai_config.defaults.n8n_memory
  final_n8n_min_instances         = var.n8n_min_instances != null ? var.n8n_min_instances : module.n8n_ai_config.defaults.n8n_min_instances
  final_n8n_max_instances         = var.n8n_max_instances != null ? var.n8n_max_instances : module.n8n_ai_config.defaults.n8n_max_instances
  final_timezone                  = var.timezone != null ? var.timezone : module.n8n_ai_config.defaults.timezone
  final_additional_n8n_env_vars   = var.additional_n8n_env_vars != null ? var.additional_n8n_env_vars : module.n8n_ai_config.defaults.additional_n8n_env_vars
  final_configure_monitoring      = var.configure_monitoring != null ? var.configure_monitoring : module.n8n_ai_config.defaults.configure_monitoring

  # Common configuration shared across all services
  common_config = {
    existing_project_id  = var.existing_project_id
    tenant_deployment_id = var.tenant_deployment_id
    deployment_region    = local.final_deployment_region
    network_name         = local.final_network_name
    agent_service_account = local.final_agent_service_account
    resource_creator_identity = local.final_resource_creator_identity
  }

  # Shared storage bucket name
  shared_bucket_name = "${var.tenant_deployment_id}-n8n-ai-data"
}

#########################################################################
# Shared Storage Bucket
#########################################################################

resource "google_storage_bucket" "shared_data" {
  name          = local.shared_bucket_name
  project       = var.existing_project_id
  location      = local.final_storage_location
  force_destroy = local.final_force_destroy_storage

  uniform_bucket_level_access = true

  versioning {
    enabled = local.final_enable_storage_versioning
  }
}

#########################################################################
# Service 1: Qdrant Vector Database
#########################################################################

module "qdrant" {
  source = "../WebApp"

  # Common configuration
  existing_project_id  = local.common_config.existing_project_id
  tenant_deployment_id = local.common_config.tenant_deployment_id
  deployment_region    = local.common_config.deployment_region
  network_name         = local.common_config.network_name
  agent_service_account = local.common_config.agent_service_account
  resource_creator_identity = local.common_config.resource_creator_identity

  # Service-specific configuration
  application_name = "qdrant"
  application_database_name = "qdrant"
  application_database_user = "qdrant"

  # Container configuration
  container_image_source = "prebuilt"
  container_image        = "qdrant/qdrant:${local.final_qdrant_version}"
  container_port         = 6333

  # Resources
  container_resources = {
    cpu_limit    = local.final_qdrant_cpu
    memory_limit = local.final_qdrant_memory
  }

  min_instance_count = 1
  max_instance_count = 1

  # Storage - use shared bucket
  create_cloud_storage = false
  gcs_volumes = [{
    name        = "data"
    bucket_name = google_storage_bucket.shared_data.name
    mount_path  = "/mnt/gcs"
    readonly    = false
    mount_options = [
      "implicit-dirs",
      "stat-cache-ttl=60s",
      "type-cache-ttl=60s"
    ]
  }]

  # Qdrant configuration
  environment_variables = {
    QDRANT__STORAGE__STORAGE_PATH = "/mnt/gcs/qdrant"
  }

  # Health check
  health_check_config = {
    enabled               = true
    type                  = "HTTP"
    path                  = "/readyz"
    initial_delay_seconds = 15
    timeout_seconds       = 5
    period_seconds        = 10
    failure_threshold     = 3
  }

  startup_probe_config = {
    enabled               = true
    type                  = "HTTP"
    path                  = "/readyz"
    initial_delay_seconds = 15
    timeout_seconds       = 5
    period_seconds        = 10
    failure_threshold     = 10
  }

  # Internal access only
  ingress_settings = local.final_qdrant_ingress

  # Monitoring
  configure_monitoring = local.final_configure_monitoring
  uptime_check_config = {
    enabled = local.final_configure_monitoring
    path    = "/readyz"
  }

  # No database needed for Qdrant
  configure_environment = true
  database_type = "POSTGRES_15"  # Required but won't be used
}

#########################################################################
# Service 2: Ollama LLM Service
#########################################################################

module "ollama" {
  source = "../WebApp"

  # Common configuration
  existing_project_id  = local.common_config.existing_project_id
  tenant_deployment_id = local.common_config.tenant_deployment_id
  deployment_region    = local.common_config.deployment_region
  network_name         = local.common_config.network_name
  agent_service_account = local.common_config.agent_service_account
  resource_creator_identity = local.common_config.resource_creator_identity

  # Service-specific configuration
  application_name = "ollama"
  application_database_name = "ollama"
  application_database_user = "ollama"

  # Container configuration
  container_image_source = "prebuilt"
  container_image        = "ollama/ollama:${local.final_ollama_version}"
  container_port         = 11434

  # Resources - Ollama needs more resources for LLM inference
  container_resources = {
    cpu_limit    = local.final_ollama_cpu
    memory_limit = local.final_ollama_memory
  }

  min_instance_count = 1
  max_instance_count = 1

  # Storage - use shared bucket
  create_cloud_storage = false
  gcs_volumes = [{
    name        = "data"
    bucket_name = google_storage_bucket.shared_data.name
    mount_path  = "/mnt/gcs"
    readonly    = false
    mount_options = [
      "implicit-dirs",
      "stat-cache-ttl=60s",
      "type-cache-ttl=60s"
    ]
  }]

  # Ollama configuration
  environment_variables = {
    OLLAMA_MODELS = "/mnt/gcs/ollama/models"
  }

  # Health check
  health_check_config = {
    enabled               = true
    type                  = "HTTP"
    path                  = "/"
    initial_delay_seconds = 20
    timeout_seconds       = 5
    period_seconds        = 30
    failure_threshold     = 3
  }

  startup_probe_config = {
    enabled               = true
    type                  = "HTTP"
    path                  = "/"
    initial_delay_seconds = 20
    timeout_seconds       = 5
    period_seconds        = 10
    failure_threshold     = 10
  }

  # Internal access only
  ingress_settings = local.final_ollama_ingress

  # Monitoring
  configure_monitoring = local.final_configure_monitoring
  uptime_check_config = {
    enabled = local.final_configure_monitoring
    path    = "/"
  }

  # No database needed for Ollama
  configure_environment = true
  database_type = "POSTGRES_15"  # Required but won't be used
}

#########################################################################
# Service 3: N8N Main Application
#########################################################################

module "n8n" {
  source = "../WebApp"

  # Common configuration
  existing_project_id  = local.common_config.existing_project_id
  tenant_deployment_id = local.common_config.tenant_deployment_id
  deployment_region    = local.common_config.deployment_region
  network_name         = local.common_config.network_name
  agent_service_account = local.common_config.agent_service_account
  resource_creator_identity = local.common_config.resource_creator_identity

  # Service-specific configuration
  application_name = "n8n"
  application_database_name = local.final_application_database_name
  application_database_user = local.final_application_database_user

  # Container configuration
  container_image_source = "prebuilt"
  container_image        = "n8nio/n8n:${local.final_n8n_version}"
  container_port         = 5678

  # Resources
  container_resources = {
    cpu_limit    = local.final_n8n_cpu
    memory_limit = local.final_n8n_memory
  }

  min_instance_count = local.final_n8n_min_instances
  max_instance_count = local.final_n8n_max_instances

  # Database configuration - N8N needs a database
  database_type = "POSTGRES_15"
  configure_environment = true

  # Cloud SQL Unix Socket for better performance
  enable_cloudsql_volume = true
  cloudsql_volume_mount_path = "/cloudsql"

  # N8N Configuration with service discovery
  environment_variables = merge(
    {
      N8N_PORT                  = "5678"
      N8N_PROTOCOL              = "https"
      N8N_DIAGNOSTICS_ENABLED   = "true"
      N8N_METRICS               = "true"
      GENERIC_TIMEZONE          = local.final_timezone

      # Database configuration (using Unix socket)
      DB_TYPE                   = "postgresdb"
      DB_POSTGRESDB_PORT        = "5432"
      DB_POSTGRESDB_SCHEMA      = "public"

      # Service URLs for Qdrant and Ollama
      QDRANT_URL                = module.qdrant.service_url
      OLLAMA_URL                = module.ollama.service_url
    },
    local.final_additional_n8n_env_vars
  )

  # Health checks
  health_check_config = {
    enabled               = true
    type                  = "HTTP"
    path                  = "/healthz"
    initial_delay_seconds = 30
    timeout_seconds       = 5
    period_seconds        = 30
    failure_threshold     = 3
  }

  startup_probe_config = {
    enabled               = true
    type                  = "HTTP"
    path                  = "/healthz"
    initial_delay_seconds = 20
    timeout_seconds       = 5
    period_seconds        = 10
    failure_threshold     = 10
  }

  # Public access for N8N UI
  ingress_settings = "all"

  # Monitoring
  configure_monitoring = local.final_configure_monitoring
  uptime_check_config = {
    enabled = local.final_configure_monitoring
    path    = "/healthz"
  }

  # Wait for dependent services to be created
  depends_on = [
    module.qdrant,
    module.ollama
  ]
}
