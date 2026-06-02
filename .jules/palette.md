## 2024-06-02 - GKE Operator Experience
**Learning:** For GKE-based modules that provision an external global load balancer (like `Bank_GKE`), operators need immediate access to the load balancer IP and the cluster authentication command post-deployment for verification and troubleshooting.
**Action:** Always include `external_ip` and `cluster_credentials_cmd` in `outputs.tf`. For global load balancers, the `external_ip` output should directly reference the load balancer's address (e.g., `google_compute_global_address.glb.address`) rather than falling back to a text file.
