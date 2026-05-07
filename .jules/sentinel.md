## 2024-05-07 - Over-privileged GKE Service Accounts
**Vulnerability:** GKE service accounts (e.g. in `Istio_GKE`, `Bank_GKE`, `MC_Bank_GKE`) were granted `roles/storage.objectAdmin` globally.
**Learning:** Node pools in GKE use a dedicated cluster service account that should only require minimal logging and monitoring roles (`roles/logging.logWriter`, `roles/monitoring.metricWriter`, `roles/monitoring.viewer`, `roles/stackdriver.resourceMetadata.writer`). The Compute Engine default SA should not be used, nor should it have `roles/owner` or `roles/editor`. Also granting `roles/storage.objectAdmin` is broader than required.
**Prevention:** Change `roles/storage.objectAdmin` to `roles/storage.objectViewer` in GKE application modules to follow least privilege.
