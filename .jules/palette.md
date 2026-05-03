## 2024-05-18 - Missing Standard Output in Application Module
**Learning:** `Bank_GKE` was missing the `cluster_credentials_cmd` standard output, required for operators to easily get credentials, despite it being a standard GKE-based module requirement defined in SKILLS.md.
**Action:** Always verify that standard outputs defined in SKILLS.md are present in all matching modules, not just the reference module (`Istio_GKE`).
