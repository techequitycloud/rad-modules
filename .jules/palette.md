## 2024-05-16 - Deployment ID variable updatesafe flag
**Learning:** The `deployment_id` variable should never include the `updatesafe` flag in its `UIMeta` annotation because modifying it after initial deployment forces recreation of all named resources. I have observed this correctly enforced in `Bank_GKE`, `Istio_GKE`, and `MC_Bank_GKE`.

## 2024-05-16 - MC_Bank_GKE UIMeta group=0 ordering inconsistency
**Learning:** In `MC_Bank_GKE`, `resource_creator_identity` and `trusted_users` have `order=102` and `order=107` respectively, while `module_dependency` is `order=102` and `module_tags` is `order=102`.
**Action:** Order numbers within the same `group` must be unique and sequential to ensure deterministic rendering in the deployment wizard.

## 2024-05-16 - Missing Standard Outputs in GKE-based modules
**Learning:** Based on `SKILLS.md`, standard GKE-based modules must include a `cluster_credentials_cmd` output. `Bank_GKE` and `MC_Bank_GKE` are missing this standard output.
**Action:** I will add `cluster_credentials_cmd` to `Bank_GKE`'s `outputs.tf` to ensure operator workflow clarity and consistency. This addresses a real operator pain point of not knowing the exact command to connect to the newly provisioned cluster.
