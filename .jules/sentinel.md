## 2024-06-14 - Over-permissioned node pool service account
**Vulnerability:** Found `roles/storage.objectAdmin` assigned to the GKE node pool service account in `modules/Istio_GKE/gke.tf`, `modules/Bank_GKE/gke.tf`, and `modules/MC_Bank_GKE/gke.tf`.
**Learning:** Node pool service accounts only need read access to pull images (`roles/storage.objectViewer` or `roles/artifactregistry.reader`). Granting `objectAdmin` allows nodes to modify/delete objects across all GCS buckets in the project, violating the principle of least privilege.
**Prevention:** Audit default GKE IAM bindings in modules. Use `roles/storage.objectViewer` instead of `roles/storage.objectAdmin` for image pulling, and scope write access to a dedicated Workload Identity where buckets need to be modified.
