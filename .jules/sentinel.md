
## 2024-05-10 - Over-privileged GKE Node Service Accounts
**Vulnerability:** The default node service accounts in `modules/Istio_GKE/gke.tf`, `modules/Bank_GKE/gke.tf`, and `modules/MC_Bank_GKE/gke.tf` were granted `roles/storage.objectAdmin`.
**Learning:** Granting `roles/storage.objectAdmin` to a cluster's node service account violates the principle of least privilege by giving project-wide destructive write access to GCS. It's easy to overlook this when building standard configurations for foundational modules.
**Prevention:** Always use `roles/storage.objectViewer` for node service accounts to allow pulling images from GCR/Artifact Registry. For workloads that need to write to GCS buckets, use Workload Identity to grant granular, bucket-level permissions instead of elevating the node service account's privileges.
