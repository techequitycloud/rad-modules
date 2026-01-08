# Tutorial: Cloud Run Jobs (jobs.tf)

## Overview
The `jobs.tf` file defines **Cloud Run Jobs**. Unlike Services (which listen for web requests), Jobs are for tasks that run to completion, such as:
- Database migrations (`python manage.py migrate`).
- Initial data loading (`import_db.sh`).
- Automated backups.
- One-off setup scripts.

## Standard Pattern
Jobs are very similar to Services but use `google_cloud_run_v2_job`. They are often triggered by:
1. **Terraform**: Using `gcloud beta run jobs execute` inside a `null_resource` (for immediate execution during deploy).
2. **Cloud Scheduler**: For recurring tasks (like backups).

## Implementation Example

```hcl
resource "google_cloud_run_v2_job" "migrate_db" {
  name     = "migrate-${var.application_name}"
  location = local.region

  template {
    template {
      containers {
        image   = "gcr.io/my-project/my-app:latest"
        command = ["python", "manage.py", "migrate"]

        # Needs same env vars as the main app
        env {
          name = "DATABASE_URL"
          value_source { ... }
        }
      }
      vpc_access { ... } # Needs DB access
    }
  }
}

# Execute the job during Terraform apply
resource "null_resource" "run_migration" {
  triggers = {
    image_sha = var.application_version # Re-run if image changes
  }

  provisioner "local-exec" {
    command = "gcloud run jobs execute ${google_cloud_run_v2_job.migrate_db.name} --region ${local.region} --wait"
  }
}
```

## Best Practices & Recommendations

### 1. Separate from Service
**Recommendation**: Keep Jobs in `jobs.tf`, distinct from `service.tf`.
**Why**: It keeps the codebase organized. Services are long-running daemons; Jobs are ephemeral tasks.

### 2. Idempotency
**Recommendation**: Ensure the script/command running in the Job is idempotent.
**Why**: Terraform might re-run the job. If running `import_db` twice deletes user data, you have a problem. Use checks (e.g., "if table exists, skip") inside your logic.

### 3. Use `wait`
**Recommendation**: When triggering via `local-exec`, use `--wait`.
**Why**: You want Terraform to fail if the migration fails, so you know the deployment is broken.

### 4. Shared Config
**Recommendation**: Use `locals` to share environment variables between `service.tf` and `jobs.tf` if possible, to avoid repeating the huge list of env vars.
