---
name: terraform-module-implementation
description: Guide for implementing Terraform Application Modules using the CloudRunApp wrapper pattern.
---

# Terraform Module Implementation Skill

This skill details how to implement new Application Modules in this repository. These modules act as wrappers around the foundational `CloudRunApp` module, reusing its core logic while defining application-specific configurations.

## 1. Overview & The Wrapper Pattern

The repository uses a "Wrapper Pattern" for Application Modules.
- **Foundation**: `modules/CloudRunApp` contains the core Terraform logic (services, IAM, networking, storage, etc.).
- **Wrapper**: Each Application Module (e.g., `modules/Odoo`, `modules/Wordpress`) symlinks to the core files in `CloudRunApp`.
- **Configuration**: The wrapper defines its specific logic in a local `.tf` file (e.g., `odoo.tf`) by setting `local.application_modules`.

**Benefits:**
- Consistent infrastructure across all apps.
- Single point of maintenance for core logic.
- Rapid creation of new modules.

## 2. Directory Structure

A standard Application Module should look like this:

```
modules/MyModule/
├── main.tf -> ../CloudRunApp/main.tf
├── variables.tf                 # Module-specific variables (Copy from template)
├── mymodule.tf                  # MAIN CONFIGURATION FILE (Local logic)
├── scripts/
│   └── mymodule/
│       ├── Dockerfile           # If building a custom image
│       └── ...                  # Other helper scripts
├── config/                      # Configuration templates (e.g., nginx.conf, php.ini)
│   └── ...
├── .gitignore
├── README.md
├── MYMODULE.md                  # Detailed documentation
└── [Symlinks to CloudRunApp]    # See list below
```

**Required Symlinks:**
Ensure these point to `../CloudRunApp/`:
- `buildappcontainer.tf`, `iam.tf`, `jobs.tf`, `main.tf`, `modules.tf`, `monitoring.tf`, `network.tf`, `nfs.tf`, `outputs.tf`, `provider-auth.tf`, `registry.tf`, `sa.tf`, `secrets.tf`, `service.tf`, `sql.tf`, `storage.tf`, `trigger.tf`, `versions.tf`

**Note:** `variables.tf` is **NOT** a symlink. It must be a local file.

## 3. Module Configuration (`<module_name>.tf`)

This file is the heart of the module. It must define a `locals` block with specific keys that `CloudRunApp` expects.

### Required Locals

```hcl
locals {
  # 1. Define the module configuration
  mymodule_module = {
    app_name                = "mymodule"
    application_version     = var.application_version
    display_name            = "My Module Display Name"
    description             = "Description of what this module does"

    # Container Image Config
    container_image         = "repo/image"  # Base image name
    image_source            = "custom"      # "custom" (build local) or "prebuilt" (pull public)

    # Build Config (if image_source = "custom")
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "mymodule"       # Maps to scripts/mymodule/
      build_args         = {
         SOME_ARG = "value"
      }
    }

    container_port          = 8080

    # Database Config
    database_type           = "POSTGRES_15" # NONE, MYSQL_8_0, POSTGRES_15, SQLSERVER_2019_STANDARD
    db_name                 = "mydb"
    db_user                 = "myuser"
    enable_cloudsql_volume  = true          # Mount Cloud SQL via Unix socket
    cloudsql_volume_mount_path = "/cloudsql"

    # Storage Config
    nfs_enabled             = true
    nfs_mount_path          = "/mnt"

    gcs_volumes = [
      {
        name          = "my-data"
        mount_path    = "/data"
        read_only     = false
      }
    ]

    # Resources
    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "512Mi"
    }

    # Initialization Jobs (Cloud Run Jobs)
    initialization_jobs = [
      {
        name        = "init-db"
        description = "Initialize database"
        command     = ["/bin/sh", "-c"]
        args        = ["./init.sh"]
        mount_nfs   = true
        execute_on_apply = true
      }
    ]
  }

  # 2. Register the module
  application_modules = {
    mymodule = local.mymodule_module
  }

  # 3. Define Environment Variables (Static + Secrets)
  module_env_vars = {
    DB_HOST = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/..." : local.db_internal_ip
  }

  module_secret_env_vars = {
    ADMIN_PASS = try(google_secret_manager_secret.admin_pass.secret_id, "")
  }

  # 4. Define Storage Buckets
  module_storage_buckets = []
}
```

## 4. Variables & UIMeta (Standard Order)

Variables in `variables.tf` must follow the "Standard Order" and include `UIMeta` annotations for the platform UI.

| Group ID | Name | Description |
| :--- | :--- | :--- |
| **0** | Metadata | Module description, documentation links |
| **100** | Basic | Enable flags, public access, basic settings |
| **200** | Project | Project ID, Region, Tenant ID |
| **300** | Application | Version, specific app settings |
| **400** | CI/CD | GitHub repo, triggers |
| **500** | Env Vars | Custom environment variables |
| **600** | Health | Probes (startup, liveness) |
| **700** | Monitoring | Alerts, trusted users |
| **800** | Init Jobs | Custom job configs |
| **900** | Network | VPC, Ingress settings |
| **1000** | DB/Backup | Passwords, Backup config |

**Example:**
```hcl
variable "module_description" {
  description = "The description of the module. {{UIMeta group=0 order=100 }}"
  type        = string
  default     = "This module deploys MyModule"
}
```

## 5. Scripts & Docker

- Place Dockerfiles and scripts in `scripts/<module_name>/`.
- In `<module_name>.tf`, set `context_path = "<module_name>"` in `container_build_config`.
- This ensures Kaniko builds relative to `scripts/<module_name>/` but can access the root if needed (though typically restricted).

## 6. Creation Process

**Recommended:** Use the helper script to verify prerequisites and clone a base module.

1.  Run `./scripts/create_module.sh`.
2.  Select a similar existing module to clone (e.g., `Odoo` if you need DB + NFS).
3.  Enter the new module name.
4.  The script will:
    -   Clone the directory.
    -   Rename files (`Old.tf` -> `New.tf`).
    -   Replace internal strings.
    -   Setup symlinks.
5.  Edit `modules/NewModule/newmodule.tf` to customize logic.
6.  Edit `modules/NewModule/variables.tf` to update metadata.

## 7. Troubleshooting & Debugging

### A. Database Connection Issues

**Symptom**: Application cannot connect to Cloud SQL database

**Common Causes & Solutions**:
1. **Unix Socket vs TCP**: Check `enable_cloudsql_volume` setting
   - Unix Socket (recommended): `enable_cloudsql_volume = true`
   - TCP Connection: `enable_cloudsql_volume = false` (Cyclos pattern)
   - Verify `DB_HOST` environment variable matches connection type

2. **PostgreSQL Extensions**: If using `enable_postgres_extensions = true`
   - Check initialization job logs: `gcloud run jobs describe init-db-extensions`
   - Verify extensions list matches app requirements
   - Common extensions: pg_trgm, uuid-ossp, postgis, cube, earthdistance

3. **Database User Creation**: Check `create-user` job status
   - Log location: Cloud Run Jobs > Executions > Logs
   - Verify Secret Manager has `db_password` secret

**Debugging Commands**:
```bash
# View initialization job logs
gcloud run jobs executions list --job=<tenant>-<app>-init-db-extensions

# Test database connection from Cloud Shell
gcloud sql connect <instance-name> --user=<db_user>

# Check secret exists
gcloud secrets describe <tenant>-<app>-db-password
```

### B. Storage & NFS Issues

**Symptom**: Application cannot write to mounted volumes

**Common Causes & Solutions**:
1. **NFS Mount Permissions**:
   - Check nfs-setup job succeeded: `gcloud run jobs describe nfs-setup`
   - Verify mount path matches: `/mnt` (default) vs custom path
   - NFS server must exist in same region (created by GCP_Services module)

2. **GCS FUSE Configuration**:
   - Verify bucket exists and SA has `storage.objectAdmin` role
   - Check mount_options: `["implicit-dirs", "metadata-cache-ttl-secs=60"]`
   - GCS FUSE limitations: No POSIX file locking, eventual consistency

3. **Volume Mount Conflicts**:
   - CloudSQL volume: `/cloudsql`
   - NFS volume: `/mnt` (configurable)
   - GCS volumes: User-defined paths
   - Ensure no path overlaps

**Debugging Commands**:
```bash
# Check NFS server status
gcloud filestore instances list --region=<region>

# Verify bucket exists and permissions
gsutil ls -L gs://<bucket-name>

# Check Cloud Run service mounts
gcloud run services describe <service-name> --format=json | jq '.spec.template.spec.volumes'
```

### C. Initialization Jobs Failures

**Symptom**: Deployment succeeds but application doesn't work correctly

**Common Causes & Solutions**:
1. **Job Execution Order**: Jobs run in dependency order via `run_ordered_jobs.py`
   - Check job dependencies in `<app>.tf` initialization_jobs
   - View execution order: `modules/CloudRunApp/scripts/core/run_ordered_jobs.py`

2. **Environment Variable Injection**:
   - Jobs inherit `module_env_vars` and `module_secret_env_vars`
   - Secret Manager secrets must exist before job execution
   - Use `execute_on_apply = false` to skip automatic execution

3. **Script Permissions**:
   - Entrypoint scripts must be executable: `chmod +x script.sh`
   - In Dockerfile: `RUN chmod +x /path/to/script.sh`

**Debugging Commands**:
```bash
# List all job executions
gcloud run jobs executions list --job=<job-name>

# View specific execution logs
gcloud run jobs executions logs <execution-name>

# Manually trigger a job
gcloud run jobs execute <job-name>
```

### D. Container Build Failures

**Symptom**: Cloud Build fails or image doesn't work

**Common Causes & Solutions**:
1. **Context Path Issues**: Kaniko builds relative to `scripts/<module_name>/`
   - Set `context_path = "<module_name>"` in `container_build_config`
   - Dockerfile must be in `scripts/<module_name>/Dockerfile`
   - Cannot access files outside context (security restriction)

2. **Build Arguments**:
   - Pass via `build_args = { KEY = "value" }`
   - In Dockerfile: `ARG KEY` then use `$KEY`
   - Build args are visible in logs (don't use for secrets)

3. **Dockerfile CMD Issues** (Critical):
   - Verify CMD points to production entrypoint, not debug script
   - Example bug: Medusa Dockerfile CMD points to `start-dev.sh`
   - Test locally: `docker run <image> /bin/sh -c 'cat /entrypoint.sh'`

**Debugging Commands**:
```bash
# View Cloud Build logs
gcloud builds list --limit=5
gcloud builds log <build-id>

# Test image locally
docker pull <artifact-registry-url>/<image>:<tag>
docker run -it <image> /bin/sh
```

### E. Networking Issues

**Symptom**: Cannot access Cloud SQL, Redis, or service is not accessible

**Common Causes & Solutions**:
1. **VPC Egress Configuration**:
   - Direct VPC Egress (recommended): Uses `network_interfaces`
   - VPC Access Connector (legacy): Uses separate connector resource
   - Check: `modules/CloudRunApp/network.tf` for current implementation

2. **Public Access**:
   - Default: `roles/run.invoker` granted to `allUsers`
   - Restrict: Set `public_access = false` (if variable implemented)
   - Verify: `gcloud run services get-iam-policy <service-name>`

3. **Ingress Settings**:
   - Default: `INGRESS_TRAFFIC_ALL`
   - Internal only: `INGRESS_TRAFFIC_INTERNAL_ONLY`
   - Load Balancer: `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`

**Debugging Commands**:
```bash
# Check VPC network exists
gcloud compute networks describe <network-name>

# Verify subnet
gcloud compute networks subnets describe <subnet-name> --region=<region>

# Test connectivity from Cloud Shell
curl https://<cloud-run-url>
```

## 8. Maintenance & Updates

### A. Updating Application Version

**Standard Update Process**:
1. Update `application_version` variable in tfvars
2. If using custom image:
   - Update Dockerfile or application code
   - Commit changes (triggers Cloud Build if CI/CD enabled)
3. Run `terraform plan` to review changes
4. Run `terraform apply`
5. Monitor new revision deployment

**Zero-Downtime Updates**:
- Cloud Run automatically does gradual rollout
- Keep `min_instance_count = 0` for scale-to-zero between deployments
- Set `min_instance_count = 1` for high-availability apps (e.g., Wordpress)

### B. Updating Module Configuration

**Safe Update Process**:
1. Read current state: `terraform show`
2. Make incremental changes to `<app>.tf`
3. Run `terraform plan` and review:
   - Green `+` : New resources (safe)
   - Yellow `~` : Updates (review carefully)
   - Red `-/+` : Replacements (potential downtime)
   - Red `-` : Deletions (data loss risk)
4. For destructive changes, backup first (see section C)

**High-Risk Changes** (require extra caution):
- Database type change: Requires migration
- NFS path change: May lose data
- CloudSQL volume toggle: Changes connection method
- Min/max instance count: Affects availability

### C. Backup & Restore Procedures

**Database Backup**:
```bash
# Export Cloud SQL database
gcloud sql export sql <instance-name> gs://<bucket>/backup-$(date +%Y%m%d).sql \
  --database=<db-name>

# Import backup (during initialization)
# Set in tfvars:
# backup_import_enabled = true
# backup_gcs_uri = "gs://<bucket>/backup-20240204.sql"
```

**NFS Backup**:
```bash
# From Cloud Shell with NFS mounted
gcloud filestore instances describe <nfs-instance>
# Manual backup: copy files from /mnt to GCS
gsutil -m rsync -r /mnt gs://<bucket>/nfs-backup/
```

**Configuration Backup**:
- Always commit tfvars to version control
- Store in separate repo (not public)
- Use terraform state remote backend (GCS recommended)

### D. Module Dependency Updates

**CloudRunApp Updates** (affects all application modules):
1. Test changes in `modules/Sample` first
2. Review changes in `modules/CloudRunApp/CHANGELOG.md` (if exists)
3. Update one application module at a time
4. Verify symlinks are intact: `./scripts/create_module.sh` validation mode

**GCP_Services Updates** (affects all modules):
1. **CRITICAL**: Never destroy VPC or NFS without full backup
2. Changes here affect all deployed applications
3. Plan in production-like environment first
4. Consider maintenance window for networking changes

### E. Monitoring & Health Checks

**Key Metrics to Monitor**:
1. **Cloud Run**:
   - Request count, latency, error rate
   - Instance count (check auto-scaling)
   - Cold start times
2. **Cloud SQL**:
   - CPU utilization (>80% = resize needed)
   - Connection count (check connection pooling)
   - Storage utilization
3. **Initialization Jobs**:
   - Last execution status
   - Execution duration trends

**Accessing Logs**:
```bash
# Cloud Run service logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=<service>" --limit=50

# Cloud SQL logs
gcloud logging read "resource.type=cloudsql_database" --limit=50

# Initialization job logs
gcloud run jobs executions logs <execution-name>
```

### F. Cost Optimization

**Resource Right-Sizing**:
1. **CPU/Memory**: Start with defaults, monitor for 1 week
   - Over-provisioned: Low utilization (<30%)
   - Under-provisioned: High latency, throttling
2. **Instance Scaling**:
   - `min_instance_count = 0`: Maximum savings (recommended)
   - `min_instance_count = 1`: Eliminates cold starts (+$15-30/month)
3. **Database Sizing**:
   - Start with `db-f1-micro` or `db-g1-small`
   - Monitor CPU and upgrade only when needed
4. **Storage**:
   - Enable GCS lifecycle policies for old data
   - Use Nearline/Coldline storage for backups

**Cost Monitoring**:
```bash
# Estimate monthly cost (rough)
gcloud billing accounts list
# Use GCP Pricing Calculator: https://cloud.google.com/products/calculator
```

## 9. Testing & Validation

### A. Pre-Deployment Validation

**Terraform Validation**:
```bash
# Syntax check
terraform validate

# Check formatting
terraform fmt -check

# Security scan (optional, requires tfsec)
tfsec .

# Plan without applying
terraform plan -out=plan-output.tfplan
```

**Module Consistency Check**:
```bash
# Verify symlinks
find . -type l -exec test ! -e {} \; -print

# Check for required files
ls -la main.tf variables.tf <app>.tf README.md

# Verify scripts directory
ls -la scripts/<module_name>/
```

### B. Post-Deployment Validation

**Service Health Check**:
```bash
# Verify service is running
gcloud run services describe <service-name> --format=json | jq '.status.conditions'

# Check URL accessibility
curl -I https://<cloud-run-url>

# View recent logs
gcloud run services logs read <service-name> --limit=20
```

**Database Connectivity Check**:
```bash
# Connect to Cloud SQL
gcloud sql connect <instance-name> --user=<db-user>

# Verify database exists
\l  # (in psql)
SHOW DATABASES;  # (in mysql)
```

**Initialization Jobs Verification**:
```bash
# List all jobs
gcloud run jobs list

# Check last execution status
gcloud run jobs executions list --job=<job-name> --limit=1

# View execution logs
gcloud run jobs executions logs <execution-name>
```

### C. Performance Testing

**Load Testing** (optional):
```bash
# Simple load test with Apache Bench
ab -n 1000 -c 10 https://<cloud-run-url>/

# Monitor during test
watch -n 1 'gcloud run services describe <service> --format="value(status.traffic[0].latestRevision)"'
```

**Database Performance**:
```bash
# Check query performance (PostgreSQL)
psql -h <host> -U <user> -d <db> -c "SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"

# Connection pooling status
psql -h <host> -U <user> -d <db> -c "SELECT count(*) FROM pg_stat_activity;"
```

## 10. Quick Reference

### A. Common Variable Patterns

**Database Configuration**:
```hcl
database_type = "POSTGRES_15"  # MYSQL_8_0, SQLSERVER_2019_STANDARD, NONE
enable_cloudsql_volume = true  # Unix socket (recommended) or false for TCP
enable_postgres_extensions = true
postgres_extensions = ["pg_trgm", "uuid-ossp"]
```

**Storage Configuration**:
```hcl
nfs_enabled = true
nfs_mount_path = "/mnt"
gcs_volumes = [
  { name = "data", mount_path = "/data", read_only = false }
]
```

**Resource Configuration**:
```hcl
container_resources = {
  cpu_limit = "1000m"     # 1 vCPU (250m, 500m, 1000m, 2000m, 4000m)
  memory_limit = "512Mi"  # 512 MB (128Mi, 256Mi, 512Mi, 1Gi, 2Gi, 4Gi, 8Gi)
}
min_instance_count = 0    # Scale-to-zero (cost optimization)
max_instance_count = 3    # Max auto-scale
```

### B. File Path Reference

**Module Structure**:
- Configuration: `modules/<Module>/<module>.tf`
- Variables: `modules/<Module>/variables.tf` (NOT symlinked)
- Scripts: `modules/<Module>/scripts/<module>/`
- Config templates: `modules/<Module>/config/`
- Documentation: `modules/<Module>/README.md` and `<MODULE>.md`

**Shared Resources**:
- Foundation: `modules/CloudRunApp/` (all core logic)
- Shared scripts: `modules/CloudRunApp/scripts/core/`
- Platform: `modules/GCP_Services/` (VPC, NFS, Redis)

### C. Important Command Reference

```bash
# Module creation
./scripts/create_module.sh

# Terraform workflow
terraform init
terraform plan -var-file="config/basic-<app>.tfvars"
terraform apply -var-file="config/basic-<app>.tfvars"
terraform destroy -var-file="config/basic-<app>.tfvars"

# Cloud Run management
gcloud run services list
gcloud run services describe <service-name>
gcloud run services logs read <service-name>

# Cloud Run Jobs
gcloud run jobs list
gcloud run jobs execute <job-name>
gcloud run jobs executions list --job=<job-name>
gcloud run jobs executions logs <execution-name>

# Cloud SQL management
gcloud sql instances list
gcloud sql connect <instance-name> --user=<user>
gcloud sql export sql <instance-name> gs://<bucket>/backup.sql

# Debugging
gcloud logging read "resource.type=cloud_run_revision" --limit=50
gcloud builds list --limit=5
gcloud builds log <build-id>
```

### D. Decision Matrix

**When to use Unix Socket vs TCP for Cloud SQL**:
- ✅ Unix Socket (`enable_cloudsql_volume = true`): Default, lower latency, more secure
- ⚠️ TCP (`enable_cloudsql_volume = false`): Required for some apps (Cyclos), connection pooling tools

**When to use NFS vs GCS FUSE**:
- ✅ NFS: Fast, POSIX-compliant, good for frequent small writes
- ⚠️ GCS FUSE: Scalable, cost-effective, good for large files, eventual consistency

**When to enable custom image building**:
- ✅ Custom (`image_source = "custom"`): Application needs customization, proprietary code
- ⚠️ Prebuilt (`image_source = "prebuilt"`): Using official Docker image (e.g., cyclos/cyclos:4)

**When to scale to zero**:
- ✅ `min_instance_count = 0`: Development, staging, cost-sensitive production
- ⚠️ `min_instance_count = 1`: Production apps requiring instant response, stateful sessions
