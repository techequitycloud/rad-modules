
## 2024-06-19 - Avoid always_run = timestamp() in null_resource triggers
**Learning:** Using `always_run = timestamp()` inside the `triggers` block of a `null_resource` defeats caching and forces re-execution on every `tofu apply`.
**Action:** Rely on explicit change indicators like `version` or `filemd5()` to optimize deployment speed.
