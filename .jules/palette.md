## 2024-06-03 - Missing Operator Outputs in Bank_GKE
 **Learning:** The `Bank_GKE` module was missing standard operator outputs like `cluster_credentials_cmd` and `external_ip` compared to `Istio_GKE`, forcing operators to manually construct `gcloud` commands and look up the global load balancer IP.
 **Action:** Ensure all GKE-based modules explicitly expose these outputs to improve the post-deployment Operator Experience.
