## 2024-05-24 - [GKE Autopilot Bug]
**Learning:** Setting `enable_autopilot` to false causes a conflict with `remove_default_node_pool` and `initial_node_count` when evaluated.
**Action:** Use ternary operator to conditionally assign `true` or `null` instead.
