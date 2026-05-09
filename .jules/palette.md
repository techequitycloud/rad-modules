## 2024-05-09 - Add missing cluster_credentials_cmd output to Bank_GKE
 **Learning:** Standard GKE-based modules are expected to expose `cluster_credentials_cmd` in `outputs.tf` to provide operators with the exact command to authenticate to the cluster. This improves the operator experience by removing the need to manually construct the gcloud command.
 **Action:** Always ensure GKE modules include the `cluster_credentials_cmd` output as defined in `SKILLS.md`.
