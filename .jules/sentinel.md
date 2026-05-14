## 2026-05-14 - Over-permissioned GKE Node Service Accounts
**Vulnerability:** GKE node pool service accounts in Bank_GKE, Istio_GKE, and MC_Bank_GKE were granted 'roles/storage.objectAdmin' (project-wide bucket administrative access).
**Learning:** Application modules sometimes duplicate Foundation module behavior, like defining GKE service accounts with overly broad permissions out of convenience.
**Prevention:** Always enforce least privilege for node service accounts by using 'roles/storage.objectViewer' instead of 'roles/storage.objectAdmin' if they only need read access, and avoid project-wide grants when possible.
