## 2024-05-17 - Service accounts granted roles/owner in helper scripts
**Vulnerability:** Standalone helper scripts in the `scripts/` directory (e.g., `gcp-cr-mesh.sh`, `gcp-istio-security.sh`) currently grant `roles/owner` to service accounts.
**Learning:** Hardcoding project-wide owner roles in generic setup scripts violates least privilege and represents a CRITICAL security risk that can easily be overlooked since it's not managed via Terraform state.
**Prevention:** Scripts must be refactored to require a user-provided, least-privilege service account instead of programmatically provisioning and elevating a new one to owner.
