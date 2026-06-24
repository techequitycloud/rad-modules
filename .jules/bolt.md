## 2024-06-24 - Remove always_run = timestamp() in triggers
**Learning:** Using `always_run = timestamp()` inside a `null_resource` `triggers` block defeats Terraform caching and forces unnecessary re-execution on every `tofu apply`. This significantly slows down deployment times.
**Action:** Never use `always_run = timestamp()` for caching. Rely on explicit change indicators like `version` or `filemd5()` instead.
