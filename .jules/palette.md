
## 2024-05-11 - Add missing cluster_credentials_cmd output to Bank_GKE
 **Learning:** Standard GKE-based modules must include a `cluster_credentials_cmd` output in `outputs.tf` to provide operators with the necessary authentication command, as defined in `SKILLS.md`. The exact required syntax is: `value = "gcloud container clusters get-credentials ${var.gke_cluster} --region ${var.gcp_region} --project ${local.project.project_id}"` (do not escape the interpolation with double dollars like `$${...}`).
 **Action:** When creating or maintaining GKE-based modules, ensure this output is present to improve the operator experience and maintain consistency across modules.
