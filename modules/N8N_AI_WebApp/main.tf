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

locals {
  # Common configuration shared across all services
  common_config = {
    existing_project_id  = var.existing_project_id
    tenant_deployment_id = var.tenant_deployment_id
    deployment_region    = var.deployment_region
    network_name         = var.network_name
    agent_service_account = var.agent_service_account
    resource_creator_identity = var.resource_creator_identity
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
  location      = var.storage_location
  force_destroy = var.force_destroy_storage

  uniform_bucket_level_access = true

  versioning {
    enabled = var.enable_storage_versioning
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
  container_image        = "qdrant/qdrant:${var.qdrant_version}"
  container_port         = 6333

  # Resources
  container_resources = {
    cpu_limit    = var.qdrant_cpu
    memory_limit = var.qdrant_memory
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
  ingress_settings = var.qdrant_ingress

  # Monitoring
  configure_monitoring = var.configure_monitoring
  uptime_check_config = {
    enabled = var.configure_monitoring
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
  container_image        = "ollama/ollama:${var.ollama_version}"
  container_port         = 11434

  # Resources - Ollama needs more resources for LLM inference
  container_resources = {
    cpu_limit    = var.ollama_cpu
    memory_limit = var.ollama_memory
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
  ingress_settings = var.ollama_ingress

  # Monitoring
  configure_monitoring = var.configure_monitoring
  uptime_check_config = {
    enabled = var.configure_monitoring
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
  application_database_name = var.application_database_name
  application_database_user = var.application_database_user

  # Container configuration
  container_image_source = "prebuilt"
  container_image        = "n8nio/n8n:${var.n8n_version}"
  container_port         = 5678

  # Resources
  container_resources = {
    cpu_limit    = var.n8n_cpu
    memory_limit = var.n8n_memory
  }

  min_instance_count = var.n8n_min_instances
  max_instance_count = var.n8n_max_instances

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
      GENERIC_TIMEZONE          = var.timezone

      # Database configuration (using Unix socket)
      DB_TYPE                   = "postgresdb"
      DB_POSTGRESDB_PORT        = "5432"
      DB_POSTGRESDB_SCHEMA      = "public"

      # Service URLs for Qdrant and Ollama
      QDRANT_URL                = module.qdrant.service_url
      OLLAMA_URL                = module.ollama.service_url
    },
    var.additional_n8n_env_vars
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
  configure_monitoring = var.configure_monitoring
  uptime_check_config = {
    enabled = var.configure_monitoring
    path    = "/healthz"
  }

  # Wait for dependent services to be created
  depends_on = [
    module.qdrant,
    module.ollama
  ]
}
