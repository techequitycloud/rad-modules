## 2024-05-01 - [Reduce GKE Node Service Account Privileges]
**Vulnerability:** GKE Application modules (`Bank_GKE`, `Istio_GKE`, `MC_Bank_GKE`) granted `roles/storage.objectAdmin` to the default node service account.
**Learning:** Overly permissive IAM bindings on node service accounts can lead to project-wide destructive access to GCS buckets.
**Prevention:** Always follow the principle of least privilege. If only read access is needed, use `roles/storage.objectViewer`.
