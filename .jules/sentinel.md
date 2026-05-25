## 2024-05-25 - GKE Node Service Account Over-Privileged with Storage Admin
**Vulnerability:** GKE node service accounts in `Bank_GKE/gke.tf`, `Istio_GKE/gke.tf`, and `MC_Bank_GKE/gke.tf` are granted `roles/storage.objectAdmin`.
**Learning:** Default configurations for GKE often over-provision storage permissions to allow for general utility, but project-wide objectAdmin grants destructive access to all buckets in the project, violating least privilege.
**Prevention:** Always use `roles/storage.objectViewer` for read-only requirements (like downloading artifacts) and use dedicated Workload Identity service accounts with bucket-level bindings when write access is explicitly needed.
