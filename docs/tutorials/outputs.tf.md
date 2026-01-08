# Tutorial: Outputs (outputs.tf)

## Overview
The `outputs.tf` file defines the data that is returned to the user (or the calling module) after `tofu apply` is finished. This is crucial for usability, providing URLs, connection strings, or IDs needed for next steps.

## Standard Pattern
Outputs usually return:
- **Service URL**: The public link to the application.
- **Database Info**: IP address and instance connection name.
- **Resources**: IDs of created buckets or service accounts.

## Implementation Example

```hcl
output "app_service_url" {
  description = "The URL of the deployed Cloud Run service"
  value       = length(google_cloud_run_v2_service.app_service) > 0 ? google_cloud_run_v2_service.app_service[0].uri : null
}

output "database_connection_name" {
  description = "The connection name of the Cloud SQL instance"
  value       = local.db_instance_name
}
```

## Best Practices & Recommendations

### 1. Conditional Safety
**Recommendation**: When referencing resources that use `count` (e.g., `count = var.enabled ? 1 : 0`), always guard the output value with a check like `length(resource) > 0 ? resource[0].val : null`.
**Why**: If the resource isn't created, Terraform will throw an error if you try to access index `[0]`.

### 2. No Secrets
**Recommendation**: **Never** output passwords or sensitive keys in `outputs.tf`.
**Why**: Outputs are displayed in clear text in the CI/CD logs and console. If a user needs a password, direct them to Secret Manager or look it up via the console.

### 3. Descriptions
**Recommendation**: Always add a `description` field.
**Why**: It serves as documentation for the API of your module.
