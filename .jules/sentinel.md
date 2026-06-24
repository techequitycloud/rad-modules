## 2026-05-04 - Prevent over-permissioned GKE node service accounts
**Vulnerability:** GKE node service accounts in Bank_GKE, Istio_GKE, and MC_Bank_GKE modules were granted the overly permissive `roles/storage.objectAdmin` role.
**Learning:** This misconfiguration grants full project-wide read/write/delete access to all GCS buckets, violating the principle of least privilege. GKE nodes generally only need read access to storage to pull container images.
**Prevention:** Always use `roles/storage.objectViewer` for standard node operations. If an application requires write access to a specific GCS bucket, configure a dedicated Workload Identity scoped to that bucket rather than elevating the node-level service account.
