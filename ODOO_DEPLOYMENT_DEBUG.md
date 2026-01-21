# Odoo Deployment Issue - Database Connection Port Error

## Issue Summary
Odoo deployment fails with the following error:
```
Database connection failure: connection to server at "10.171.0.5", port 8069 failed: Connection timed out
```

## Root Cause
The Odoo container is attempting to connect to PostgreSQL on port **8069** (Odoo's HTTP port) instead of port **5432** (PostgreSQL's standard port). This happens when the `DB_PORT` and `PGPORT` environment variables are not properly set in the Cloud Run service configuration.

## Timeline of Fixes
1. **Commit 58877ab** (Jan 21, 17:25 GMT) - Added `DB_PORT` and `PGPORT` to WebApp/main.tf odoo preset
2. **Commit 4130063** (Jan 21, 18:09 GMT) - Fixed standalone Odoo module (modules/Odoo)
3. **Error logs** (Jan 21, 18:39 GMT) - Deployment still failing with port 8069

## Current Code Status
The fix is **ALREADY in place** in the codebase:

### File: `modules/WebApp/main.tf` (lines 204-210)
```terraform
var.application_module == "odoo" ? {
  HOST    = local.db_internal_ip
  DB_HOST = local.db_internal_ip
  USER    = local.database_user_full
  DB_PORT = "5432"           # ✓ Correct port set
  PGPORT  = "5432"           # ✓ PostgreSQL port set
} : {},
```

## Why the Error Still Occurs
The deployed Cloud Run service is running with an **older configuration** that doesn't include the DB_PORT fix. The Terraform configuration needs to be re-applied to update the running service.

## Required Action
**Re-apply the Terraform configuration** to update the Cloud Run service with the correct environment variables:

```bash
# Navigate to the deployment directory
cd /path/to/terraform/config

# Apply the Terraform configuration
terraform apply
```

## Verification Steps

### 1. Verify Environment Variables in Cloud Run
After applying Terraform, check the Cloud Run service environment variables:

```bash
# Get the service name (format: appodoo<tenant_id><random_id>)
SERVICE_NAME="appodoodemo9e0726a6"
REGION="us-central1"
PROJECT_ID="qwiklabs-gcp-03-ba6ddd2b9ffc"

# Describe the service and check environment variables
gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --project $PROJECT_ID \
  --format="value(spec.template.spec.containers[0].env)"
```

Look for:
- `DB_PORT=5432` ✓
- `PGPORT=5432` ✓
- `DB_HOST=10.171.0.5` (or similar internal IP) ✓

### 2. Check Service Logs
Monitor the logs after redeployment:

```bash
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=$SERVICE_NAME" \
  --project $PROJECT_ID \
  --limit 50 \
  --format json
```

Expected: No more "port 8069" connection errors

### 3. Test Database Connection
The Odoo initialization job should complete successfully:

```bash
# List recent job executions
gcloud run jobs executions list \
  --region $REGION \
  --project $PROJECT_ID \
  --format="table(name,status,completionTime)"
```

Expected: `odoo-init-*` job shows `SUCCEEDED` status

## Technical Details

### Environment Variable Flow
1. **Definition**: `modules/WebApp/main.tf` line 204-210 (preset_env_vars)
2. **Merging**: Line 230-240 (static_env_vars merges preset + defaults)
3. **Application**: `modules/WebApp/service.tf` line 184-194 (dynamic env blocks)
4. **Cloud Run**: Environment variables set on container

### Database Connection Parameters for Odoo
```bash
HOST=10.171.0.5          # Database IP
DB_HOST=10.171.0.5       # Alternative format
DB_PORT=5432             # PostgreSQL port (CRITICAL)
PGPORT=5432              # PostgreSQL client variable
DB_NAME=odoo_demo9e0726a6_<random>
DB_USER=odoo_demo9e0726a6_<random>
DB_PASSWORD=<from_secret_manager>
```

## Related Files
- `modules/WebApp/main.tf` - Odoo preset configuration with DB_PORT
- `modules/WebApp/service.tf` - Cloud Run service with environment variables
- `modules/WebApp/jobs.tf` - Initialization jobs (db-init, odoo-init)
- `modules/WebApp/modules/odoo/variables.tf` - Odoo module defaults

## References
- Commit 58877ab: "Update Odoo configuration to use internal DB IP and enforce port 5432"
- Commit 4130063: "Fix Odoo database connection timeout by adding missing DB_PORT environment variables"
- PostgreSQL default port: 5432
- Odoo HTTP port: 8069 (should NOT be used for DB connection)
