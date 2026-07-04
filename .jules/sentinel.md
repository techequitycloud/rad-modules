## 2024-07-04 - Over-permissioned GKE Default Node Service Accounts
**Vulnerability:** The GKE node service accounts in `Istio_GKE`, `Bank_GKE`, and `MC_Bank_GKE` were granted `roles/storage.objectAdmin`, which allows nodes (and pods using the default node service account) to overwrite or delete objects in any GCS bucket in the project, rather than just pulling images.
**Learning:** Default node service accounts should only have read-only access to storage (`roles/storage.objectViewer` or `roles/artifactregistry.reader`) to pull container images, strictly following the least privilege principle.
**Prevention:** Avoid granting administrative roles like `roles/storage.objectAdmin` or `roles/storage.admin` to node service accounts.
