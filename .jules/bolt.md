## 2025-06-25 - Avoid always_run in null_resource for manifest downloads
**Learning:** Using `always_run = timestamp()` in `null_resource` triggers (like `download_bank_of_anthos`) forces re-execution on every `tofu apply`, which cascaded to replacing the downstream deployment resources every time. This defeats caching and significantly slows down idempotent deployments.
**Action:** Remove `always_run = timestamp()` and rely on explicit state variables like `version` or `filemd5()` so `tofu apply` only triggers changes when necessary.
