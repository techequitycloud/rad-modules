## 2024-05-24 - Over-permissioned GKE Node Pool Service Accounts
**Vulnerability:** GKE node pool service accounts across multiple foundation modules (`Bank_GKE`, `Istio_GKE`, `MC_Bank_GKE`) were granted `roles/storage.objectAdmin`.
**Learning:** Node pool service accounts only need read access to pull container images from Artifact Registry or GCR. Granting `objectAdmin` unnecessarily allows node workloads to overwrite or delete objects in any storage bucket within the project, which violates the principle of least privilege.
**Prevention:** Always grant `roles/storage.objectViewer` or `roles/artifactregistry.reader` to node pool service accounts instead of `roles/storage.objectAdmin`. Ensure `prevent_destroy` is considered for buckets storing state.
