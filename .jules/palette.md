## 2024-06-01 - Missing Standard Outputs in GKE Modules
 **Learning:** Standard GKE module outputs like `cluster_credentials_cmd` and `external_ip` are sometimes omitted. In the Bank_GKE module, `external_ip` should be derived from the global load balancer (`google_compute_global_address.glb.address`) rather than a text file since it provisions its own load balancer.
 **Action:** Ensure standard outputs are consistently applied across GKE modules and adjust the source for `external_ip` according to the module's architecture (e.g. GLB vs local script output).
