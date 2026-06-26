## 2024-06-26 - Avoid `always_run = timestamp()` for null_resource triggers
**Learning:** Using `always_run = timestamp()` inside the `triggers` block of a `null_resource` defeats caching and forces re-execution on every `tofu apply`. This slows down deployments significantly.
**Action:** Replace `always_run = timestamp()` with explicit change indicators like `version` or file hashes to optimize deployment speed.
