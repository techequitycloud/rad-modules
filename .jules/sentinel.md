## 2024-05-08 - GKE Node Service Accounts Over-permissioned with Storage Admin

**Vulnerability:** GKE node service accounts in `modules/Istio_GKE/gke.tf`, `modules/Bank_GKE/gke.tf`, and `modules/MC_Bank_GKE/gke.tf` were granted `roles/storage.objectAdmin` by default in the `local.gke_sa_project_roles` list.

**Learning:** This is a recurring misconfiguration pattern in the GKE application modules. GKE nodes typically only need to read from GCR/Artifact Registry or GCS (e.g., for pulling images or reading config). Granting `storage.objectAdmin` to the default node service account creates a project-wide risk where any compromised pod running on that node (without workload identity) could delete or overwrite objects in any GCS bucket in the project.

**Prevention:** Always restrict default node service accounts to `roles/storage.objectViewer` or less. If a specific application running on GKE requires write access to a bucket, configure a dedicated Workload Identity with bucket-level permissions rather than elevating the node-level service account.
