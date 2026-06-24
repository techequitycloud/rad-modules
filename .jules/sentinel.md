## 2024-05-18 - Over-permissioned GKE Node Service Account
**Vulnerability:** GKE standard node pools in `Bank_GKE` and `MC_Bank_GKE` modules were granting `roles/storage.objectAdmin` to the default node service account (`gke-standard-sa`).
**Learning:** Default GKE node service accounts should only have read-only permissions for storage (e.g., to pull images via `roles/artifactregistry.reader` or `roles/storage.objectViewer`), not administrative permissions that allow data deletion or modification across all project buckets.
**Prevention:** Strictly adhere to the principle of least privilege. Verify what exact permissions a node pool needs (usually just logging, monitoring, and pulling images) rather than granting broad generic roles.
