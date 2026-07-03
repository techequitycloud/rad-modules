## 2026-07-03 - Optimize Null Resource Triggers
**Learning:** Using `always_run = timestamp()` inside the `triggers` block of a `null_resource` (e.g., for downloading manifests) defeats caching and forces re-execution on every `tofu apply`, significantly slowing down deployments.
**Action:** Rely on explicit change indicators like `version` or `filemd5()` to optimize deployment speed.
