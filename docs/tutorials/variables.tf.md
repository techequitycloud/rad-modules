# Tutorial: Variables (variables.tf)

## Overview
The `variables.tf` file defines the input interface for your module. It allows users to customize the deployment (e.g., naming resources, setting sizes, toggling features) without changing the code.

## Standard Pattern
Variables in `rad-modules` are heavily annotated with metadata comments (e.g., `{{UIMeta ... }}`) which are used by the deployment UI to render forms.

### Key Groups
- **Deployment**: Metadata like `module_description`, `credit_cost`.
- **Application Project**: `existing_project_id`, `network_name`.
- **Deploy**: `application_name`, `application_version` (image tag).
- **Tenant**: `tenant_deployment_id`, `configure_environment`.

## Implementation Example

```hcl
# GROUP 5: Deploy

variable "application_name" {
  description = "Specify application name. {{UIMeta group=0 order=501 updatesafe}}"
  type        = string
  default     = "myapp"
}

variable "application_version" {
  description = "Enter application version (image tag). {{UIMeta group=0 order=504 updatesafe}}"
  type        = string
  default     = "latest"
}
```

## Best Practices & Recommendations

### 1. UIMeta Tags
**Recommendation**: Always include `{{UIMeta group=X order=Y updatesafe}}` in descriptions.
**Why**:
- `group=0`: Hides the variable from the simple UI view (for advanced/static configs).
- `updatesafe`: Indicates this variable can be changed after initial deployment (e.g., upgrading a version) without destroying the resource.

### 2. Type Constraints
**Recommendation**: Always define `type`. Use `string`, `bool`, `number`, or `list(string)` explicitly.
**Why**: Prevents runtime errors and allows Terraform to validate inputs early.

### 3. Sensible Defaults
**Recommendation**: Provide defaults for optional values (e.g., `default = true` for `configure_monitoring`).
**Why**: Reduces the friction for users deploying the module for the first time.

### 4. No Secrets in Defaults
**Recommendation**: Never put default passwords or keys in `variables.tf`.
**Why**: These files are committed to version control. Use `secrets.tf` to generate random passwords or require the user to input them at runtime (marked as `sensitive = true`).
