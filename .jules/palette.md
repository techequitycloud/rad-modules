## 2024-11-20 - Ensure Accurate Output Descriptions
 **Learning:** When adding outputs like `cluster_credentials_cmd` to improve operator experience, the description should accurately reflect what the output is (a gcloud terminal command), not just what it fetches (Kubernetes credentials).
 **Action:** Always review output descriptions for precise clarity. Instead of `description = "Kubernetes credentials"`, use `description = "gcloud command to fetch Kubernetes cluster credentials"`.
