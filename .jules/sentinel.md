## 2024-05-19 - Removed roles/storage.objectAdmin from GKE service accounts
**Vulnerability:** GKE service accounts in application modules (`modules/Istio_GKE`, `modules/Bank_GKE`, `modules/MC_Bank_GKE`) were granted `roles/storage.objectAdmin` by default, giving them project-wide destructive access to Google Cloud Storage buckets.
**Learning:** The default node service account IAM permissions were configured to include overly permissive roles, violating the principle of least privilege. In GKE application modules, `roles/storage.objectAdmin` was unnecessarily included in the `local.gke_sa_project_roles` list.
**Prevention:** Enforce least privilege by replacing or removing `roles/storage.objectAdmin` in favor of `roles/storage.objectViewer` in GKE service account IAM configurations. Applications requiring write access should use a dedicated Workload Identity with bucket-level permissions instead.

## 2024-05-19 - Pending Security Fix: Remove roles/owner from scripts
**Vulnerability:** Standalone helper scripts in the `scripts/` directory (e.g., `gcp-cr-mesh.sh`, `gcp-istio-security.sh`, `gcp-istio-traffic.sh`, `gcp-m2c-vm.sh`) currently grant `roles/owner` to service accounts.
**Learning:** These scripts violate security best practices by granting excessively broad permissions (`roles/owner`) to service accounts during execution.
**Prevention:** This requires remediation in a future security patch to narrow the permissions granted to the exact roles required by the scripts.
