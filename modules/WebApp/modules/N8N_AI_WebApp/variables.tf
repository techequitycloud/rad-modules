# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  n8n_ai_webapp_defaults = {
    agent_service_account     = null
    deployment_region         = "us-central1"
    network_name              = "vpc-network"
    resource_creator_identity = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
    storage_location          = "US"
    force_destroy_storage     = false
    enable_storage_versioning = true
    application_database_name = "n8n"
    application_database_user = "n8n"
    
    qdrant_version            = "latest"
    qdrant_cpu                = "1"
    qdrant_memory             = "2Gi"
    qdrant_ingress            = "internal"
    
    ollama_version            = "latest"
    ollama_cpu                = "2"
    ollama_memory             = "4Gi"
    ollama_ingress            = "internal"
    
    n8n_version               = "latest"
    n8n_cpu                   = "2"
    n8n_memory                = "4Gi"
    n8n_min_instances         = 1
    n8n_max_instances         = 10
    timezone                  = "America/New_York"
    additional_n8n_env_vars   = {}
    
    configure_monitoring      = true
  }
}

output "defaults" {
  description = "Default configuration for N8N AI WebApp"
  value       = local.n8n_ai_webapp_defaults
}
