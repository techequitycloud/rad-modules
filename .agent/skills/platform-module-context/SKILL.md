---
name: platform-module-context
description: Understand the GCP_Services module and how it configures Google Cloud services.
---

# Platform Module Context (GCP_Services)

The `modules/GCP_Services` module is responsible for setting up the shared foundational infrastructure on Google Cloud Platform. It does not deploy applications itself but prepares the environment for them.

## Core Responsibilities

GCP_Services provides the platform layer that all application modules depend on:

1.  **Network Infrastructure**: VPC networks, subnets, and connectivity
2.  **Database Services**: Managed Cloud SQL (MySQL and PostgreSQL)
3.  **Caching Services**: Memorystore for Redis
4.  **File Storage**: Filestore NFS shares
5.  **IAM Configuration**: Shared service accounts and permissions
6.  **Service Enablement**: Activates required GCP APIs

## Platform Module Rules (from AGENTS.md)

**Critical Governance**:

1.  **Independence**: Platform modules MUST be self-contained
    *   No dependencies on other modules via symlinks
    *   Can be deployed standalone
2.  **Granularity**: Separate resources into logical files
    *   `network.tf` for networking
    *   `mysql.tf` and `pgsql.tf` for databases
    *   `redis.tf` for caching
    *   `filestore.tf` for file storage
3.  **Explicit Outputs**: Export all resource IDs and connection details
    *   Required by dependent modules (CloudRunApp, Application modules)
    *   Must be comprehensive and well-documented

## Resource Organization

GCP_Services organizes infrastructure into logical files:

### Networking (`network.tf`)

**Resources Created**:
*   **VPC Network**: Private network for all resources
*   **Subnets**: Regional subnets with IP ranges
*   **Serverless VPC Access Connectors**: Allow Cloud Run to access VPC resources
*   **Private Service Connection**: Enable private IP for Cloud SQL
*   **Firewall Rules**: Control traffic between resources

**Key Configurations**:
```hcl
# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "${var.network_name}-vpc"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.network_name}-subnet"
  ip_cidr_range = "10.8.0.0/28"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# VPC Access Connector (for Cloud Run)
resource "google_vpc_access_connector" "connector" {
  name          = "${var.network_name}-connector"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.8.0.0/28"
  min_instances = 2
  max_instances = 10
}
```

**Outputs**:
*   `vpc_id`: VPC network ID
*   `subnet_id`: Subnet ID
*   `vpc_connector_id`: Full connector ID for Cloud Run (e.g., `projects/PROJECT/locations/REGION/connectors/NAME`)
*   `vpc_connector_name`: Connector name only

### Databases

#### MySQL (`mysql.tf`)

**Resources Created**:
*   Cloud SQL MySQL instances (version 8.0)
*   Databases within instances
*   User accounts
*   Backup configuration
*   High availability settings

**Key Configurations**:
```hcl
resource "google_sql_database_instance" "mysql" {
  name             = "${var.instance_name}-mysql"
  database_version = "MYSQL_8_0"
  region           = var.region

  settings {
    tier              = var.db_tier  # e.g., db-custom-1-3840
    availability_type = "REGIONAL"   # HA configuration
    disk_size         = var.disk_size
    disk_type         = "PD_SSD"

    backup_configuration {
      enabled            = true
      start_time         = "03:00"
      binary_log_enabled = true
    }

    ip_configuration {
      ipv4_enabled    = false  # No public IP
      private_network = google_compute_network.vpc.id
    }
  }
}

resource "google_sql_database" "mysql_db" {
  name     = var.database_name
  instance = google_sql_database_instance.mysql.name
}

resource "google_sql_user" "mysql_user" {
  name     = var.db_user
  instance = google_sql_database_instance.mysql.name
  password = random_password.mysql_password.result
}
```

**Outputs**:
*   `mysql_instance_connection_name`: Connection string
*   `mysql_private_ip`: Private IP address
*   `mysql_instance_name`: Instance name
*   `mysql_database_name`: Database name
*   `mysql_user`: Database username

#### PostgreSQL (`pgsql.tf`)

**Resources Created**:
*   Cloud SQL PostgreSQL instances (version 15)
*   Databases within instances
*   User accounts
*   Extension configuration
*   Backup configuration

**Key Configurations**:
```hcl
resource "google_sql_database_instance" "postgres" {
  name             = "${var.instance_name}-pgsql"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier              = var.db_tier
    availability_type = "REGIONAL"
    disk_size         = var.disk_size
    disk_type         = "PD_SSD"

    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }
  }
}
```

**Extension Support**:
*   Extensions installed via application module initialization jobs
*   Common extensions: `pg_trgm`, `unaccent`, `uuid-ossp`, `postgis`

**Outputs**:
*   `postgres_instance_connection_name`: Connection string
*   `postgres_private_ip`: Private IP address
*   `postgres_instance_name`: Instance name
*   `postgres_database_name`: Database name
*   `postgres_user`: Database username

### Redis (`redis.tf`)

**Resources Created**:
*   Memorystore for Redis instances
*   Private IP allocation
*   Persistence configuration
*   Memory tier selection

**Key Configurations**:
```hcl
resource "google_redis_instance" "redis" {
  name           = "${var.instance_name}-redis"
  tier           = var.redis_tier  # "BASIC" or "STANDARD_HA"
  memory_size_gb = var.redis_memory_size_gb

  region                  = var.region
  authorized_network      = google_compute_network.vpc.id
  connect_mode            = "PRIVATE_SERVICE_ACCESS"
  redis_version           = "REDIS_7_0"
  display_name            = "${var.instance_name} Redis"
  reserved_ip_range       = var.redis_reserved_ip_range

  # Persistence (only available on STANDARD_HA tier)
  persistence_config {
    persistence_mode    = "RDB"
    rdb_snapshot_period = "ONE_HOUR"
  }
}
```

**Tiers**:
*   **BASIC**: Single-zone, no high availability
*   **STANDARD_HA**: Multi-zone, automatic failover, persistence

**Outputs**:
*   `redis_host`: Private IP address
*   `redis_port`: Port (usually 6379)
*   `redis_connection_string`: Full connection string (`redis://host:port`)
*   `redis_instance_id`: Instance ID

### Storage (`filestore.tf`)

**Resources Created**:
*   Filestore NFS instances
*   File shares
*   Tier selection (performance vs. cost)

**Key Configurations**:
```hcl
resource "google_filestore_instance" "nfs" {
  name     = "${var.instance_name}-nfs"
  location = var.region
  tier     = var.filestore_tier  # BASIC_HDD, BASIC_SSD, etc.

  file_shares {
    capacity_gb = var.filestore_capacity_gb
    name        = "vol1"
  }

  networks {
    network = google_compute_network.vpc.name
    modes   = ["MODE_IPV4"]
  }
}
```

**Tiers and Use Cases**:

| Tier | Performance | Use Case | Cost |
|------|-------------|----------|------|
| BASIC_HDD | Up to 100 MB/s | Development, low-traffic apps | Low |
| BASIC_SSD | Up to 480 MB/s | Production apps, moderate traffic | Medium |
| HIGH_SCALE_SSD | Up to 1,200 MB/s | High-traffic, performance-critical | High |
| ENTERPRISE | Up to 1,600 MB/s | Mission-critical, compliance | Highest |

**Outputs**:
*   `nfs_server`: NFS server IP address
*   `nfs_path`: File share path (usually `/vol1`)
*   `nfs_connection_string`: Full connection (`SERVER:/vol1`)

### IAM (`sa.tf`, `iam.tf`)

**Resources Created**:
*   Shared service accounts for common operations
*   Project-level IAM bindings
*   Service API enablement

**Key Configurations**:
```hcl
# Shared service account for infrastructure management
resource "google_service_account" "infrastructure_sa" {
  account_id   = "${var.project_id}-infra-sa"
  display_name = "Infrastructure Management Service Account"
}

# Grant necessary permissions
resource "google_project_iam_member" "infra_sa_compute_admin" {
  project = var.project_id
  role    = "roles/compute.admin"
  member  = "serviceAccount:${google_service_account.infrastructure_sa.email}"
}
```

**Enabled Services**:
*   `compute.googleapis.com` - Compute Engine
*   `servicenetworking.googleapis.com` - Private Service Connect
*   `sqladmin.googleapis.com` - Cloud SQL
*   `redis.googleapis.com` - Memorystore
*   `file.googleapis.com` - Filestore
*   `vpcaccess.googleapis.com` - Serverless VPC Access

## Usage Pattern

GCP_Services is deployed **before** application modules:

### Deployment Order

```
1. GCP_Services
   ↓ Creates infrastructure
2. CloudRunApp / Application Modules
   ↓ Consume outputs
3. Applications deployed
```

### Output Consumption

Application modules consume GCP_Services outputs:

```hcl
# In application module terraform.tfvars or variables
module "myapp" {
  source = "./modules/MyApp"

  # From GCP_Services outputs
  vpc_connector_id = module.gcp_services.vpc_connector_id
  sql_instance     = module.gcp_services.postgres_instance_connection_name
  redis_host       = module.gcp_services.redis_host
  redis_port       = module.gcp_services.redis_port
  nfs_server       = module.gcp_services.nfs_server

  # Application-specific config
  service_name     = "myapp"
  # ...
}
```

### Terraform Workflow

**Step 1: Deploy GCP_Services**:
```bash
cd modules/GCP_Services
terraform init
terraform plan -var-file=config/basic-gcp-services.tfvars
terraform apply -var-file=config/basic-gcp-services.tfvars
```

**Step 2: Capture Outputs**:
```bash
terraform output > ../outputs.txt
# Or use terraform_remote_state data source
```

**Step 3: Deploy Application**:
```bash
cd modules/MyApp
terraform init

# Reference GCP_Services outputs
terraform plan \
  -var="vpc_connector_id=$(terraform output -state=../GCP_Services/terraform.tfstate vpc_connector_id)" \
  -var-file=config/basic-myapp.tfvars

terraform apply
```

## Complete Outputs Reference

### Networking Outputs

```hcl
output "vpc_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "subnet_id" {
  description = "The ID of the subnet"
  value       = google_compute_subnetwork.subnet.id
}

output "vpc_connector_id" {
  description = "Full VPC Access Connector ID"
  value       = google_vpc_access_connector.connector.id
}

output "vpc_connector_name" {
  description = "VPC Access Connector name only"
  value       = google_vpc_access_connector.connector.name
}
```

### Database Outputs (MySQL)

```hcl
output "mysql_instance_connection_name" {
  description = "MySQL instance connection name"
  value       = google_sql_database_instance.mysql.connection_name
}

output "mysql_private_ip" {
  description = "MySQL instance private IP address"
  value       = google_sql_database_instance.mysql.private_ip_address
}

output "mysql_database_name" {
  description = "MySQL database name"
  value       = google_sql_database.mysql_db.name
}

output "mysql_user" {
  description = "MySQL username"
  value       = google_sql_user.mysql_user.name
  sensitive   = false
}

output "mysql_password_secret_id" {
  description = "Secret Manager ID for MySQL password"
  value       = google_secret_manager_secret.mysql_password.id
  sensitive   = true
}
```

### Database Outputs (PostgreSQL)

```hcl
output "postgres_instance_connection_name" {
  description = "PostgreSQL instance connection name"
  value       = google_sql_database_instance.postgres.connection_name
}

output "postgres_private_ip" {
  description = "PostgreSQL instance private IP address"
  value       = google_sql_database_instance.postgres.private_ip_address
}

output "postgres_database_name" {
  description = "PostgreSQL database name"
  value       = google_sql_database.postgres_db.name
}

output "postgres_user" {
  description = "PostgreSQL username"
  value       = google_sql_user.postgres_user.name
}
```

### Redis Outputs

```hcl
output "redis_host" {
  description = "Redis instance host (IP address)"
  value       = google_redis_instance.redis.host
}

output "redis_port" {
  description = "Redis instance port"
  value       = google_redis_instance.redis.port
}

output "redis_connection_string" {
  description = "Redis connection string"
  value       = "redis://${google_redis_instance.redis.host}:${google_redis_instance.redis.port}"
}

output "redis_instance_id" {
  description = "Redis instance ID"
  value       = google_redis_instance.redis.id
}
```

### Filestore Outputs

```hcl
output "nfs_server" {
  description = "Filestore NFS server IP address"
  value       = google_filestore_instance.nfs.networks[0].ip_addresses[0]
}

output "nfs_path" {
  description = "Filestore file share path"
  value       = "/vol1"
}

output "nfs_connection_string" {
  description = "Full NFS mount connection string"
  value       = "${google_filestore_instance.nfs.networks[0].ip_addresses[0]}:/vol1"
}
```

## Dependency Flow

Understanding how outputs flow from GCP_Services to applications:

```
┌────────────────────────────────────┐
│        GCP_Services Module         │
│                                    │
│  ┌──────────────────────────────┐ │
│  │  network.tf                  │ │
│  │  - VPC, Subnets              │ │
│  │  - VPC Connector             │ │
│  └──────────┬───────────────────┘ │
│             │ outputs              │
│             ↓                      │
│  ┌──────────────────────────────┐ │
│  │  pgsql.tf / mysql.tf         │ │
│  │  - Cloud SQL Instances       │ │
│  │  - Databases, Users          │ │
│  └──────────┬───────────────────┘ │
│             │ outputs              │
│             ↓                      │
│  ┌──────────────────────────────┐ │
│  │  redis.tf                    │ │
│  │  - Memorystore Redis         │ │
│  └──────────┬───────────────────┘ │
│             │ outputs              │
│             ↓                      │
│  ┌──────────────────────────────┐ │
│  │  filestore.tf                │ │
│  │  - NFS Shares                │ │
│  └──────────┬───────────────────┘ │
└─────────────┼────────────────────┘
              │
              ↓
    ┌─────────────────────┐
    │  Output Variables   │
    │  - vpc_connector_id │
    │  - sql_instance     │
    │  - redis_host       │
    │  - nfs_server       │
    └─────────┬───────────┘
              │
              ↓
┌─────────────────────────────────────┐
│    CloudRunApp / App Modules        │
│                                     │
│  Uses outputs to configure:         │
│  - VPC Access (networking)          │
│  - Database connections (sql)       │
│  - Cache connections (redis)        │
│  - File storage mounts (nfs)        │
└─────────────────────────────────────┘
```

## Configuration Examples

### Basic Configuration

**File**: `config/basic-gcp-services.tfvars`

```hcl
project_id = "my-gcp-project"
region     = "us-central1"

# Networking
network_name           = "my-network"
subnet_cidr            = "10.8.0.0/28"
vpc_connector_cidr     = "10.8.0.0/28"

# PostgreSQL
enable_postgres        = true
postgres_tier          = "db-custom-1-3840"  # 1 vCPU, 3.75 GB RAM
postgres_disk_size     = 10
postgres_database_name = "app_db"
postgres_user          = "app_user"

# Redis
enable_redis           = true
redis_tier             = "BASIC"
redis_memory_size_gb   = 1

# Filestore
enable_filestore       = false
```

### Advanced Configuration

**File**: `config/advanced-gcp-services.tfvars`

```hcl
project_id = "my-gcp-project"
region     = "us-central1"

# Networking with multiple subnets
network_name       = "production-network"
subnet_cidr        = "10.8.0.0/24"
vpc_connector_cidr = "10.8.0.0/28"

# High-availability PostgreSQL
enable_postgres         = true
postgres_tier           = "db-custom-4-15360"  # 4 vCPU, 15 GB RAM
postgres_disk_size      = 100
postgres_availability   = "REGIONAL"  # HA configuration
postgres_backup_enabled = true
postgres_pitr_enabled   = true  # Point-in-time recovery

# High-availability Redis with persistence
enable_redis           = true
redis_tier             = "STANDARD_HA"  # Multi-zone HA
redis_memory_size_gb   = 5
redis_persistence      = true

# High-performance Filestore
enable_filestore       = true
filestore_tier         = "BASIC_SSD"
filestore_capacity_gb  = 1024

# MySQL for legacy applications
enable_mysql           = true
mysql_tier             = "db-custom-2-7680"
mysql_disk_size        = 50
```

## Troubleshooting GCP_Services

### VPC Connector Issues

**Problem**: Cloud Run cannot connect to VPC resources

**Solution**:
1.  Verify VPC connector exists:
    ```bash
    gcloud compute networks vpc-access connectors list --region=us-central1
    ```
2.  Check IP range doesn't conflict:
    ```bash
    gcloud compute networks subnets list --network=my-network
    ```
3.  Ensure connector has capacity:
    ```bash
    gcloud compute networks vpc-access connectors describe CONNECTOR_NAME \
      --region=us-central1
    ```

### Cloud SQL Connection Failures

**Problem**: Cannot connect to Cloud SQL from Cloud Run

**Solution**:
1.  Verify private IP is configured:
    ```bash
    gcloud sql instances describe INSTANCE_NAME \
      --format="value(ipAddresses.ipAddress)"
    ```
2.  Check private service connection:
    ```bash
    gcloud services vpc-peerings list --network=my-network
    ```
3.  Verify VPC connector is attached to Cloud Run service
4.  Check database exists and user has permissions

### Redis Connection Issues

**Problem**: Cannot connect to Memorystore Redis

**Solution**:
1.  Verify Redis instance is in same VPC:
    ```bash
    gcloud redis instances describe INSTANCE_NAME --region=us-central1
    ```
2.  Check Redis IP is accessible from VPC connector subnet
3.  Verify firewall rules allow traffic
4.  Test connection from Cloud Shell in same VPC:
    ```bash
    redis-cli -h REDIS_IP ping
    ```

### Filestore Mount Failures

**Problem**: Cannot mount NFS share in Cloud Run

**Solution**:
1.  Verify Filestore instance is active:
    ```bash
    gcloud filestore instances describe INSTANCE_NAME \
      --location=us-central1
    ```
2.  Check network configuration allows NFS traffic
3.  Verify IP address is correct in mount configuration
4.  Check Cloud Run service has correct volume mount specification

### Permission Errors

**Problem**: "Permission denied" when creating resources

**Solution**:
1.  Verify required APIs are enabled:
    ```bash
    gcloud services list --enabled
    ```
2.  Enable missing services:
    ```bash
    gcloud services enable compute.googleapis.com
    gcloud services enable servicenetworking.googleapis.com
    gcloud services enable sqladmin.googleapis.com
    ```
3.  Check service account has necessary roles
4.  Verify quota is not exceeded:
    ```bash
    gcloud compute project-info describe --project=PROJECT_ID
    ```

### Resource Quota Issues

**Problem**: "Quota exceeded" errors

**Solution**:
1.  Check current quota usage:
    ```bash
    gcloud compute project-info describe --project=PROJECT_ID
    ```
2.  Request quota increase in GCP Console
3.  Use smaller instance sizes for development
4.  Clean up unused resources

## Best Practices

### Security

1.  **No Public IPs**: Always use private IPs for databases and Redis
2.  **VPC Isolation**: Keep resources in private VPC
3.  **Firewall Rules**: Implement least-privilege access
4.  **Secret Management**: Store passwords in Secret Manager
5.  **IAM Separation**: Use separate service accounts for different purposes

### Cost Optimization

1.  **Right-Sizing**: Choose appropriate tiers for your workload
2.  **Development Tiers**: Use BASIC tiers for dev/test
3.  **Auto-Scaling**: Use VPC connector auto-scaling
4.  **Backups**: Configure retention policies to avoid excessive storage costs
5.  **Monitoring**: Set up billing alerts

### High Availability

1.  **Regional Deployment**: Use REGIONAL availability for Cloud SQL
2.  **HA Redis**: Use STANDARD_HA tier for production
3.  **Backup Configuration**: Enable automated backups and PITR
4.  **Multi-Zone**: Distribute resources across zones
5.  **Disaster Recovery**: Plan for region failover

### Performance

1.  **Proper Sizing**: Provision adequate CPU and memory
2.  **SSD Storage**: Use SSD for better database performance
3.  **Connection Pooling**: Implement pooling for Cloud SQL
4.  **Redis Tier**: Use STANDARD_HA for better performance
5.  **VPC Connector Sizing**: Ensure adequate throughput capacity
