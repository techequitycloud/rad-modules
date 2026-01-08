# Tutorial: Database (database.tf / sql.tf)

## Overview
The `database.tf` (or `sql.tf`) file manages the application's data persistence. In standard modules, this often involves:
1. **Discovering** the shared Cloud SQL instance (created by `GCP_Services`).
2. **Creating** a dedicated Database (e.g., `create database myapp`).
3. **Creating** a dedicated User (e.g., `create user myapp with password ...`).

## Standard Pattern
We generally do _not_ create a new `google_sql_database_instance` for every app (too expensive). We use a shared instance and create logical databases within it.

## Implementation Example

```hcl
# 1. Generate Password
resource "random_password" "db_password" { ... }

# 2. Create Database
resource "google_sql_database" "db" {
  name     = var.application_database_name
  instance = local.db_instance_name # From GCP_Services
  project  = local.project.project_id
}

# 3. Create User
resource "google_sql_user" "user" {
  name     = var.application_database_user
  instance = local.db_instance_name
  password = random_password.db_password.result
  project  = local.project.project_id
}
```

## Best Practices & Recommendations

### 1. Logical Isolation
**Recommendation**: Every application gets its own `google_sql_database` and `google_sql_user`.
**Why**: Security. If App A is compromised, it cannot read App B's tables if they are in different databases with different credentials.

### 2. Discovery vs. Creation
**Recommendation**: Use Data Sources or Remote State to find the Instance name, don't hardcode it.
**Why**: The instance name might change or have a random suffix.

### 3. Password Rotation
**Recommendation**: If you change the `random_password` length, Terraform will regenerate it. Be careful—this breaks the app until the new password is injected.
