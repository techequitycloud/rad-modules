
## 2024-05-24 - Over-permissioned GKE Node Service Accounts
**Vulnerability:** The default GKE node service account was granted `roles/storage.objectAdmin` in application modules (`Bank_GKE`, `Istio_GKE`, `MC_Bank_GKE`), granting it destructive write access to all GCS buckets in the project.
**Learning:** Broad permissions assigned to default components (like node service accounts) often go unnoticed because they are bundled in a large list of standard roles (`local.gke_sa_project_roles`).
**Prevention:** Always default to read-only roles (`roles/storage.objectViewer`) for compute service accounts unless write access is explicitly required for a specific, isolated bucket (which should then use a dedicated Workload Identity instead of node-level permissions).
