## 2024-06-15 - Removed always_run = timestamp() in download triggers
**Learning:** Using `always_run = timestamp()` inside the `triggers` block of a `null_resource` (e.g., for downloading manifests) defeats caching and forces re-execution on every `tofu apply`. This slows down deployments significantly.
**Action:** Rely on explicit change indicators like `version` or `filemd5()` rather than timestamp() to optimize deployment speed. I removed it from the `download_bank_of_anthos` null_resource triggers in Bank_GKE and MC_Bank_GKE modules.

## 2024-06-15 - Fixing 'Invalid index' errors during tofu test
**Learning:** Referencing nested list attributes of cluster resources (e.g., `google_container_cluster`'s `master_auth[0].cluster_ca_certificate`) causes 'Invalid index' errors during `tofu test` executions with mock providers, as these attributes often return as empty lists in mocks.
**Action:** When configuring providers like `kubernetes` or `helm`, wrap the attribute lookup in `try(..., "")` to provide a fallback value for mock providers (e.g., `cluster_ca_certificate = base64decode(try(local.cluster.master_auth[0].cluster_ca_certificate, ""))`).

## 2024-06-15 - Fixing 'Conflicting configuration arguments' errors during tofu test
**Learning:** Assigning `false` to optional boolean attributes that conflict with other fields (such as GKE's `enable_autopilot` and `remove_default_node_pool`) causes Terraform provider validation errors during `tofu plan` or `tofu test`.
**Action:** When configuring optional boolean attributes that conflict with other fields, assign `null` instead of `false` (e.g., `enable_autopilot = var.is_autopilot ? true : null`) to cleanly omit the field and avoid Terraform provider validation errors.
