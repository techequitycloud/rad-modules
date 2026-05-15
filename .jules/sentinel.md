## 2024-05-18 - Excess IAM roles on GKE node service accounts
**Vulnerability:** GKE node service accounts were granted `roles/storage.objectAdmin` project-wide, violating least privilege.
**Learning:** In GKE application modules (Bank_GKE, Istio_GKE, MC_Bank_GKE), the default node service account IAM permissions are configured using the `local.gke_sa_project_roles` list, which must strictly enforce least privilege (e.g., omitting `roles/storage.objectAdmin` in favor of `roles/storage.objectViewer` to prevent project-wide destructive access).
**Prevention:** Always verify the `local.gke_sa_project_roles` in `gke.tf` when creating or reviewing GKE modules. Remove project-wide `roles/storage.objectAdmin` and replace it with `roles/storage.objectViewer`.
