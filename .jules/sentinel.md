## 2024-05-27 - Fix over-permissioned GKE node pool service accounts
**Vulnerability:** GKE node pool service accounts in `Istio_GKE`, `Bank_GKE`, and `MC_Bank_GKE` were granted the overly permissive `roles/storage.objectAdmin` role.
**Learning:** Node pool service accounts only require read access to Storage/Artifact Registry to pull container images. Granting them `objectAdmin` violates the principle of least privilege and unnecessarily exposes all storage buckets in the project to potential compromise if a node is breached.
**Prevention:** Always grant `roles/storage.objectViewer` or `roles/artifactregistry.reader` instead of `roles/storage.objectAdmin` for GKE node pools.
