## 2024-05-24 - Speeding up `null_resource` downloads
**Learning:** Using `always_run = timestamp()` on `null_resource` slows down deployments because it forces the provisioner to run on every apply. Dynamic triggers like `manifests_missing = fileexists(...) ? "exists" : timestamp()` cause a two-apply state issue.
**Action:** Use static triggers like `always_run = "true"` and handle idempotency with bash logic within the `local-exec` provisioner (e.g., `if [ -f "..." ]; then exit 0; fi`) to skip redundant executions.
