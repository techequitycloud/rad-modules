## 2024-07-15 - Mismatched UIMeta group for network range variables
**Learning:** Variables for secondary IP ranges (`pod_ip_range`, `service_ip_range`) frequently end up in `group=0` despite their `order` matching the cluster networking section (e.g., `order=505`). This places advanced networking configuration on the first metadata page of the wizard, confusing deployers.
**Action:** Always verify that a variable's `group=N` matches the hundreds digit of its `order=Nxx` to keep section-specific variables grouped together.
