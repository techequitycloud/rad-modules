## 2024-05-30 - GKE SA Over-permissioning
**Vulnerability:** GKE node pool service accounts in `modules/Istio_GKE/gke.tf`, `modules/Bank_GKE/gke.tf`, and `modules/MC_Bank_GKE/gke.tf` are granted `roles/storage.objectAdmin`.
**Learning:** This is a project-wide role granting full control over all GCS buckets in the project, which violates the principle of least privilege. The intended permission is likely just `roles/storage.objectViewer` to allow nodes to pull container images from GCR/Artifact Registry if still using GCS backend.
**Prevention:** Always use `roles/storage.objectViewer` for node pools unless specific write access is needed, in which case Workload Identity should be used for bucket-specific access.

## 2024-05-30 - Scripts using roles/owner
**Vulnerability:** Shell scripts in `scripts/gcp-cr-mesh/`, `scripts/gcp-istio-security/`, `scripts/gcp-istio-traffic/`, and `scripts/gcp-m2c-vm/` grant `roles/owner` to a newly created service account and download its key.
**Learning:** This is a severe security violation as it creates a highly privileged, long-lived credential and stores it locally. These are likely standalone helper scripts, but they should be refactored to use least-privilege roles or rely on user credentials.
**Prevention:** Never grant `roles/owner` in scripts. Ensure scripts only request the specific roles required for their tasks.
