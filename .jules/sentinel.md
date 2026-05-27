
## 2024-05-18 - Over-permissioned Default Node Service Accounts in GKE
**Vulnerability:** Default GKE node service accounts were granted `roles/storage.objectAdmin` in `Istio_GKE`, `Bank_GKE`, and `MC_Bank_GKE` modules.
**Learning:** `roles/storage.objectAdmin` is a project-wide role that grants full control over objects in all buckets, which is too permissive for standard node operations (like pulling images or reading config).
**Prevention:** Always grant `roles/storage.objectViewer` (which allows reading objects but not writing/deleting) unless a workload specifically requires write access to a bucket. In that case, use Workload Identity bound to a dedicated bucket rather than elevating the node service account's global permissions.
