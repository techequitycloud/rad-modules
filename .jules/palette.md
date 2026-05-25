## 2024-05-25 - Operator Experience: Standardizing Outputs
**Learning:** GKE-based modules provisioning a global load balancer must provide standard `cluster_credentials_cmd` and `external_ip` outputs directly referencing the load balancer address and gcloud cluster credential commands to reduce operator friction and support tickets.
**Action:** Always include these standard outputs when building application-layer modules with ingress.
