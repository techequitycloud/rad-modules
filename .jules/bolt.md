## 2024-05-08 - Use static triggers in null_resource local-exec for idempotency
**Learning:** Using `always_run = timestamp()` in `null_resource` slows down deployments because it forces the resource to be marked as replaced in every run. Dynamic triggers like `manifests_missing = fileexists(...) ? "exists" : timestamp()` cause a two-apply state issue.
**Action:** Use `always_run = "true"` and handle idempotency with bash logic within the `local-exec` provisioner (e.g., `if [ -d "${local.extracted_path}/kubernetes-manifests" ]; then exit 0; fi`) to skip redundant executions.
