## 2024-07-13 - Aligning UIMeta Group with Order Hundreds Digit
**Learning:** The `group=N` value in UIMeta annotations must align with the hundreds digit of its `order=Nxx` attribute (e.g., `group=3` for `order=3xx`, `group=5` for `order=5xx`), avoiding incorrect default placement in `group=0` for variables that should reside in specific sections on the deployment wizard.
**Action:** When auditing or adding new variables across modules, verify their `group` number explicitly matches the corresponding section defined in `SKILLS.md` and their `order` value, rather than defaulting to `0`.
