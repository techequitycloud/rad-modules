## 2024-05-29 - Over-permissioned GKE Node Service Accounts

**Vulnerability:** The default GKE node pool service accounts in `Bank_GKE`, `Istio_GKE`, and `MC_Bank_GKE` were explicitly granted `roles/storage.objectAdmin` on the entire project, giving all pods running on the cluster full control over all GCS buckets in the project.
**Learning:** The `roles/storage.objectAdmin` was likely added as a convenience for application development, but violates least privilege. Node-level service accounts should only have the minimum permissions needed to run the node itself (pulling images, writing logs/metrics). If applications need GCS write access, Workload Identity with a dedicated, scoped service account should be used instead.
**Prevention:** GKE node service accounts should only have `roles/storage.objectViewer` or `roles/artifactregistry.reader` to pull images, never `roles/storage.objectAdmin` or project-wide destructive permissions. Use Workload Identity for app-specific permissions.
