## 2024-06-16 - Standardizing GKE Operator Outputs
**Learning:** Operators rely on the `cluster_credentials_cmd` output for a seamless handoff from Terraform to `kubectl`. When GKE-based modules lack this output, operators must manually construct the command, breaking their workflow.
**Action:** Always include the standard `cluster_credentials_cmd` output in all GKE-based modules as mandated by `SKILLS.md`, ensuring a consistent operator experience.
