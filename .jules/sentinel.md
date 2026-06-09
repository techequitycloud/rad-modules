## 2024-05-24 - Over-permissioned GKE Node Service Account
**Vulnerability:** The default GKE node service account in `Istio_GKE`, `Bank_GKE`, and `MC_Bank_GKE` was granted `roles/storage.objectAdmin`.
**Learning:** Node pools only need read access to pull container images from GCS/Artifact Registry. Granting objectAdmin allows nodes to modify/delete any object in any bucket in the project, which is a significant privilege escalation risk if a pod is compromised. In `Bank_GKE` and `MC_Bank_GKE`, it was granted alongside `roles/storage.objectViewer` which was redundant.
**Prevention:** Always use `roles/storage.objectViewer` or `roles/artifactregistry.reader` for GKE node pool service accounts, never `roles/storage.objectAdmin`.
