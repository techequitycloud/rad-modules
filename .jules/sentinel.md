## 2025-06-27 - [Sentinel] Remove roles/storage.objectAdmin from GKE node service accounts
**Vulnerability:** Found `roles/storage.objectAdmin` assigned to the default GKE node service account across multiple modules (Bank_GKE, Istio_GKE, MC_Bank_GKE).
**Learning:** Default GKE node service accounts are often over-permissioned. They only need read-only access (e.g. `roles/storage.objectViewer`, `roles/artifactregistry.reader`) to pull images. Granting `objectAdmin` violates the principle of least privilege and introduces risk if a node is compromised.
**Prevention:** Enforce strict read-only roles for all GKE node service accounts.
