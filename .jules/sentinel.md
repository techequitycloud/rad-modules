
## 2024-06-25 - GKE Node Pool Over-Permissioned Service Accounts
**Vulnerability:** GKE node service accounts in standard deployment configurations (`Bank_GKE`, `Istio_GKE`, `MC_Bank_GKE`) were granted `roles/storage.objectAdmin` rather than `roles/storage.objectViewer`.
**Learning:** This is a recurring pattern where broad permissions are historically granted "just in case." GKE nodes only require read access to GCS/Artifact Registry to pull container images. Write access allows any pod on the node, if compromised, to potentially overwrite or delete critical infrastructure artifacts.
**Prevention:** Enforce `roles/storage.objectViewer` as the default for all node service accounts. If an application requires write access to GCS, use Workload Identity to grant permissions directly to the specific pod rather than elevating the node service account.
