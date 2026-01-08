# Tutorial: Cloud Run Services (service.tf)

## Overview
The `service.tf` file defines the main application workload using **Cloud Run**. It describes the container image, resource limits, environment variables, and connections to other services (SQL, Storage).

## Standard Pattern
We use `google_cloud_run_v2_service` (Gen2) as the standard resource. It typically includes:
- **Template**: The container definition.
- **Env Vars**: Injected from Secret Manager (`value_source`) or plain text.
- **VPC Access**: Direct VPC egress to reach private Cloud SQL IPs and NFS servers.
- **Volume Mounts**: For Cloud SQL sockets and shared NFS storage.

## Implementation Example

```hcl
resource "google_cloud_run_v2_service" "app_service" {
  name     = "app-${var.application_name}"
  location = local.region
  ingress  = "INGRESS_TRAFFIC_ALL" # or INTERNAL_ONLY

  template {
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2" # Required for NFS
    service_account       = local.cloud_run_sa_email

    containers {
      image = "gcr.io/my-project/my-app:latest"

      # Secret Environment Variable
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }

      # NFS Mount
      volume_mounts {
        name       = "nfs-shared"
        mount_path = "/var/www/html/data"
      }
    }

    # NFS Volume Definition
    volumes {
      name = "nfs-shared"
      nfs {
        server    = local.nfs_server_ip
        path      = "/var/nfs/data"
        read_only = false
      }
    }

    vpc_access {
      network_interfaces {
        network    = var.network_name
        subnetwork = "default" # or specific subnet
      }
    }
  }
}
```

## Best Practices & Recommendations

### 1. Gen2 Execution Environment
**Recommendation**: Always set `execution_environment = "EXECUTION_ENVIRONMENT_GEN2"`.
**Why**: Generation 1 does not support NFS volume mounts. Gen2 provides full Linux compatibility which is required for most complex legacy apps.

### 2. Secret Manager Integration
**Recommendation**: Never pass sensitive data (API keys, DB passwords) in `env { value = "..." }`. Use `value_source` with Secret Manager.
**Why**: Plain text environment variables are visible in the Cloud Console and Terraform state.

### 3. Explicit Dependencies
**Recommendation**: Use `depends_on` for IAM and Secrets.
**Why**: Cloud Run will fail to start if the Service Account doesn't _yet_ have permission to access the referenced Secret.

### 4. VPC Access
**Recommendation**: Configure Direct VPC Egress (`vpc_access`).
**Why**: It is more performant and cheaper than the legacy "Serverless VPC Access Connector".
