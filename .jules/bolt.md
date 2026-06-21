## 2024-06-21 - Remove always_run from triggers to optimize apply time
**Learning:** Using `always_run = timestamp()` inside `triggers` blocks for `null_resource` instances defeats caching and forces re-execution on every `tofu apply`, slowing down deployments unnecessarily.
**Action:** Removed `always_run = timestamp()` from download tasks in GKE modules. Relied on explicit change indicators like `version` and `download_path` to trigger resource recreation only when needed. Added `# PERFORMANCE:` comments.
