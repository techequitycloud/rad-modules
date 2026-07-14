## 2024-07-14 - Incorrect UIMeta Group Assignments
**Learning:** Variables are sometimes incorrectly assigned to `group=0` despite their `order=Nxx` attribute implying they belong to a different logical section (e.g., `order=505` placed in `group=0` instead of `group=5`). This breaks the layout of the deployment wizard and forces deployers to configure related settings on the wrong pages.
**Action:** During deployment wizard checks, proactively audit variables with `group=0` against their `order` attribute and `SKILLS.md` to ensure they genuinely belong in the 'Provider / Metadata' section.
