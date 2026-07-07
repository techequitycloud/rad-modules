## 2024-07-07 - Variables incorrectly assigned to group=0

**Learning:** Across `Istio_GKE` and `Bank_GKE`, variables like `pod_ip_range`, `service_ip_range`, and `deploy_application` are incorrectly assigned to `UIMeta group=0`. `group=0` is reserved for "Provider / Metadata" variables (e.g. `module_description`, `enable_services`, `project_id` overrides). Putting functional variables in `group=0` causes them to appear on the first wizard page alongside metadata, creating a confusing and disorganized deployer experience.

**Action:** When adding or auditing variables, always cross-reference the variable's logical section (e.g., GKE, Application) with the section mapping in `SKILLS.md` and assign the correct `group=N` value.
