## 2026-05-20 - null_resource Triggers Causing Re-apply
**Learning:** Using `always_run = timestamp()` on a `null_resource` slows down deployments. It constantly evaluates as a new value, forcing the resource replacement every time `tofu apply` runs. This is problematic for large downloads and extractions.
**Action:** Use a static trigger like `always_run = "true"` and handle the idempotency inside the `local-exec` bash script (e.g., check if files/directories already exist and skip the step) to ensure faster plan and apply phases while maintaining correct state behavior.
