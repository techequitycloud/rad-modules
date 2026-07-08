## 2024-07-08 - Removed always_run=timestamp() from null_resources
**Learning:** Using `always_run = timestamp()` inside the `triggers` block of a `null_resource` (e.g., for downloading manifests) defeats caching and forces re-execution on every `tofu apply`.
**Action:** Rely on explicit change indicators like `version` or `filemd5()` to optimize deployment speed instead of `timestamp()`.
