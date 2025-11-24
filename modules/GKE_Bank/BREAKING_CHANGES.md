# Breaking Changes

This document outlines the breaking changes introduced in the latest version of the GKE_Bank module.

## Authentication

The module no longer uses the `resource_creator_identity` variable for service account impersonation. Instead, it now relies on the ambient credentials of the environment where Terraform is executed (e.g., Application Default Credentials).

**Migration:**

- Remove the `resource_creator_identity` variable from your module configuration.
- Ensure that the environment where you run Terraform is authenticated with Google Cloud.

## Networking

The `ip_cidr_ranges` variable has been renamed to `ip_cidr_range` and its type has been changed from `set(string)` to `string`.

**Migration:**

- Rename the `ip_cidr_ranges` variable to `ip_cidr_range` in your module configuration.
- Ensure that the value of `ip_cidr_range` is a single CIDR range string (e.g., `"10.0.0.0/16"`).
