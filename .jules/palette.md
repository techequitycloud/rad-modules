## 2024-05-26 - Missing standard GKE outputs
**Learning:** Found that Bank_GKE was missing standard required outputs cluster_credentials_cmd and external_ip. For GKE-based modules with a global load balancer, external_ip should directly reference the load balancer's address.
**Action:** Always verify new or existing GKE modules include standard outputs defined in SKILLS.md to improve operator experience.
