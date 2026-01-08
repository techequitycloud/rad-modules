# Tutorial: Service Accounts (sa.tf)

## Overview
The `sa.tf` file manages **Service Accounts (SAs)**. In a modular architecture, we often need to check if a Service Account already exists (created by a foundational module) or creates new ones specific to the application.

## Standard Pattern
The `rad-modules` approach uses a pattern of "Discovery" via an external data source to check for existing SAs, combined with local variables to handle the logic.

### Key Components
- `data "external" "check_service_accounts"`: A shell script block that queries Google Cloud to see if standard SAs (like `cloudrun-sa`) already exist.
- `locals`: Defines booleans (e.g., `cloud_run_sa_exists`) and constructs email addresses dynamically based on the project ID.
- `resource "google_service_account"`: Creates a new SA only if it's required and doesn't exist (though currently, most modules rely on the foundational `GCP_Project` or `GCP_Services` to provide these, or assume standard naming).

## Implementation Example
This complex pattern is standard across modules to ensure idempotency and loose coupling:

```hcl
# Check for existence
data "external" "check_service_accounts" {
  program = ["bash", "-c", "... script checking gcloud iam service-accounts describe ..."]
}

locals {
  # Parse result
  cloud_run_sa_exists = data.external.check_service_accounts.result["cloud_run_sa_exists"] == "true"

  # Define standard email pattern
  cloud_run_sa_email = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
}
```

## Best Practices & Recommendations

### 1. Consistent Naming
**Recommendation**: Stick to the standard naming convention: `[component]-sa` (e.g., `cloudrun-sa`, `cloudsql-sa`).
**Why**: This allows other modules to predictably construct the SA email address without needing to query the API for every single dependency.

### 2. Centralized Definition
**Recommendation**: If possible, define Service Accounts in the foundational `GCP_Project` module and pass them as outputs or assume standard naming.
**Why**: This avoids "orphan" service accounts or duplicate creation attempts if multiple modules try to manage the same identity.

### 3. Least Privilege
**Recommendation**: The Service Account created in `sa.tf` should have **no permissions** by default.
**Why**: Permissions should be added via `iam.tf` only for the specific resources required. Do not grant `roles/owner` or `roles/editor` to application Service Accounts.
