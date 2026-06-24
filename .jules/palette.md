## 2024-06-24 - Missing Outputs in GKE Modules
**Learning:** GKE-based modules like Bank_GKE must expose `cluster_credentials_cmd` and `external_ip` in `outputs.tf` to provide a consistent operator experience. When auditing modules, check for these standard outputs.
**Action:** I will ensure all GKE modules include these outputs, as specified in the SKILLS.md standards, to improve operator clarity.

## 2024-06-24 - AI Code Review False Positive
**Learning:** The AI code reviewer falsely flagged valid references `google_compute_global_address.glb.address` and `var.gke_cluster` as hallucinated. It missed that these are valid elements present in the module's `glb.tf` and `variables.tf`. The module passed `tofu validate` and `tofu test`.
**Action:** Always verify if a review flag is truly valid by checking `tofu validate` results and actual file contents rather than blindly trusting the reviewer.
