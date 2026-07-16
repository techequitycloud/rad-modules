## 2026-07-16 - Incorrect UIMeta Default Group Placement
**Learning:** Variables correctly assigned a section ordering (e.g., `order=505`) are frequently and erroneously assigned to `group=0` instead of their corresponding logical group (`group=5`), which disrupts the deployment wizard UI flow.
**Action:** Always verify that the `group=N` value corresponds directly to the hundreds digit of the `order=Nxx` attribute to ensure correct page placement in the UI.
