## 2024-07-06 - Remove always_run = timestamp() from null_resource
**Learning:** Using `always_run = timestamp()` inside the `triggers` block of a `null_resource` (e.g., for downloading manifests) defeats caching and forces re-execution on every apply, slowing down terraform apply.
**Action:** Rely on explicit change indicators like `version` or `filemd5()` to optimize deployment speed instead of `always_run = timestamp()`.
