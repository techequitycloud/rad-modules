## 2024-05-07 - Avoid timestamp triggers in local-exec
**Learning:** When using `null_resource` with `local-exec` to download or generate files, using `always_run = timestamp()` slows down deployments, and using dynamic triggers like `manifests_missing = fileexists(...) ? "exists" : timestamp()` causes a two-apply state issue forcing resource recreation.
**Action:** Instead, rely on static triggers (like version numbers) and handle idempotency with bash logic within the `local-exec` provisioner (e.g., `if [ -f "..." ]; then exit 0; fi`) to skip redundant executions.
