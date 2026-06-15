## 2024-06-15 - UIMeta Group Assignments for Pod and Service IP Ranges

**Learning:** Variables `pod_ip_range` and `service_ip_range` were mistakenly assigned to `group=0` (Provider/Metadata) instead of their respective GKE cluster configuration groups, which negatively impacted the deployer experience by hiding cluster networking settings from the main GKE configuration page.
**Action:** When auditing or copying variables across modules, ensure that `group=N` annotations are verified against the standard layout in `SKILLS.md` and correctly map to the domain context (e.g. GKE IP configurations belong in the GKE section, not Metadata).
