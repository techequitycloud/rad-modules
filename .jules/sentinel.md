
## 2025-05-18 - Avoid roles/owner in helper scripts
**Vulnerability:** The standalone helper script `scripts/gcp-cr-mesh/gcp-cr-mesh.sh` dynamically created a service account and granted it `roles/owner` project-wide to provision resources.
**Learning:** Even though bash helper scripts bypass Terraform state and are often used for quick bootstrapping, they still run with broad permissions and create persistent identities. Using `roles/owner` for these scripts violates least privilege and creates a massive security gap if the script or its downloaded JSON key is compromised.
**Prevention:** Always identify the exact APIs and actions the helper script performs and grant a precise list of least-privilege roles (e.g., `roles/run.admin`, `roles/compute.networkAdmin`) via a loop, rather than defaulting to `roles/owner` for convenience.
