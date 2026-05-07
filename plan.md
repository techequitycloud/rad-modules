1. **Remove `roles/storage.objectAdmin` from GKE node service accounts**
   - File to modify: `modules/Istio_GKE/gke.tf`, `modules/Bank_GKE/gke.tf`, `modules/MC_Bank_GKE/gke.tf`
   - Description: The `roles/storage.objectAdmin` role is overly permissive for a GKE node pool service account. It grants full control over objects, including deleting them, which violates the principle of least privilege. It should be replaced with `roles/storage.objectViewer` if not already present, or simply removed if `roles/storage.objectViewer` is already in the list.
   - Note: In `Bank_GKE/gke.tf` and `MC_Bank_GKE/gke.tf`, `roles/storage.objectViewer` is already present in the list, so I will just remove `roles/storage.objectAdmin`. In `Istio_GKE/gke.tf`, I will replace `roles/storage.objectAdmin` with `roles/storage.objectViewer`.

2. **Run pre-commit instructions**
   - Ensure proper testing, verification, review, and reflection are done.

3. **Submit the changes**
   - Submit the PR with appropriate descriptive title and messages.
