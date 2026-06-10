## 2024-06-10 - Over-permissioned GKE Node Pool Service Accounts
**Vulnerability:** GKE node pool service accounts (`gke_sa_project_roles`) in `modules/Istio_GKE`, `modules/Bank_GKE`, and `modules/MC_Bank_GKE` were granted `roles/storage.objectAdmin`.
**Learning:** Node pools only require read access to pull container images from Artifact Registry / GCR. The `roles/storage.objectAdmin` role grants full write/delete access across all buckets in the project, which violates the principle of least privilege.
**Prevention:** Always grant `roles/storage.objectViewer` or `roles/artifactregistry.reader` instead of `roles/storage.objectAdmin` for node pool service accounts, as specified in memory/guidelines.
