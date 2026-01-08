# Tutorial: Secrets Management (secrets.tf)

## Overview
The `secrets.tf` file handles the creation and versioning of sensitive data using **Secret Manager**. This allows us to securely generate, store, and inject credentials without them ever appearing in plain text in our code.

## Standard Pattern
1. **Generate**: Use `random_password` to create a strong, unique value.
2. **Define**: Create a `google_secret_manager_secret` container.
3. **Store**: Create a `google_secret_manager_secret_version` to store the generated value.
4. **Access**: (Optional) Use `data "google_secret_manager_secret_version"` if you need to read it back (but avoid this if possible to keep state clean).

## Implementation Example

```hcl
# 1. Generate
resource "random_password" "db_password" {
  length  = 16
  special = false
}

# 2. Define Container
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.application_name}-db-password"
  replication {
    user_managed {
      replicas {
        location = local.region
      }
    }
  }
}

# 3. Store Version
resource "google_secret_manager_secret_version" "db_password_val" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}
```

## Best Practices & Recommendations

### 1. Generated vs. User Provided
**Recommendation**: Prefer generating secrets (`random_password`) inside Terraform over asking users to provide them.
**Why**: It's more secure (users don't handle the password) and easier (zero configuration).

### 2. Random Suffixes
**Recommendation**: Append `${local.random_id}` or similar to `secret_id`.
**Why**: Secret names are global to the project. If you deploy two instances of "wordpress", their secret names will collide without a unique suffix.

### 3. Application Configs
**Recommendation**: For complex apps (like Django or Moodle), store the _entire_ config file (e.g., `settings.py` content or `.env` file) as a single secret version.
**Why**: It simplifies injection. You can mount the secret as a file directly into the container, rather than mapping 20 individual environment variables.
