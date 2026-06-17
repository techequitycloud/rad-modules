## 2024-06-17 - Avoid always_run in null_resource for performance
**Learning:** Using `always_run = timestamp()` inside the `triggers` block of a `null_resource` defeats caching and forces re-execution on every `tofu apply`. This significantly increases deployment times, especially for operations like downloading large manifests or source code.
**Action:** Rely on explicit change indicators like `version` or `filemd5()` to optimize deployment speed instead of forcing continuous re-execution.
