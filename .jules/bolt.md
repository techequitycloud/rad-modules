## 2024-06-11 - Unnecessary Resource Replacement on Apply

**Learning:** Using `always_run = timestamp()` on a `null_resource` in Terraform forces full resource replacement and application downtime on every `terraform apply` if the resource has a `when = destroy` block.

**Action:** Removed `always_run = timestamp()` trigger and dynamic upstream dependencies (`download_id`) to break the downstream replacement chain and only rely on `depends_on` or actual application version changes to speed up applies.
