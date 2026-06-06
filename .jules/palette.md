## 2025-06-06 - Missing Standard Outputs in Bank_GKE

**Learning:** `Bank_GKE` lacks the standard `cluster_credentials_cmd` and `external_ip` outputs. Without these, the operator must manually construct the `gcloud` cluster authentication command and hunt through the GCP console to find the Bank of Anthos load balancer's IP address. `external_ip` should directly reference the `google_compute_global_address.glb.address` since this module provisions a global load balancer, rather than relying on a local text file fallback.

**Action:** When auditing GKE-based modules that provision a load balancer, ensure `cluster_credentials_cmd` and `external_ip` (referencing the actual load balancer resource) are exposed in `outputs.tf` to provide a consistent operator experience.
