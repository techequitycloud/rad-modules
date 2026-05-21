## 2024-05-21 - Avoiding null_resource timestamp() triggers
**Learning:** When using `null_resource` with `local-exec` to download or generate files, using `always_run = timestamp()` slows down deployments by forcing resource recreation on every apply.
**Action:** Instead, rely on static triggers (like version numbers) or `always_run = "true"` (which avoids marking the resource as replaced in the state) and handle idempotency with bash logic within the `local-exec` provisioner (e.g., `if [ -f "..." ]; then exit 0; fi`) to skip redundant executions.
