## 2024-06-14 - Null Resource Trigger Forces Redownloads

**Learning:** Using `timestamp()` in the `triggers` block of a `null_resource` (e.g., for downloading application manifests) defeats the purpose of caching and idempotency. It causes the provisioner to run on *every single* `terraform apply` or `plan`, which unnecessarily downloads release archives and significantly slows down the deployment process, especially for large multi-cluster setups.

**Action:** Avoid `timestamp()` in `null_resource` triggers unless explicit recreation on every run is absolutely intended. Instead, rely on attributes that actually reflect changes (like a `version` string, or `filemd5()` of a source file) to ensure the provisioner only runs when the underlying source changes, speeding up subsequent `apply` times.
