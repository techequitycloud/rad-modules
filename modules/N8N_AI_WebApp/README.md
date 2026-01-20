# N8N AI Stack Wrapper Module

This wrapper module deploys a complete N8N AI Stack consisting of three interconnected services using the WebApp module:

1. **Qdrant** - Vector database for AI embeddings
2. **Ollama** - Local LLM inference service
3. **N8N** - Workflow automation platform with AI capabilities

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    N8N AI Stack                              │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────┐         ┌──────────┐         ┌──────────┐    │
│  │  Qdrant  │◄────────┤   N8N    │────────►│  Ollama  │    │
│  │  (6333)  │         │  (5678)  │         │ (11434)  │    │
│  └────┬─────┘         └────┬─────┘         └────┬─────┘    │
│       │                    │                     │           │
│       └────────────────────┼─────────────────────┘           │
│                            │                                 │
│                    ┌───────▼────────┐                        │
│                    │  Shared GCS    │                        │
│                    │    Bucket      │                        │
│                    │                │                        │
│                    │ • Qdrant Data  │                        │
│                    │ • Ollama Models│                        │
│                    └────────────────┘                        │
│                                                               │
│  ┌────────────────────────────────────────────────┐         │
│  │         Cloud SQL PostgreSQL (N8N)             │         │
│  │      (Connected via Unix Socket)               │         │
│  └────────────────────────────────────────────────┘         │
│                                                               │
└─────────────────────────────────────────────────────────────┘

Access:
  - N8N:    Public (HTTPS)
  - Qdrant: Internal only
  - Ollama: Internal only
```

## Features

- **Multi-Service Deployment**: Three services deployed and wired together automatically
- **Service Discovery**: N8N automatically configured with Qdrant and Ollama URLs
- **Shared Storage**: Single GCS bucket shared across all services for data persistence
- **Database Integration**: PostgreSQL database for N8N with Unix socket connection
- **Automatic Scaling**: N8N scales from 1-10 instances based on load
- **Health Monitoring**: Built-in health checks and uptime monitoring for all services
- **Security**: Internal-only access for Qdrant and Ollama, public HTTPS for N8N

## Usage

### Basic Deployment

```hcl
module "n8n_ai" {
  source = "./modules/N8N_AI_WebApp"

  # Common configuration
  existing_project_id       = "my-gcp-project"
  tenant_deployment_id      = "prod"
  deployment_region         = "us-central1"
  network_name              = "my-vpc-network"
  agent_service_account     = "cloudrun-sa@my-project.iam.gserviceaccount.com"
  resource_creator_identity = "user:admin@example.com"

  # Use default versions and resource limits
}
```

### Production Deployment with Custom Configuration

```hcl
module "n8n_ai" {
  source = "./modules/N8N_AI_WebApp"

  # Common configuration
  existing_project_id       = "my-gcp-project"
  tenant_deployment_id      = "prod"
  deployment_region         = "us-central1"
  network_name              = "my-vpc-network"
  agent_service_account     = "cloudrun-sa@my-project.iam.gserviceaccount.com"
  resource_creator_identity = "user:admin@example.com"

  # Storage configuration
  storage_location          = "US"
  force_destroy_storage     = false
  enable_storage_versioning = true

  # Qdrant configuration
  qdrant_version = "v1.7.4"
  qdrant_cpu     = "2"
  qdrant_memory  = "4Gi"

  # Ollama configuration (needs more resources for LLM inference)
  ollama_version = "latest"
  ollama_cpu     = "4"
  ollama_memory  = "8Gi"

  # N8N configuration
  n8n_version        = "latest"
  n8n_cpu            = "2"
  n8n_memory         = "4Gi"
  n8n_min_instances  = 2
  n8n_max_instances  = 20
  timezone           = "America/New_York"

  # Additional N8N environment variables
  additional_n8n_env_vars = {
    N8N_ENCRYPTION_KEY        = "your-encryption-key-here"
    N8N_USER_MANAGEMENT_DISABLED = "false"
    EXECUTIONS_DATA_SAVE_ON_ERROR    = "all"
    EXECUTIONS_DATA_SAVE_ON_SUCCESS  = "all"
    EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS = "true"
  }

  # Monitoring
  configure_monitoring = true
}
```

### Multi-Environment Deployment

```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

locals {
  resource_limits = {
    dev = {
      qdrant_cpu    = "1"
      qdrant_memory = "2Gi"
      ollama_cpu    = "2"
      ollama_memory = "4Gi"
      n8n_cpu       = "1"
      n8n_memory    = "2Gi"
      n8n_max       = 5
    }
    staging = {
      qdrant_cpu    = "2"
      qdrant_memory = "4Gi"
      ollama_cpu    = "4"
      ollama_memory = "8Gi"
      n8n_cpu       = "2"
      n8n_memory    = "4Gi"
      n8n_max       = 10
    }
    prod = {
      qdrant_cpu    = "4"
      qdrant_memory = "8Gi"
      ollama_cpu    = "8"
      ollama_memory = "16Gi"
      n8n_cpu       = "4"
      n8n_memory    = "8Gi"
      n8n_max       = 20
    }
  }
}

module "n8n_ai" {
  source = "./modules/N8N_AI_WebApp"

  existing_project_id       = var.project_id
  tenant_deployment_id      = var.environment
  deployment_region         = "us-central1"
  network_name              = "my-vpc"
  agent_service_account     = var.service_account
  resource_creator_identity = var.creator_identity

  # Environment-specific resource limits
  qdrant_cpu    = local.resource_limits[var.environment].qdrant_cpu
  qdrant_memory = local.resource_limits[var.environment].qdrant_memory
  ollama_cpu    = local.resource_limits[var.environment].ollama_cpu
  ollama_memory = local.resource_limits[var.environment].ollama_memory
  n8n_cpu       = local.resource_limits[var.environment].n8n_cpu
  n8n_memory    = local.resource_limits[var.environment].n8n_memory
  n8n_max_instances = local.resource_limits[var.environment].n8n_max
}
```

## Outputs

After deployment, the module provides these outputs:

```hcl
# Access the N8N web interface
output "n8n_url" {
  value = module.n8n_ai.n8n_url
}

# Internal service URLs (for debugging)
output "qdrant_url" {
  value = module.n8n_ai.qdrant_url
}

output "ollama_url" {
  value = module.n8n_ai.ollama_url
}

# Storage bucket information
output "shared_bucket" {
  value = module.n8n_ai.shared_bucket_name
}

# Complete deployment summary
output "deployment_info" {
  value = module.n8n_ai.deployment_summary
}
```

## Service-Specific Details

### Qdrant (Vector Database)

- **Container Image**: `qdrant/qdrant:${var.qdrant_version}`
- **Port**: 6333
- **Storage**: `/mnt/gcs/qdrant` (on shared GCS bucket)
- **Health Check**: `/readyz` endpoint
- **Access**: Internal only (not accessible from internet)
- **Scaling**: Fixed at 1 instance (vector databases don't scale horizontally easily)

**Default Configuration**:
```hcl
qdrant_version = "latest"
qdrant_cpu     = "1"
qdrant_memory  = "2Gi"
qdrant_ingress = "internal"
```

### Ollama (LLM Service)

- **Container Image**: `ollama/ollama:${var.ollama_version}`
- **Port**: 11434
- **Storage**: `/mnt/gcs/ollama/models` (on shared GCS bucket for model persistence)
- **Health Check**: `/` endpoint
- **Access**: Internal only
- **Scaling**: Fixed at 1 instance (LLM models are stateful)

**Default Configuration**:
```hcl
ollama_version = "latest"
ollama_cpu     = "2"
ollama_memory  = "4Gi"
ollama_ingress = "internal"
```

**Note**: Ollama needs higher resources for LLM inference. Increase CPU/memory for larger models.

### N8N (Workflow Automation)

- **Container Image**: `n8nio/n8n:${var.n8n_version}`
- **Port**: 5678
- **Database**: PostgreSQL 15 (Cloud SQL with Unix socket)
- **Health Check**: `/healthz` endpoint
- **Access**: Public HTTPS
- **Scaling**: Auto-scales from 1 to 10 instances (configurable)

**Default Configuration**:
```hcl
n8n_version        = "latest"
n8n_cpu            = "2"
n8n_memory         = "4Gi"
n8n_min_instances  = 1
n8n_max_instances  = 10
timezone           = "America/New_York"
```

**Service Discovery**:
N8N is automatically configured with environment variables pointing to Qdrant and Ollama:
- `QDRANT_URL`: Internal URL of Qdrant service
- `OLLAMA_URL`: Internal URL of Ollama service

## Storage Structure

The shared GCS bucket is organized as follows:

```
gs://${tenant_deployment_id}-n8n-ai-data/
├── qdrant/              # Qdrant vector database files
│   ├── collections/
│   ├── storage/
│   └── snapshots/
└── ollama/              # Ollama model files
    └── models/
        ├── llama2/
        ├── mistral/
        └── ...
```

## Networking and Security

### Service Access

| Service | Access Level | Ingress Setting | Purpose |
|---------|-------------|-----------------|---------|
| N8N | Public HTTPS | `all` | User access to workflow UI |
| Qdrant | Internal only | `internal` | N8N → Qdrant API calls |
| Ollama | Internal only | `internal` | N8N → Ollama API calls |

### IAM Permissions

The module automatically configures IAM permissions:

1. **Cloud Run Service Accounts**: Each service has its own service account
2. **Storage Access**: All services have read/write access to the shared GCS bucket
3. **Database Access**: N8N service account has access to Cloud SQL instance
4. **Service-to-Service**: Internal services are accessible via VPC connector

## Monitoring and Health Checks

All services include:

- **Startup Probes**: Ensure services start correctly
  - Initial delay: 15-20 seconds
  - Failure threshold: 10 attempts

- **Health Checks**: Monitor service health
  - Check interval: 10-30 seconds
  - Failure threshold: 3 attempts

- **Uptime Monitoring**: Google Cloud Monitoring checks (if enabled)
  - Qdrant: `/readyz` endpoint
  - Ollama: `/` endpoint
  - N8N: `/healthz` endpoint

## Dependencies

This module depends on:

1. **WebApp Module**: All three services use the WebApp module
2. **Existing Infrastructure**:
   - GCP Project with billing enabled
   - VPC Network
   - Service Account with appropriate permissions
   - Cloud SQL API enabled
   - Cloud Run API enabled
   - Cloud Storage API enabled

## Service Startup Order

The module ensures correct startup order using Terraform dependencies:

```
1. Shared GCS Bucket
2. Qdrant & Ollama (parallel)
3. N8N (waits for Qdrant & Ollama via depends_on)
```

## Cost Considerations

Approximate monthly costs (us-central1 region):

| Service | Resources | Estimated Cost |
|---------|-----------|---------------|
| N8N Cloud Run | 2 CPU, 4Gi RAM, 1 instance | ~$35-50/month |
| Qdrant Cloud Run | 1 CPU, 2Gi RAM, 1 instance | ~$18-25/month |
| Ollama Cloud Run | 2 CPU, 4Gi RAM, 1 instance | ~$35-50/month |
| Cloud SQL PostgreSQL | db-custom-1-3840 | ~$50-70/month |
| GCS Storage | 10GB | ~$0.20-0.50/month |
| **Total** | | **~$138-195/month** |

**Cost Optimization Tips**:
- Use committed use discounts for Cloud Run
- Scale down resources in dev/staging environments
- Enable storage lifecycle policies to delete old data
- Use regional storage instead of multi-regional

## Troubleshooting

### N8N Can't Connect to Qdrant

**Check**:
1. Verify Qdrant service is running: Check Cloud Run console
2. Check service URL: `terraform output qdrant_url`
3. Review N8N environment variables: Ensure `QDRANT_URL` is set correctly
4. Check VPC connector: Ensure internal networking is configured

### N8N Can't Connect to Ollama

**Check**:
1. Verify Ollama service is running
2. Check Ollama has sufficient resources for model inference
3. Verify `OLLAMA_URL` environment variable in N8N
4. Check Ollama logs for model loading errors

### Shared Storage Issues

**Check**:
1. Verify bucket exists: `terraform output shared_bucket_name`
2. Check IAM permissions on bucket
3. Review GCS FUSE mount options in service.tf
4. Check service account permissions

### Database Connection Issues

**Check**:
1. Verify Cloud SQL instance exists and is running
2. Check Cloud SQL Unix socket mount in N8N service
3. Review database connection environment variables
4. Check Cloud SQL IAM permissions

## Migration from N8N_AI Module

If migrating from the original N8N_AI module:

1. **Backup Your Data**: Export N8N workflows and database
2. **Update Terraform**: Change module source to N8N_AI_WebApp
3. **Update Variables**: Variable names are compatible
4. **Apply Changes**: Run `terraform apply`
5. **Restore Data**: Import workflows and data if needed

## Limitations

1. **No Automatic Ollama Model Management**: Models must be manually pulled/managed
2. **Single Instance for Qdrant/Ollama**: No horizontal scaling (by design)
3. **Manual Service URL Wiring**: URLs are wired explicitly (not auto-discovered)
4. **No Built-in Backup**: Implement separate backup strategy for GCS bucket and database

## Future Enhancements

Potential improvements for future versions:

1. **Automatic Model Management**: Pre-pull Ollama models during deployment
2. **Advanced Monitoring**: Custom Prometheus metrics and dashboards
3. **Backup Integration**: Automated backup/restore for storage and database
4. **Service Mesh**: Enhanced service-to-service communication with Istio
5. **GPU Support**: GPU instances for Ollama to improve LLM performance

## Support

For issues or questions:

1. Check the troubleshooting section above
2. Review WebApp module documentation
3. Check Cloud Run logs in GCP Console
4. Review Terraform state: `terraform show`

## License

Copyright 2024 (c) Tech Equity Ltd - Apache License 2.0

## Version History

- **v1.0** (2026-01-20): Initial release
  - Three-service deployment (N8N, Qdrant, Ollama)
  - Shared GCS bucket storage
  - Service discovery via module outputs
  - Comprehensive monitoring and health checks
