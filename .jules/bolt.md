## 2024-07-05 - Optimize Terraform Apply by Removing `always_run = timestamp()`
**Learning:** Using `always_run = timestamp()` inside `triggers` for downloading manifests forces re-execution on every `terraform apply`, slowing down deployments because dependent resources (like `deploy_bank_of_anthos`) also recreate.
**Action:** Remove `always_run = timestamp()` from `triggers` to optimize deployment speed, relying on `version` and `download_path` to track changes instead.
