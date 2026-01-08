# Tutorial: Implementing IAM (iam.tf)

## Overview
The `iam.tf` file is the central location for managing **Identity and Access Management (IAM)** policies within a module. It defines _who_ (Service Accounts, Users) has permission to do _what_ (access secrets, connect to databases) on specific resources.

## Standard Pattern
In the `rad-modules` architecture, IAM is typically handled at two levels:
1. **Resource-Level IAM**: Granting a Service Account access to a specific resource (e.g., a Secret or a Bucket).
2. **Project-Level IAM**: Granting broad permissions to "Trusted Users" or the Service Account itself (though least-privilege resource bindings are preferred).

### Key Resources
- `google_project_iam_member`: Grants a role to a member on the entire project.
- `google_secret_manager_secret_iam_member`: Grants access to a specific secret.
- `google_storage_bucket_iam_member`: Grants access to a specific storage bucket.
- `google_cloud_run_service_iam_binding`: Controls who can invoke the Cloud Run service (e.g., `allUsers` for public apps).

## Implementation Example
The following is a standard structure for an `iam.tf` file:

```hcl
# 1. Grant Cloud Run Service Account access to specific secrets
resource "google_secret_manager_secret_iam_member" "db_password_access" {
  project   = local.project.project_id
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.cloud_run_sa_email}"

  depends_on = [google_secret_manager_secret.db_password]
}

# 2. Grant public access to the application (if applicable)
resource "google_cloud_run_service_iam_binding" "public_access" {
  count    = var.public_access ? 1 : 0
  location = local.region
  service  = google_cloud_run_v2_service.app_service[0].name
  role     = "roles/run.invoker"
  members  = ["allUsers"]
}
```

## Best Practices & Recommendations

### 1. Granular Access Control
**Recommendation**: Avoid using `google_project_iam_member` for application permissions unless absolutely necessary.
**Why**: Granting `roles/storage.objectAdmin` at the project level allows the app to modify _any_ bucket. Instead, use `google_storage_bucket_iam_member` to grant access only to the app's specific bucket.

### 2. Use `iam_member` over `iam_binding`
**Recommendation**: Prefer `google_project_iam_member` over `google_project_iam_binding`.
**Why**: `iam_binding` is authoritative. It will **remove** any other users/service accounts that have that role if they are not listed in your Terraform code. `iam_member` is additive and safe to use in modular environments.

### 3. Service Account Separation
**Recommendation**: Each module uses specific Service Accounts (e.g., `cloudrun-sa`, `cloudbuild-sa`) defined in `sa.tf`.
**Why**: Never use the default Compute Engine service account. Dedicated SAs allow you to audit and restrict permissions per component.

### 4. Dependency Management
**Recommendation**: Always verify dependencies for IAM resources.
**Why**: Terraform might try to apply an IAM policy before the resource (like a Secret) is fully created. Explicit `depends_on` blocks (as seen in the example) prevent "Resource not found" errors during apply.
