## 2026-05-14 - Missing cluster_credentials_cmd output in GKE modules
 **Learning:** Standard GKE-based modules are expected to provide a `cluster_credentials_cmd` output as per `SKILLS.md`. `modules/Bank_GKE` (and potentially `modules/MC_Bank_GKE`) were missing this output, which reduces Operator Experience because they don't get the ready-to-paste command for authentication.
 **Action:** Always double-check standard outputs like `cluster_credentials_cmd` and `external_ip` when reviewing module configurations, especially for older or cloned modules.
