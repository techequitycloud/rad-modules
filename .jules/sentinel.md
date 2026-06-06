## 2024-05-24 - Over-permissioned GKE Node Pools
**Vulnerability:** GKE standard node pool service accounts in modules/Istio_GKE, modules/Bank_GKE, and modules/MC_Bank_GKE were granted `roles/storage.objectAdmin`.
**Learning:** Node pools only require read access to pull images (`roles/storage.objectViewer` or `roles/artifactregistry.reader`). Granting objectAdmin allows them to overwrite or delete ANY object in ALL buckets across the project, a massive blast radius.
**Prevention:** Always grant `roles/storage.objectViewer` or `roles/artifactregistry.reader` instead of `roles/storage.objectAdmin` for node pool SAs.
