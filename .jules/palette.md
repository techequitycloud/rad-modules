## 2024-05-21 - Standard Operator Outputs for GKE Modules
**Learning:** Application modules like Bank_GKE sometimes lack standard operational outputs (`cluster_credentials_cmd` and `external_ip`), which leaves operators without clear next steps for connecting to their new deployments or knowing the public IP.
**Action:** Always ensure GKE modules expose a copy-pastable `cluster_credentials_cmd` and the `external_ip` (referencing the load balancer directly if present, rather than a local text file) to improve operator experience and prevent troubleshooting delays.
