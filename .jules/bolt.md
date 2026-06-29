## 2024-05-14 - [Null Resource always_run Performance]
**Learning:** Using `always_run = timestamp()` inside the triggers block of a `null_resource` (e.g., for downloading manifests) defeats caching and forces re-execution on every `tofu apply`. This breaks idempotency and cascades down to dependent resources, causing unnecessary and slow re-deployments.
**Action:** Rely on explicit change indicators like `version` or `filemd5()` to optimize deployment speed instead of `always_run = timestamp()`.
